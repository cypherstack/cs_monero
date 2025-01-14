import 'dart:ffi';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../../cs_monero.dart';
import '../deprecated/get_height_by_date.dart';
import '../ffi_bindings/monero_wallet_bindings.dart' as xmr_ffi;
import '../ffi_bindings/monero_wallet_manager_bindings.dart' as xmr_wm_ffi;

class MoneroWallet extends Wallet {
  // internal constructor
  MoneroWallet._(Pointer<Void> pointer) : _walletPointer = pointer;

  // shared pointer
  static Pointer<Void>? _walletManagerPointerCached;
  static final Pointer<Void> _walletManagerPointer = Pointer.fromAddress(
    (() {
      try {
        // monero.printStarts = true;
        _walletManagerPointerCached ??= xmr_wm_ffi.getWalletManager();
        Logging.log?.i("ptr: $_walletManagerPointerCached");
      } catch (e, s) {
        Logging.log?.e("Failed to initialize wm ptr", error: e, stackTrace: s);
      }
      return _walletManagerPointerCached!.address;
    })(),
  );

  // instance pointers
  Pointer<Void>? _coinsPointer;
  Pointer<Void>? _transactionHistoryPointer;
  Pointer<Void>? _walletPointer;
  Pointer<Void> _getWalletPointer() {
    if (_walletPointer == null) {
      throw Exception(
        "MoneroWallet was closed!",
      );
    }
    return _walletPointer!;
  }

  // private helpers

  Transaction _transactionFrom(Pointer<Void> infoPointer) {
    return Transaction(
      displayLabel: xmr_ffi.getTransactionInfoLabel(infoPointer),
      description: xmr_ffi.getTransactionInfoDescription(infoPointer),
      fee: BigInt.from(xmr_ffi.getTransactionInfoFee(infoPointer)),
      confirmations: xmr_ffi.getTransactionInfoConfirmations(infoPointer),
      blockHeight: xmr_ffi.getTransactionInfoBlockHeight(infoPointer),
      accountIndex: xmr_ffi.getTransactionInfoAccount(infoPointer),
      addressIndexes: xmr_ffi.getTransactionSubaddressIndexes(infoPointer),
      paymentId: xmr_ffi.getTransactionInfoPaymentId(infoPointer),
      amount: BigInt.from(xmr_ffi.getTransactionInfoAmount(infoPointer)),
      isSpend: xmr_ffi.getTransactionInfoIsSpend(infoPointer),
      hash: xmr_ffi.getTransactionInfoHash(infoPointer),
      key: getTxKey(xmr_ffi.getTransactionInfoHash(infoPointer)),
      timeStamp: DateTime.fromMillisecondsSinceEpoch(
        xmr_ffi.getTransactionInfoTimestamp(infoPointer) * 1000,
      ),
      minConfirms: MinConfirms.monero,
    );
  }

  // ===========================================================================
  //  ==== static factory constructor functions ================================

  /// Creates a new Monero wallet with the specified parameters and seed type.
  ///
  /// This function initializes a new [MoneroWallet] instance at the specified path
  /// and with the provided password. The type of seed generated depends on the
  /// [MoneroSeedType] parameter. Optionally, it allows creating a deprecated
  /// 14-word seed wallet if necessary.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be created.
  /// - **password** (`String`, required): The password used to secure the wallet.
  /// - **language** (`String`, optional): The mnemonic language for seed generation.
  ///   Defaults to `"English"`.
  /// - **seedType** (`MoneroSeedType`, required): Specifies the seed type for the wallet:
  ///   - `sixteen`: 16-word seed (uses polyseed).
  ///   - `twentyFive`: 25-word seed.
  /// - **networkType** (`int`, optional): Specifies the Monero network type:
  ///   - `0`: Mainnet (default).
  ///   - `1`: Testnet.
  ///   - `2`: Stagenet.
  ///
  /// ### Returns:
  /// A `Future` that resolves to an instance of [MoneroWallet] once the wallet
  /// is successfully created.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = await MoneroWallet.create(
  ///   path: '/path/to/new_wallet',
  ///   password: 'secure_password',
  ///   seedType: MoneroSeedType.twentyFive,
  ///   networkType: 0,
  /// );
  /// ```
  static Future<MoneroWallet> create({
    required String path,
    required String password,
    String language = "English",
    required MoneroSeedType seedType,
    int networkType = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final Pointer<Void> walletPointer;
    switch (seedType) {
      case MoneroSeedType.sixteen:
        final seed = xmr_ffi.createPolyseed(language: language);
        walletPointer = Pointer<Void>.fromAddress(
          await Isolate.run(
            () => xmr_wm_ffi
                .createWalletFromPolyseed(
                  Pointer.fromAddress(walletManagerPointerAddress),
                  path: path,
                  password: password,
                  mnemonic: seed,
                  seedOffset: "",
                  newWallet: true,
                  restoreHeight: 0, // ignored by core underlying code
                  kdfRounds: 1,
                )
                .address,
          ),
        );
        break;

      case MoneroSeedType.twentyFive:
        walletPointer = Pointer<Void>.fromAddress(
          await Isolate.run(
            () => xmr_wm_ffi
                .createWallet(
                  Pointer.fromAddress(walletManagerPointerAddress),
                  path: path,
                  password: password,
                  language: language,
                  networkType: networkType,
                )
                .address,
          ),
        );
        break;
    }

    xmr_ffi.checkWalletStatus(walletPointer);

    final address = walletPointer.address;
    await Isolate.run(() {
      xmr_ffi.storeWallet(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(walletPointer);
    return wallet;
  }

  /// Restores a Monero wallet from a mnemonic seed phrase.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password used to encrypt the wallet file.
  /// - **seed** (`String`, required): The mnemonic seed phrase for restoring the wallet.
  /// - **networkType** (`int`, optional): Specifies the Monero network type to use:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///   NOTE: THIS IS ONLY USED BY 25 WORD SEEDS!
  ///
  /// ### Returns:
  /// A `Future` that resolves to an instance of [MoneroWallet] upon successful restoration.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = await MoneroWallet.restoreWalletFromSeed(
  ///   path: '/path/to/wallet',
  ///   password: 'secure_password',
  ///   seed: 'mnemonic seed phrase here',
  ///   networkType: 0,
  ///   restoreHeight: 200000, // Start from a specific block height
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the wallet cannot be restored due to an invalid seed,
  /// incorrect path, or other issues.
  static Future<MoneroWallet> restoreWalletFromSeed({
    required String path,
    required String password,
    required String seed,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final Pointer<Void> walletPointer;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      walletPointer = Pointer<Void>.fromAddress(
        await Isolate.run(
          () => xmr_wm_ffi
              .recoveryWallet(
                Pointer.fromAddress(walletManagerPointerAddress),
                path: path,
                password: password,
                mnemonic: seed,
                restoreHeight: restoreHeight,
                seedOffset: "",
                networkType: networkType,
              )
              .address,
        ),
      );
    } else if (seedLength == 16) {
      walletPointer = Pointer<Void>.fromAddress(
        await Isolate.run(
          () => xmr_wm_ffi
              .createWalletFromPolyseed(
                Pointer.fromAddress(walletManagerPointerAddress),
                path: path,
                password: password,
                mnemonic: seed,
                seedOffset: "",
                newWallet: false,
                restoreHeight: 0, // ignored by core underlying code
                kdfRounds: 1,
                networkType: networkType,
              )
              .address,
        ),
      );
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    xmr_ffi.checkWalletStatus(walletPointer);

    final address = walletPointer.address;
    await Isolate.run(() {
      xmr_ffi.storeWallet(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(walletPointer);
    return wallet;
  }

  /// Creates a view-only Monero wallet.
  ///
  /// This function initializes a view-only [MoneroWallet] instance, which allows the
  /// user to monitor incoming transactions and view their wallet balance without
  /// having spending capabilities. This is useful for scenarios where tracking
  /// wallet activity is required without spending authority.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the view-only wallet will be stored.
  /// - **password** (`String`, required): The password to encrypt the wallet file.
  /// - **address** (`String`, required): The public address associated with the wallet.
  /// - **viewKey** (`String`, required): The private view key, granting read access
  ///   to the wallet's transaction history.
  /// - **networkType** (`int`, optional): Specifies the Monero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// A new instance of [MoneroWallet] with view-only access, allowing tracking
  /// of the specified wallet without spending permissions.
  ///
  /// ### Example:
  /// ```dart
  /// final viewOnlyWallet = MoneroWallet.createViewOnlyWallet(
  ///   path: '/path/to/view_only_wallet',
  ///   password: 'secure_password',
  ///   address: 'public_address_here',
  ///   viewKey: 'view_key_here',
  ///   networkType: 0,
  ///   restoreHeight: 50000, // Sync from a specific block height
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the provided address or view key is invalid, or if the wallet
  /// cannot be created due to other issues.
  ///
  /// ### Notes:
  /// - This wallet type allows viewing incoming transactions and balance but
  ///   does not grant spending capability.
  static Future<MoneroWallet> createViewOnlyWallet({
    required String path,
    required String password,
    required String address,
    required String viewKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) async =>
      await restoreWalletFromKeys(
        path: path,
        password: password,
        language: "", // not used when the viewKey is not empty
        address: address,
        viewKey: viewKey,
        spendKey: "",
        networkType: networkType,
        restoreHeight: restoreHeight,
      );

  /// Restores a Monero wallet from private keys and address.
  ///
  /// This function creates a new [MoneroWallet] instance from the provided
  /// address, view key, and spend key, allowing recovery of a previously
  /// existing wallet. Specify the wallet file’s path, password, and optional
  /// network type and restore height to customize the wallet creation process.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password to encrypt the wallet file.
  /// - **language** (`String`, required): The mnemonic language for any future
  ///   seed generation.
  /// - **address** (`String`, required): The public address of the wallet to restore.
  /// - **viewKey** (`String`, required): The private view key associated with the wallet.
  /// - **spendKey** (`String`, required): The private spend key associated with the wallet.
  /// - **networkType** (`int`, optional): Specifies the Monero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// An instance of [MoneroWallet] representing the restored wallet.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = MoneroWallet.restoreWalletFromKeys(
  ///   path: '/path/to/wallet',
  ///   password: 'secure_password',
  ///   language: 'English',
  ///   address: 'public_address_here',
  ///   viewKey: 'view_key_here',
  ///   spendKey: 'spend_key_here',
  ///   networkType: 0,
  ///   restoreHeight: 100000, // Start syncing from a specific block height
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the provided keys or address are invalid, or if the wallet
  /// cannot be restored due to other issues.
  static Future<MoneroWallet> restoreWalletFromKeys({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final walletPointer = Pointer<Void>.fromAddress(
      await Isolate.run(
        () => xmr_wm_ffi
            .createWalletFromKeys(
              Pointer.fromAddress(walletManagerPointerAddress),
              path: path,
              password: password,
              language: language,
              addressString: address,
              viewKeyString: viewKey,
              spendKeyString: spendKey,
              networkType: networkType,
              restoreHeight: restoreHeight,
            )
            .address,
      ),
    );

    xmr_ffi.checkWalletStatus(walletPointer);

    final wallet = MoneroWallet._(walletPointer);
    return wallet;
  }

  /// Restores a Monero wallet and creates a seed from a private spend key.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password to encrypt the wallet file.
  /// - **language** (`String`, required): The mnemonic language for any future
  ///   seed generation or wallet recovery prompts.
  /// - **spendKey** (`String`, required): The private spend key associated with the wallet.
  /// - **networkType** (`int`, optional): Specifies the Monero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// An instance of [MoneroWallet] representing the restored wallet with full access
  /// to the funds associated with the given spend key.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = MoneroWallet.restoreDeterministicWalletFromSpendKey(
  ///   path: '/path/to/wallet',
  ///   password: 'secure_password',
  ///   language: 'English',
  ///   spendKey: 'spend_key_here',
  ///   networkType: 0,
  ///   restoreHeight: 100000, // Start syncing from a specific block height
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the provided spend key is invalid, or if the wallet cannot be
  /// restored due to other I/O issues.
  ///
  /// ### Notes:
  /// - This method is useful for users who have lost their mnemonic seed but still have
  ///   access to their spend key. It allows for full wallet recovery, including access
  ///   to balances and transaction history.
  static Future<MoneroWallet> restoreDeterministicWalletFromSpendKey({
    required String path,
    required String password,
    required String language,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final walletPointer = Pointer<Void>.fromAddress(
      await Isolate.run(
        () => xmr_wm_ffi
            .createDeterministicWalletFromSpendKey(
              Pointer.fromAddress(walletManagerPointerAddress),
              path: path,
              password: password,
              language: language,
              spendKeyString: spendKey,
              newWallet: true,
              restoreHeight: restoreHeight,
              networkType: networkType,
            )
            .address,
      ),
    );

    xmr_ffi.checkWalletStatus(walletPointer);

    final wallet = MoneroWallet._(walletPointer);
    await wallet.save();
    return wallet;
  }

  /// Loads an existing Monero wallet from the specified path with the provided password.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path to the existing wallet file to be loaded.
  /// - **password** (`String`, required): The password used to decrypt the wallet file.
  /// - **networkType** (`int`, optional): Specifies the Monero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  ///
  /// ### Returns:
  /// An instance of [MoneroWallet] representing the loaded wallet.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = MoneroWallet.loadWallet(
  ///   path: '/path/to/existing_wallet',
  ///   password: 'secure_password',
  ///   networkType: 0,
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the wallet file cannot be found, the password is incorrect,
  /// or the file cannot be read due to other I/O issues.
  static Future<MoneroWallet> loadWallet({
    required String path,
    required String password,
    int networkType = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final walletPointer = Pointer<Void>.fromAddress(
      await Isolate.run(
        () => xmr_wm_ffi
            .openWallet(
              Pointer.fromAddress(walletManagerPointerAddress),
              path: path,
              password: password,
              networkType: networkType,
            )
            .address,
      ),
    );

    xmr_ffi.checkWalletStatus(walletPointer);

    final wallet = MoneroWallet._(walletPointer);

    return wallet;
  }

  // ===========================================================================
  // special check to see if wallet exists
  static bool isWalletExist(String path) => xmr_wm_ffi.walletExists(
        _walletManagerPointer,
        path,
      );

  // ===========================================================================
  // === Internal overrides ====================================================

  @override
  @protected
  Future<void> refreshOutputs() async {
    _coinsPointer = xmr_ffi.getCoinsPointer(_getWalletPointer());
    final pointerAddress = _coinsPointer!.address;
    await Isolate.run(() {
      xmr_ffi.refreshCoins(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  Future<void> refreshTransactions() async {
    _transactionHistoryPointer = xmr_ffi.getTransactionHistoryPointer(
      _getWalletPointer(),
    );
    final pointerAddress = _transactionHistoryPointer!.address;

    await Isolate.run(() {
      xmr_ffi.refreshTransactionHistory(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  int transactionCount() => xmr_ffi.getTransactionHistoryCount(
        _transactionHistoryPointer!,
      );

  // ===========================================================================
  // === Overrides =============================================================

  @override
  int getCurrentWalletSyncingHeight() =>
      xmr_ffi.getWalletBlockChainHeight(_getWalletPointer());

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getMoneroHeightByDate(date: date);
  }

  @override
  Future<void> connect({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  }) async {
    Logging.log?.i("init (initConnection()) node address: $daemonAddress");
    final pointerAddress = _getWalletPointer().address;

    // TODO: do something with return value?
    // return value matters? If so, whats the point of checking status below?
    final _ = await Isolate.run(() {
      return xmr_ffi.initWallet(
        Pointer.fromAddress(pointerAddress),
        daemonAddress: daemonAddress,
        daemonUsername: daemonUsername ?? "",
        daemonPassword: daemonPassword ?? "",
        proxyAddress: socksProxyAddress ?? "",
        useSsl: useSSL,
        lightWallet: isLightWallet,
      );
    });

    xmr_ffi.checkWalletStatus(_getWalletPointer());

    xmr_ffi.setTrustedDaemon(
      _getWalletPointer(),
      arg: trusted,
    );
  }

  // @override
  // Future<bool> createViewOnlyWalletFromCurrentWallet({
  //   required String path,
  //   required String password,
  //   String language = "English",
  // }) async {
  //   return await Isolate.run(
  //     () => monero.Wallet_createWatchOnly(
  //       _getWalletPointer(),
  //       path: path,
  //       password: password,
  //       language: language,
  //     ),
  //   );
  // }

  @override
  bool isViewOnly() {
    final isWatchOnly = xmr_ffi.isWatchOnly(_getWalletPointer());
    return isWatchOnly;
  }

  // @override
  // void setProxyUri(String proxyUri) {
  //   monero.Wallet_setProxy(_getWalletPointer(), address: proxyUri);
  // }

  @override
  Future<bool> isConnectedToDaemon() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return xmr_ffi.isConnected(Pointer.fromAddress(address));
    });
    return result == 1;
  }

  @override
  Future<bool> isSynced() async {
    // So `Wallet_synchronized` will return true even if doing a rescan.
    // As such, we'll just do an approximation and assume (probably wrongly so)
    // that current sync/scan height and daemon height calls will return sane
    // values.
    final current = getCurrentWalletSyncingHeight();
    final daemonHeight = getDaemonHeight();

    // if difference is less than an arbitrary low but non zero value, then make
    // the call to `Wallet_synchronized`
    if (daemonHeight > 0 && daemonHeight - current < 10) {
      final address = _getWalletPointer().address;
      final result = await Isolate.run(() {
        return xmr_ffi.isSynchronized(Pointer.fromAddress(address));
      });
      return result;
    }

    return false;
  }

  @override
  String getPath() {
    final path = xmr_ffi.getWalletPath(_getWalletPointer());
    return path;
  }

  @override
  String getSeed() {
    final polySeed = xmr_ffi.getWalletPolyseed(
      _getWalletPointer(),
      passphrase: "",
    );
    if (polySeed != "") {
      return polySeed;
    }
    final legacy = xmr_ffi.getWalletSeed(_getWalletPointer(), seedOffset: "");
    return legacy;
  }

  @override
  String getSeedLanguage() {
    final language = xmr_ffi.getWalletSeedLanguage(_getWalletPointer());
    return language;
  }

  @override
  String getPrivateSpendKey() {
    return xmr_ffi.getWalletSecretSpendKey(_getWalletPointer());
  }

  @override
  String getPrivateViewKey() {
    return xmr_ffi.getWalletSecretViewKey(_getWalletPointer());
  }

  @override
  String getPublicSpendKey() {
    return xmr_ffi.getWalletPublicSpendKey(_getWalletPointer());
  }

  @override
  String getPublicViewKey() {
    return xmr_ffi.getWalletPublicViewKey(_getWalletPointer());
  }

  @override
  Address getAddress({int accountIndex = 0, int addressIndex = 0}) {
    final address = Address(
      value: xmr_ffi.getWalletAddress(
        _getWalletPointer(),
        accountIndex: accountIndex,
        addressIndex: addressIndex,
      ),
      account: accountIndex,
      index: addressIndex,
    );

    return address;
  }

  @override
  int getDaemonHeight() {
    return xmr_ffi.getDaemonBlockChainHeight(_getWalletPointer());
  }

  @override
  int getRefreshFromBlockHeight() =>
      xmr_ffi.getWalletRefreshFromBlockHeight(_getWalletPointer());

  @override
  void setRefreshFromBlockHeight(int startHeight) {
    xmr_ffi.setWalletRefreshFromBlockHeight(
      _getWalletPointer(),
      refreshFromBlockHeight: startHeight,
    );
  }

  @override
  void startSyncing({Duration interval = const Duration(seconds: 10)}) {
    // 10 seconds seems to be the default in monero core
    xmr_ffi.setWalletAutoRefreshInterval(
      _getWalletPointer(),
      millis: interval.inMilliseconds,
    );
    xmr_ffi.refreshWalletAsync(_getWalletPointer());
    xmr_ffi.startWalletRefresh(_getWalletPointer());
  }

  @override
  void stopSyncing() {
    xmr_ffi.pauseWalletRefresh(_getWalletPointer());
    xmr_ffi.stopWallet(_getWalletPointer());
  }

  // /// returns true on success
  // @override
  // Future<bool> rescanSpent() async {
  //   final address = _getWalletPointer().address;
  //   final result = await Isolate.run(() {
  //     return monero.Wallet_rescanSpent(Pointer.fromAddress(address));
  //   });
  //   return result;
  // }

  /// returns true on success
  @override
  Future<bool> rescanBlockchain() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return xmr_ffi.rescanWalletBlockchain(Pointer.fromAddress(address));
    });
    return result;
  }

  @override
  BigInt getBalance({int accountIndex = 0}) => BigInt.from(
        xmr_ffi.getWalletBalance(
          _getWalletPointer(),
          accountIndex: accountIndex,
        ),
      );

  @override
  BigInt getUnlockedBalance({int accountIndex = 0}) => BigInt.from(
        xmr_ffi.getWalletUnlockedBalance(
          _getWalletPointer(),
          accountIndex: accountIndex,
        ),
      );

  // @override
  // List<Account> getAccounts({bool includeSubaddresses = false, String? tag}) {
  //   final accountsCount =
  //       monero.Wallet_numSubaddressAccounts(_getWalletPointer());
  //   final accountsPointer =
  //       monero.Wallet_subaddressAccount(_getWalletPointer());
  //   final accountsSize = monero.AddressBook_getAll_size(accountsPointer);
  //
  //   print("accountsSize: $accountsSize");
  //   print("accountsCount: $accountsCount");
  //
  //   final List<Account> accounts = [];
  //
  //   for (int i = 0; i < accountsCount; i++) {
  //     final primaryAddress = getAddress(accountIndex: i, addressIndex: 0);
  //     final List<Address> subAddresses = [];
  //
  //     if (includeSubaddresses) {
  //       final subaddressCount = monero.Wallet_numSubaddresses(
  //         _getWalletPointer(),
  //         accountIndex: i,
  //       );
  //       for (int j = 0; j < subaddressCount; j++) {
  //         final address = getAddress(accountIndex: i, addressIndex: j);
  //         subAddresses.add(address);
  //       }
  //     }
  //
  //     final account = Account(
  //       index: i,
  //       primaryAddress: primaryAddress.value,
  //       balance: BigInt.from(getBalance(accountIndex: i)),
  //       unlockedBalance: BigInt.from(getUnlockedBalance(accountIndex: i)),
  //       subaddresses: subAddresses,
  //     );
  //
  //     accounts.add(account);
  //   }
  //
  //   return accounts;
  //
  //   // throw UnimplementedError("TODO");
  // }
  //
  // @override
  // Account getAccount(int accountIdx, {bool includeSubaddresses = false}) {
  //   throw UnimplementedError("TODO");
  // }
  //
  // @override
  // void createAccount({String? label}) {
  //   monero.Wallet_addSubaddressAccount(_getWalletPointer(), label: label ?? "");
  // }
  //
  // @override
  // void setAccountLabel(int accountIdx, String label) {
  //   throw UnimplementedError("TODO");
  // }
  //
  // @override
  // void setSubaddressLabel(int accountIdx, int addressIdx, String label) {
  //   monero.Wallet_setSubaddressLabel(
  //     _getWalletPointer(),
  //     accountIndex: accountIdx,
  //     addressIndex: addressIdx,
  //     label: label,
  //   );
  // }

  @override
  String getTxKey(String txid) {
    return xmr_ffi.getTxKey(_getWalletPointer(), txid: txid);
  }

  @override
  Future<Transaction> getTx(String txid, {bool refresh = false}) async {
    if (refresh) {
      await refreshTransactions();
    }

    return _transactionFrom(
      xmr_ffi.getTransactionInfoPointerByTxid(
        _transactionHistoryPointer!,
        txid: txid,
      ),
    );
  }

  @override
  Future<List<Transaction>> getTxs({bool refresh = false}) async {
    if (refresh) {
      await refreshTransactions();
    }

    final size = transactionCount();

    return List.generate(
      size,
      (index) => _transactionFrom(
        xmr_ffi.getTransactionInfoPointer(
          _transactionHistoryPointer!,
          index: index,
        ),
      ),
    );
  }

  @override
  Future<List<Output>> getOutputs({
    bool includeSpent = false,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        await refreshOutputs();
      }
      final count = xmr_ffi.getCoinsCount(_coinsPointer!);

      Logging.log?.i("monero outputs found=$count");

      final List<Output> result = [];

      for (int i = 0; i < count; i++) {
        final coinInfoPointer = xmr_ffi.getCoinInfoPointer(_coinsPointer!, i);

        final hash = xmr_ffi.getHashForCoinsInfo(coinInfoPointer);

        if (hash.isNotEmpty) {
          final spent = xmr_ffi.isSpentCoinsInfo(coinInfoPointer);

          if (includeSpent || !spent) {
            final utxo = Output(
              address: xmr_ffi.getAddressForCoinsInfo(coinInfoPointer),
              hash: hash,
              keyImage: xmr_ffi.getKeyImageForCoinsInfo(coinInfoPointer),
              value:
                  BigInt.from(xmr_ffi.getAmountForCoinsInfo(coinInfoPointer)),
              isFrozen: xmr_ffi.isFrozenCoinsInfo(coinInfoPointer),
              isUnlocked: xmr_ffi.isUnlockedCoinsInfo(coinInfoPointer),
              vout: xmr_ffi.getInternalOutputIndexForCoinsInfo(coinInfoPointer),
              spent: spent,
              spentHeight: spent
                  ? xmr_ffi.getSpentHeightForCoinsInfo(coinInfoPointer)
                  : null,
              height: xmr_ffi.getBlockHeightForCoinsInfo(coinInfoPointer),
              coinbase: xmr_ffi.isCoinbaseCoinsInfo(coinInfoPointer),
            );

            result.add(utxo);
          }
        } else {
          Logging.log?.w("Found empty hash in monero utxo?!");
        }
      }

      return result;
    } catch (e, s) {
      Logging.log?.w("getOutputs failed", error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> exportKeyImages({
    required String filename,
    bool all = false,
  }) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return xmr_ffi.exportWalletKeyImages(
        Pointer<Void>.fromAddress(pointerAddress),
        filename,
        all: all,
      );
    });
  }

  @override
  Future<bool> importKeyImages({required String filename}) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return xmr_ffi.importWalletKeyImages(
        Pointer<Void>.fromAddress(pointerAddress),
        filename,
      );
    });
  }

  @override
  Future<void> freezeOutput(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted freeze of empty keyImage.");
    }

    final count = xmr_ffi.getAllCoinsSize(_coinsPointer!);
    for (int i = 0; i < count; i++) {
      if (keyImage ==
          xmr_ffi.getKeyImageForCoinsInfo(
            xmr_ffi.getCoinInfoPointer(_coinsPointer!, i),
          )) {
        xmr_ffi.freezeCoin(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't freeze utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<void> thawOutput(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted thaw of empty keyImage.");
    }

    final count = xmr_ffi.getAllCoinsSize(_coinsPointer!);
    for (int i = 0; i < count; i++) {
      if (keyImage ==
          xmr_ffi.getKeyImageForCoinsInfo(
            xmr_ffi.getCoinInfoPointer(_coinsPointer!, i),
          )) {
        xmr_ffi.thawCoin(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't thaw utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<PendingTransaction> createTx({
    required Recipient output,
    required TransactionPriority priority,
    required int accountIndex,
    List<Output>? preferredInputs,
    String paymentId = "",
    bool sweep = false,
  }) async {
    final List<String>? processedInputs;
    if (preferredInputs != null) {
      processedInputs = await checkAndProcessInputs(
        inputs: preferredInputs,
        sendAmount: output.amount,
        sweep: sweep,
      );
    } else {
      processedInputs = null;
    }
    final inputsToUse = preferredInputs ?? <Output>[];

    try {
      final walletPointerAddress = _getWalletPointer().address;
      final pendingTxPointer = Pointer<Void>.fromAddress(
        await Isolate.run(() {
          final tx = xmr_ffi.createTransaction(
            Pointer.fromAddress(walletPointerAddress),
            address: output.address,
            paymentId: paymentId,
            amount: sweep ? 0 : output.amount.toInt(),
            pendingTransactionPriority: priority.value,
            subaddressAccount: accountIndex,
            preferredInputs: inputsToUse.map((e) => e.keyImage).toList(),
          );
          return tx.address;
        }),
      );

      xmr_ffi.checkPendingTransactionStatus(pendingTxPointer);

      return PendingTransaction(
        amount:
            BigInt.from(xmr_ffi.getPendingTransactionAmount(pendingTxPointer)),
        fee: BigInt.from(xmr_ffi.getPendingTransactionFee(pendingTxPointer)),
        txid: xmr_ffi.getPendingTransactionTxid(pendingTxPointer),
        hex: xmr_ffi.getPendingTransactionHex(pendingTxPointer),
        pointerAddress: pendingTxPointer.address,
      );
    } finally {
      if (processedInputs != null) {
        await postProcessInputs(keyImages: processedInputs);
      }
    }
  }

  @override
  Future<PendingTransaction> createTxMultiDest({
    required List<Recipient> outputs,
    required TransactionPriority priority,
    required int accountIndex,
    String paymentId = "",
    List<Output>? preferredInputs,
    bool sweep = false,
  }) async {
    final List<String>? processedInputs;
    if (preferredInputs != null) {
      processedInputs = await checkAndProcessInputs(
        inputs: preferredInputs,
        sendAmount: outputs.map((e) => e.amount).fold(
              BigInt.zero,
              (p, e) => p + e,
            ),
        sweep: sweep,
      );
    } else {
      processedInputs = null;
    }
    final inputsToUse = preferredInputs ?? <Output>[];

    try {
      final walletPointerAddress = _getWalletPointer().address;
      final pendingTxPointer = Pointer<Void>.fromAddress(
        await Isolate.run(() {
          final tx = xmr_ffi.createTransactionMultiDest(
            Pointer.fromAddress(walletPointerAddress),
            paymentId: paymentId,
            addresses: outputs.map((e) => e.address).toList(),
            isSweepAll: sweep,
            amounts: outputs.map((e) => e.amount.toInt()).toList(),
            pendingTransactionPriority: priority.value,
            subaddressAccount: accountIndex,
            preferredInputs: inputsToUse.map((e) => e.keyImage).toList(),
          );
          return tx.address;
        }),
      );

      xmr_ffi.checkPendingTransactionStatus(pendingTxPointer);

      return PendingTransaction(
        amount:
            BigInt.from(xmr_ffi.getPendingTransactionAmount(pendingTxPointer)),
        fee: BigInt.from(xmr_ffi.getPendingTransactionFee(pendingTxPointer)),
        txid: xmr_ffi.getPendingTransactionTxid(
          pendingTxPointer,
        ),
        hex: xmr_ffi.getPendingTransactionHex(
          pendingTxPointer,
        ),
        pointerAddress: pendingTxPointer.address,
      );
    } finally {
      if (processedInputs != null) {
        await postProcessInputs(keyImages: processedInputs);
      }
    }
  }

  @override
  Future<void> commitTx(PendingTransaction tx) async {
    // TODO: check if the return value should be used in any way or if it is ok to rely on the status check below?
    final _ = await Isolate.run(() {
      return xmr_ffi.commitPendingTransaction(
        Pointer<Void>.fromAddress(
          tx.pointerAddress,
        ),
      );
    });

    xmr_ffi.checkPendingTransactionStatus(
      Pointer<Void>.fromAddress(
        tx.pointerAddress,
      ),
    );
  }

  @override
  Future<String> signMessage(
    String message,
    String address,
  ) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return xmr_ffi.signMessageWith(
        Pointer.fromAddress(pointerAddress),
        message: message,
        address: address,
      );
    });
  }

  @override
  Future<bool> verifyMessage(
    String message,
    String address,
    String signature,
  ) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return xmr_ffi.verifySignedMessageWithWallet(
        Pointer.fromAddress(pointerAddress),
        message: message,
        address: address,
        signature: signature,
      );
    });
  }

  // @override
  // String getPaymentUri(TxConfig request) {
  //   throw UnimplementedError("TODO");
  // }

  @override
  BigInt? amountFromString(String value) {
    try {
      // not sure what protections or validation is done internally
      // so lets do some extra for now
      double.parse(value);

      // if that parse succeeded the following should produce a valid result

      return BigInt.from(xmr_ffi.amountFromString(value));
    } catch (e, s) {
      Logging.log?.w(
        "amountFromString failed to parse \"$value\"",
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  String getPassword() {
    return xmr_ffi.getWalletPassword(_getWalletPointer());
  }

  @override
  void changePassword(String newPassword) {
    xmr_ffi.setWalletPassword(_getWalletPointer(), password: newPassword);
  }

  @override
  Future<void> save() async {
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      xmr_ffi.storeWallet(Pointer.fromAddress(pointerAddress), path: "");
    });
  }

  // TODO probably get rid of this. Not a good API/Design
  bool isClosing = false;
  @override
  Future<void> close({bool save = false}) async {
    if (isClosed() || isClosing) return;
    isClosing = true;
    stopSyncing();
    stopListeners();

    if (save) {
      await this.save();
    }

    xmr_wm_ffi.closeWallet(_walletManagerPointer, _getWalletPointer(), save);
    _walletPointer = null;
    isClosing = false;
  }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
