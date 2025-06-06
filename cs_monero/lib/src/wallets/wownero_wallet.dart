import 'dart:ffi';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../../cs_monero.dart';
import '../deprecated/get_height_by_date.dart';
import '../ffi_bindings/wownero_wallet_bindings.dart' as wow_ffi;
import '../ffi_bindings/wownero_wallet_manager_bindings.dart' as wow_wm_ffi;

const _kFourteenWordSeedCacheKey = "cs_monero.fourteen.seed";

class WowneroWallet extends Wallet {
  // internal constructor
  WowneroWallet._(Pointer<Void> pointer) : _walletPointer = pointer;

  // shared pointer
  static Pointer<Void>? _walletManagerPointerCached;
  static final Pointer<Void> _walletManagerPointer = Pointer.fromAddress(
    (() {
      try {
        // wownero.printStarts = true;
        _walletManagerPointerCached ??= wow_wm_ffi.getWalletManager();
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
        "WowneroWallet was closed!",
      );
    }
    return _walletPointer!;
  }

  // ===========================================================================
  //  ==== private helpers =====================================================

  Future<Transaction> _transactionFrom(Pointer<Void> infoPointer) async {
    final address = infoPointer.address;
    final walletPtrAddress = _getWalletPointer().address;

    final txData = await Isolate.run(() {
      final infoPointer = Pointer<Void>.fromAddress(address);

      final txid = wow_ffi.getTransactionInfoHash(infoPointer);

      final key = wow_ffi.getTxKey(
        Pointer.fromAddress(walletPtrAddress),
        txid: txid,
      );

      return Transaction(
        displayLabel: wow_ffi.getTransactionInfoLabel(infoPointer),
        description: wow_ffi.getTransactionInfoDescription(infoPointer),
        fee: BigInt.from(wow_ffi.getTransactionInfoFee(infoPointer)),
        confirmations: wow_ffi.getTransactionInfoConfirmations(infoPointer),
        blockHeight: wow_ffi.getTransactionInfoBlockHeight(infoPointer),
        accountIndex: wow_ffi.getTransactionInfoAccount(infoPointer),
        addressIndexes: wow_ffi.getTransactionSubaddressIndexes(infoPointer),
        paymentId: wow_ffi.getTransactionInfoPaymentId(infoPointer),
        amount: BigInt.from(wow_ffi.getTransactionInfoAmount(infoPointer)),
        isSpend: wow_ffi.getTransactionInfoIsSpend(infoPointer),
        hash: txid,
        key: key,
        timeStamp: DateTime.fromMillisecondsSinceEpoch(
          wow_ffi.getTransactionInfoTimestamp(infoPointer) * 1000,
        ),
        minConfirms: MinConfirms.monero,
      ).toMap();
    });

    return Transaction.fromMap(txData);
  }

  // ===========================================================================
  //  ==== static factory constructor functions ================================

  /// Creates a new Wownero wallet with the specified parameters and seed type.
  ///
  /// This function initializes a new [WowneroWallet] instance at the specified path
  /// and with the provided password. The type of seed generated depends on the
  /// [WowneroSeedType] parameter. Optionally, it allows creating a deprecated
  /// 14-word seed wallet if necessary.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be created.
  /// - **password** (`String`, required): The password used to secure the wallet.
  /// - **language** (`String`, optional): The mnemonic language for seed generation.
  ///   Defaults to `"English"`.
  /// - **seedType** (`WowneroSeedType`, required): Specifies the seed type for the wallet:
  ///   - `fourteen`: 14-word seed (deprecated).
  ///   - `sixteen`: 16-word seed (uses polyseed).
  ///   - `twentyFive`: 25-word seed.
  /// - **networkType** (`int`, optional): Specifies the Wownero network type:
  ///   - `0`: Mainnet (default).
  ///   - `1`: Testnet.
  ///   - `2`: Stagenet.
  /// - **overrideDeprecated14WordSeedException** (`bool`, optional): If `true`, allows
  ///   creation of a 14-word seed wallet despite its deprecation. Defaults to `false`.
  ///
  /// ### Returns:
  /// A `Future` that resolves to an instance of [WowneroWallet] once the wallet
  /// is successfully created.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = await WowneroWallet.create(
  ///   path: '/path/to/new_wallet',
  ///   password: 'secure_password',
  ///   seedType: WowneroSeedType.twentyFive,
  ///   networkType: 0,
  /// );
  /// ```
  static Future<WowneroWallet> create({
    required String path,
    required String password,
    String language = "English",
    required WowneroSeedType seedType,
    int networkType = 0,
    bool overrideDeprecated14WordSeedException = false,
    String seedOffset = "",
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final Pointer<Void> walletPointer;

    switch (seedType) {
      case WowneroSeedType.fourteen:
        if (!overrideDeprecated14WordSeedException) {
          throw Exception(
            "New 14 word seed wallet creation is deprecated. "
            "If you really need this, "
            "set overrideDeprecated14WordSeedException to true.",
          );
        }

        walletPointer = await Isolate.run(() {
          return wow_ffi.create14WordSeed(
            path: path,
            password: password,
            language: language,
            networkType: networkType,
          );
        });
        final address = walletPointer.address;

        // get the generated seed
        final seed = await Isolate.run(() {
          return wow_ffi.getWalletCacheAttribute(
            Pointer.fromAddress(address),
            key: "cake.seed",
          );
        });
        // store generated seed with the correct cache key
        await Isolate.run(() {
          return wow_ffi.setWalletCacheAttribute(
            Pointer.fromAddress(address),
            key: _kFourteenWordSeedCacheKey,
            value: seed,
          );
        });
        break;

      case WowneroSeedType.sixteen:
        final seed = wow_ffi.createPolyseed(language: language);
        walletPointer = Pointer<Void>.fromAddress(
          await Isolate.run(
            () => wow_wm_ffi
                .createWalletFromPolyseed(
                  Pointer.fromAddress(walletManagerPointerAddress),
                  path: path,
                  password: password,
                  mnemonic: seed,
                  seedOffset: seedOffset,
                  newWallet: true,
                  restoreHeight: 0, // ignored by core underlying code
                  kdfRounds: 1,
                )
                .address,
          ),
        );
        break;

      case WowneroSeedType.twentyFive:
        walletPointer = Pointer<Void>.fromAddress(
          await Isolate.run(
            () => wow_wm_ffi
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

    wow_ffi.checkWalletStatus(walletPointer);

    final address = walletPointer.address;
    await Isolate.run(() {
      wow_ffi.storeWallet(Pointer.fromAddress(address), path: path);
    });

    final wallet = WowneroWallet._(walletPointer);
    return wallet;
  }

  /// Restores a Wownero wallet from a mnemonic seed phrase.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password used to encrypt the wallet file.
  /// - **seed** (`String`, required): The mnemonic seed phrase for restoring the wallet.
  /// - **networkType** (`int`, optional): Specifies the Wownero network type to use:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///   NOTE: THIS IS ONLY USED BY 25 WORD SEEDS!
  ///
  /// ### Returns:
  /// A `Future` that resolves to an instance of [WowneroWallet] upon successful restoration.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = await WowneroWallet.restoreWalletFromSeed(
  ///   path: '/path/to/wallet',
  ///   password: 'secure_password',
  ///   seed: 'mnemonic seed phrase here',
  ///   networkType: 0,
  ///   restoreHeight: 200000, // Start from a specific block height
  /// );
  /// ```
  static Future<WowneroWallet> restoreWalletFromSeed({
    required String path,
    required String password,
    required String seed,
    int networkType = 0,
    int restoreHeight = 0,
    String seedOffset = "",
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final Pointer<Void> walletPointer;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      walletPointer = Pointer<Void>.fromAddress(
        await Isolate.run(
          () => wow_wm_ffi
              .recoveryWallet(
                Pointer.fromAddress(walletManagerPointerAddress),
                path: path,
                password: password,
                mnemonic: seed,
                restoreHeight: restoreHeight,
                seedOffset: seedOffset,
                networkType: networkType,
              )
              .address,
        ),
      );
    } else if (seedLength == 16) {
      walletPointer = Pointer<Void>.fromAddress(
        await Isolate.run(
          () => wow_wm_ffi
              .createWalletFromPolyseed(
                Pointer.fromAddress(walletManagerPointerAddress),
                path: path,
                password: password,
                mnemonic: seed,
                seedOffset: seedOffset,
                newWallet: false,
                restoreHeight: 0, // ignored by core underlying code
                kdfRounds: 1,
                networkType: networkType,
              )
              .address,
        ),
      );
    } else if (seedLength == 14) {
      walletPointer = await Isolate.run(() {
        return wow_ffi.restore14WordSeed(
          path: path,
          password: password,
          language: seed, // yes the "language" param is misnamed
          networkType: networkType,
        );
      });
      final walletPointerAddress = walletPointer.address;
      restoreHeight = await Isolate.run(() {
        return wow_ffi.getWalletRefreshFromBlockHeight(
          Pointer.fromAddress(walletPointerAddress),
        );
      });
      // store seed with the correct cache key
      await Isolate.run(() {
        return wow_ffi.setWalletCacheAttribute(
          Pointer.fromAddress(walletPointerAddress),
          key: _kFourteenWordSeedCacheKey,
          value: seed,
        );
      });
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    wow_ffi.checkWalletStatus(walletPointer);

    final walletPointerAddress = walletPointer.address;
    await Isolate.run(() {
      wow_ffi.storeWallet(
        Pointer.fromAddress(walletPointerAddress),
        path: path,
      );
    });

    final wallet = WowneroWallet._(walletPointer);
    return wallet;
  }

  /// Creates a view-only Wownero wallet.
  ///
  /// This function initializes a view-only [WowneroWallet] instance, which allows the
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
  /// - **networkType** (`int`, optional): Specifies the Wownero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// A new instance of [WowneroWallet] with view-only access, allowing tracking
  /// of the specified wallet without spending permissions.
  ///
  /// ### Example:
  /// ```dart
  /// final viewOnlyWallet = WowneroWallet.createViewOnlyWallet(
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
  static Future<WowneroWallet> createViewOnlyWallet({
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

  /// Restores a Wownero wallet from private keys and address.
  ///
  /// This function creates a new [WowneroWallet] instance from the provided
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
  /// - **networkType** (`int`, optional): Specifies the Wownero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// An instance of [WowneroWallet] representing the restored wallet.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = WowneroWallet.restoreWalletFromKeys(
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
  static Future<WowneroWallet> restoreWalletFromKeys({
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
        () => wow_wm_ffi
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

    wow_ffi.checkWalletStatus(walletPointer);

    final wallet = WowneroWallet._(walletPointer);
    return wallet;
  }

  /// Restores a Wownero wallet and creates a seed from a private spend key.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password to encrypt the wallet file.
  /// - **language** (`String`, required): The mnemonic language for any future
  ///   seed generation or wallet recovery prompts.
  /// - **spendKey** (`String`, required): The private spend key associated with the wallet.
  /// - **networkType** (`int`, optional): Specifies the Wownero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  /// - **restoreHeight** (`int`, optional): The blockchain height from which to start
  ///   synchronizing the wallet. Defaults to `0`, starting from the genesis block.
  ///
  /// ### Returns:
  /// An instance of [WowneroWallet] representing the restored wallet with full access
  /// to the funds associated with the given spend key.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = WowneroWallet.restoreDeterministicWalletFromSpendKey(
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
  static Future<WowneroWallet> restoreDeterministicWalletFromSpendKey({
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
        () => wow_wm_ffi
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

    wow_ffi.checkWalletStatus(walletPointer);

    final wallet = WowneroWallet._(walletPointer);
    await wallet.save();
    return wallet;
  }

  /// Loads an existing Wownero wallet from the specified path with the provided password.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path to the existing wallet file to be loaded.
  /// - **password** (`String`, required): The password used to decrypt the wallet file.
  /// - **networkType** (`int`, optional): Specifies the Wownero network type:
  ///   - `0`: Mainnet (default)
  ///   - `1`: Testnet
  ///   - `2`: Stagenet
  ///
  /// ### Returns:
  /// An instance of [WowneroWallet] representing the loaded wallet.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = WowneroWallet.loadWallet(
  ///   path: '/path/to/existing_wallet',
  ///   password: 'secure_password',
  ///   networkType: 0,
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the wallet file cannot be found, the password is incorrect,
  /// or the file cannot be read due to other I/O issues.
  static Future<WowneroWallet> loadWallet({
    required String path,
    required String password,
    int networkType = 0,
  }) async {
    final walletManagerPointerAddress = _walletManagerPointer.address;
    final walletPointer = Pointer<Void>.fromAddress(
      await Isolate.run(
        () => wow_wm_ffi
            .openWallet(
              Pointer.fromAddress(walletManagerPointerAddress),
              path: path,
              password: password,
              networkType: networkType,
            )
            .address,
      ),
    );

    wow_ffi.checkWalletStatus(walletPointer);

    final wallet = WowneroWallet._(walletPointer);

    return wallet;
  }

  // ===========================================================================
  // special check to see if wallet exists
  static Future<bool> isWalletExist(String path) async {
    final address = _walletManagerPointer.address;
    return Isolate.run(() {
      return wow_wm_ffi.walletExists(
        Pointer.fromAddress(address),
        path,
      );
    });
  }

  // ===========================================================================
  // === Internal overrides ====================================================

  @override
  @protected
  Future<void> refreshOutputs() async {
    _coinsPointer = wow_ffi.getCoinsPointer(_getWalletPointer());
    final pointerAddress = _coinsPointer!.address;
    await Isolate.run(() {
      wow_ffi.refreshCoins(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  Future<void> refreshTransactions() async {
    _transactionHistoryPointer = wow_ffi.getTransactionHistoryPointer(
      _getWalletPointer(),
    );
    final pointerAddress = _transactionHistoryPointer!.address;

    await Isolate.run(() {
      wow_ffi.refreshTransactionHistory(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  Future<int> transactionCount() async {
    final address = _transactionHistoryPointer!.address;
    return await Isolate.run(() {
      return wow_ffi.getTransactionHistoryCount(
        Pointer.fromAddress(address),
      );
    });
  }

  // ===========================================================================
  // === Overrides =============================================================

  @override
  Future<int> getCurrentWalletSyncingHeight() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.getWalletBlockChainHeight(
        Pointer.fromAddress(walletPointerAddress),
      );
    });
  }

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getWowneroHeightByDate(date: date);
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
      return wow_ffi.initWallet(
        Pointer.fromAddress(pointerAddress),
        daemonAddress: daemonAddress,
        daemonUsername: daemonUsername ?? "",
        daemonPassword: daemonPassword ?? "",
        proxyAddress: socksProxyAddress ?? "",
        useSsl: useSSL,
        lightWallet: isLightWallet,
      );
    });

    wow_ffi.checkWalletStatus(_getWalletPointer());

    wow_ffi.setTrustedDaemon(
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
  //     () => wownero.Wallet_createWatchOnly(
  //       _getWalletPointer(),
  //       path: path,
  //       password: password,
  //       language: language,
  //     ),
  //   );
  // }

  @override
  Future<bool> isViewOnly() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.isWatchOnly(Pointer.fromAddress(walletPointerAddress));
    });
  }

  // @override
  // void setProxyUri(String proxyUri) {
  //   wownero.Wallet_setProxy(_getWalletPointer(), address: proxyUri);
  // }

  @override
  Future<bool> isConnectedToDaemon() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wow_ffi.isConnected(Pointer.fromAddress(address));
    });
    return result == 1;
  }

  @override
  Future<bool> isSynced() async {
    // So `Wallet_synchronized` will return true even if doing a rescan.
    // As such, we'll just do an approximation and assume (probably wrongly so)
    // that current sync/scan height and daemon height calls will return sane
    // values.
    final current = await getCurrentWalletSyncingHeight();
    final daemonHeight = await getDaemonHeight();

    // if difference is less than an arbitrary low but non zero value, then make
    // the call to `Wallet_synchronized`
    if (daemonHeight > 0 && daemonHeight - current < 10) {
      final address = _getWalletPointer().address;
      final result = await Isolate.run(() {
        return wow_ffi.isSynchronized(Pointer.fromAddress(address));
      });
      return result;
    }

    return false;
  }

  @override
  Future<String> getPath() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.getWalletPath(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<String> getSeed({String seedOffset = ""}) async {
    final walletPointerAddress = _getWalletPointer().address;

    return await Isolate.run(() {
      final fourteen = wow_ffi.getWalletCacheAttribute(
        Pointer.fromAddress(walletPointerAddress),
        key: _kFourteenWordSeedCacheKey,
      );
      if (fourteen != "") {
        return fourteen;
      }

      final polySeed = wow_ffi.getWalletPolyseed(
        Pointer.fromAddress(walletPointerAddress),
        passphrase: seedOffset,
      );
      if (polySeed != "") {
        return polySeed;
      }

      final legacy = wow_ffi.getWalletSeed(
        Pointer.fromAddress(walletPointerAddress),
        seedOffset: seedOffset,
      );
      return legacy;
    });
  }

  @override
  Future<String> getSeedLanguage() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getWalletSeedLanguage(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<String> getPrivateSpendKey() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getWalletSecretSpendKey(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<String> getPrivateViewKey() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getWalletSecretViewKey(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<String> getPublicSpendKey() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getWalletPublicSpendKey(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<String> getPublicViewKey() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getWalletPublicViewKey(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<Address> getAddress({
    int accountIndex = 0,
    int addressIndex = 0,
  }) async {
    final walletPointerAddress = _getWalletPointer().address;

    return await Isolate.run(() {
      final addressValue = wow_ffi.getWalletAddress(
        Pointer.fromAddress(walletPointerAddress),
        accountIndex: accountIndex,
        addressIndex: addressIndex,
      );

      return Address(
        value: addressValue,
        account: accountIndex,
        index: addressIndex,
      );
    });
  }

  @override
  Future<int> getDaemonHeight() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi
          .getDaemonBlockChainHeight(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<int> getRefreshFromBlockHeight() async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.getWalletRefreshFromBlockHeight(
        Pointer.fromAddress(walletPointerAddress),
      );
    });
  }

  @override
  Future<void> setRefreshFromBlockHeight(int startHeight) async {
    final walletPointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wow_ffi.setWalletRefreshFromBlockHeight(
        Pointer.fromAddress(walletPointerAddress),
        refreshFromBlockHeight: startHeight,
      );
    });
  }

  @override
  Future<void> startSyncing({
    Duration interval = const Duration(seconds: 10),
  }) async {
    final walletPointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      // 10 seconds seems to be the default in monero core
      wow_ffi.setWalletAutoRefreshInterval(
        Pointer.fromAddress(walletPointerAddress),
        millis: interval.inMilliseconds,
      );
      wow_ffi.refreshWalletAsync(Pointer.fromAddress(walletPointerAddress));
      wow_ffi.startWalletRefresh(Pointer.fromAddress(walletPointerAddress));
    });
  }

  @override
  Future<void> stopSyncing() async {
    final walletPointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wow_ffi.pauseWalletRefresh(Pointer.fromAddress(walletPointerAddress));
      wow_ffi.stopWallet(Pointer.fromAddress(walletPointerAddress));
    });
  }

  // /// returns true on success
  // @override
  // Future<bool> rescanSpent() async {
  //   final address = _getWalletPointer().address;
  //   final result = await Isolate.run(() {
  //     return wownero.Wallet_rescanSpent(Pointer.fromAddress(address));
  //   });
  //   return result;
  // }

  /// returns true on success
  @override
  Future<bool> rescanBlockchain() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wow_ffi.rescanWalletBlockchain(Pointer.fromAddress(address));
    });
    return result;
  }

  @override
  Future<BigInt> getBalance({int accountIndex = 0}) async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      final balance = wow_ffi.getWalletBalance(
        Pointer.fromAddress(walletPointerAddress),
        accountIndex: accountIndex,
      );
      return BigInt.from(balance);
    });
  }

  @override
  Future<BigInt> getUnlockedBalance({int accountIndex = 0}) async {
    final walletPointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      final unlockedBalance = wow_ffi.getWalletUnlockedBalance(
        Pointer.fromAddress(walletPointerAddress),
        accountIndex: accountIndex,
      );
      return BigInt.from(unlockedBalance);
    });
  }

  // @override
  // List<Account> getAccounts({bool includeSubaddresses = false}) {
  //   final accountsCount =
  //       wownero.Wallet_numSubaddressAccounts(_getWalletPointer());
  //   final accountsPointer =
  //       wownero.Wallet_subaddressAccount(_getWalletPointer());
  //   final accountsSize = wownero.AddressBook_getAll_size(accountsPointer);
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
  //       final subaddressCount = wownero.Wallet_numSubaddresses(
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
  //   wownero.Wallet_addSubaddressAccount(_getWalletPointer(),
  //       label: label ?? "");
  // }
  //
  // @override
  // void setAccountLabel(int accountIdx, String label) {
  //   throw UnimplementedError("TODO");
  // }
  //
  // @override
  // void setSubaddressLabel(int accountIdx, int addressIdx, String label) {
  //   wownero.Wallet_setSubaddressLabel(
  //     _getWalletPointer(),
  //     accountIndex: accountIdx,
  //     addressIndex: addressIdx,
  //     label: label,
  //   );
  // }

  @override
  Future<String> getTxKey(String txid) async {
    final address = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.getTxKey(Pointer.fromAddress(address), txid: txid);
    });
  }

  @override
  Future<Transaction> getTx(String txid, {bool refresh = false}) async {
    if (refresh) {
      await refreshTransactions();
    }

    return _transactionFrom(
      wow_ffi.getTransactionInfoPointerByTxid(
        _transactionHistoryPointer!,
        txid: txid,
      ),
    );
  }

  @override
  Future<List<Transaction>> getTxs({
    required Set<String> txids,
    bool refresh = false,
  }) async {
    if (refresh) {
      await refreshTransactions();
    }

    final List<Transaction> result = [];
    for (final txid in txids) {
      result.add(await getTx(txid, refresh: false));
    }
    return result;
  }

  @override
  Future<List<Transaction>> getAllTxs({bool refresh = false}) async {
    if (refresh) {
      await refreshTransactions();
    }

    final size = await transactionCount();

    final List<Transaction> result = [];
    for (int i = 0; i < size; i++) {
      result.add(
        await _transactionFrom(
          wow_ffi.getTransactionInfoPointer(
            _transactionHistoryPointer!,
            index: i,
          ),
        ),
      );
    }

    return result;
  }

  @override
  Future<List<String>> getAllTxids({bool refresh = false}) async {
    if (refresh) {
      await refreshTransactions();
    }

    final address = _transactionHistoryPointer!.address;
    final size = await transactionCount();

    return Isolate.run(() {
      final ptr = Pointer.fromAddress(address);

      return List.generate(
        size,
        (index) => wow_ffi.getTransactionInfoHash(
          wow_ffi.getTransactionInfoPointer(
            ptr.cast(),
            index: index,
          ),
        ),
      );
    });
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

      final address = _coinsPointer!.address;

      return Isolate.run(() {
        final List<Output> result = [];

        final ptr = Pointer.fromAddress(address);

        final count = wow_ffi.getCoinsCount(ptr.cast());
        for (int i = 0; i < count; i++) {
          final coinInfoPointer = wow_ffi.getCoinInfoPointer(ptr.cast(), i);

          final hash = wow_ffi.getHashForCoinsInfo(coinInfoPointer);

          if (hash.isNotEmpty) {
            final spent = wow_ffi.isSpentCoinsInfo(coinInfoPointer);

            if (includeSpent || !spent) {
              final utxo = Output(
                address: wow_ffi.getAddressForCoinsInfo(coinInfoPointer),
                hash: hash,
                keyImage: wow_ffi.getKeyImageForCoinsInfo(coinInfoPointer),
                value:
                    BigInt.from(wow_ffi.getAmountForCoinsInfo(coinInfoPointer)),
                isFrozen: wow_ffi.isFrozenCoinsInfo(coinInfoPointer),
                isUnlocked: wow_ffi.isUnlockedCoinsInfo(coinInfoPointer),
                vout:
                    wow_ffi.getInternalOutputIndexForCoinsInfo(coinInfoPointer),
                spent: spent,
                spentHeight: spent
                    ? wow_ffi.getSpentHeightForCoinsInfo(coinInfoPointer)
                    : null,
                height: wow_ffi.getBlockHeightForCoinsInfo(coinInfoPointer),
                coinbase: wow_ffi.isCoinbaseCoinsInfo(coinInfoPointer),
              );

              result.add(utxo);
            }
          }
        }

        return result;
      });
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
      return wow_ffi.exportWalletKeyImages(
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
      return wow_ffi.importWalletKeyImages(
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

    final address = _coinsPointer!.address;

    await Isolate.run(() {
      final ptr = Pointer.fromAddress(address);
      final count = wow_ffi.getAllCoinsSize(ptr.cast());
      for (int i = 0; i < count; i++) {
        if (keyImage ==
            wow_ffi.getKeyImageForCoinsInfo(
              wow_ffi.getCoinInfoPointer(ptr.cast(), i),
            )) {
          wow_ffi.freezeCoin(ptr.cast(), index: i);
          return;
        }
      }
    });

    throw Exception(
      "Can't freeze utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<void> thawOutput(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted thaw of empty keyImage.");
    }

    final address = _coinsPointer!.address;

    await Isolate.run(() {
      final ptr = Pointer.fromAddress(address);
      final count = wow_ffi.getAllCoinsSize(ptr.cast());
      for (int i = 0; i < count; i++) {
        if (keyImage ==
            wow_ffi.getKeyImageForCoinsInfo(
              wow_ffi.getCoinInfoPointer(ptr.cast(), i),
            )) {
          wow_ffi.thawCoin(ptr.cast(), index: i);
          return;
        }
      }
    });

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
          final tx = wow_ffi.createTransaction(
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

      wow_ffi.checkPendingTransactionStatus(pendingTxPointer);

      return PendingTransaction(
        amount:
            BigInt.from(wow_ffi.getPendingTransactionAmount(pendingTxPointer)),
        fee: BigInt.from(wow_ffi.getPendingTransactionFee(pendingTxPointer)),
        txid: wow_ffi.getPendingTransactionTxid(pendingTxPointer),
        hex: wow_ffi.getPendingTransactionHex(pendingTxPointer),
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
          final tx = wow_ffi.createTransactionMultiDest(
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

      wow_ffi.checkPendingTransactionStatus(pendingTxPointer);

      return PendingTransaction(
        amount:
            BigInt.from(wow_ffi.getPendingTransactionAmount(pendingTxPointer)),
        fee: BigInt.from(wow_ffi.getPendingTransactionFee(pendingTxPointer)),
        txid: wow_ffi.getPendingTransactionTxid(
          pendingTxPointer,
        ),
        hex: wow_ffi.getPendingTransactionHex(
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
      return wow_ffi.commitPendingTransaction(
        Pointer<Void>.fromAddress(
          tx.pointerAddress,
        ),
      );
    });

    wow_ffi.checkPendingTransactionStatus(
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
      return wow_ffi.signMessageWith(
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
      return wow_ffi.verifySignedMessageWithWallet(
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
  Future<BigInt?> amountFromString(String value) async {
    try {
      // not sure what protections or validation is done internally
      // so lets do some extra for now
      double.parse(value);

      // if that parse succeeded the following should produce a valid result

      return BigInt.from(
        await Isolate.run(() => wow_ffi.amountFromString(value)),
      );
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
  Future<String> getPassword() async {
    final address = _getWalletPointer().address;
    return await Isolate.run(() {
      return wow_ffi.getWalletPassword(Pointer.fromAddress(address));
    });
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final address = _getWalletPointer().address;
    await Isolate.run(() {
      return wow_ffi.setWalletPassword(
        Pointer.fromAddress(address),
        password: newPassword,
      );
    });
  }

  @override
  Future<void> save() async {
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wow_ffi.storeWallet(Pointer.fromAddress(pointerAddress), path: "");
    });
  }

  // TODO probably get rid of this. Not a good API/Design
  bool isClosing = false;
  @override
  Future<void> close({bool save = false}) async {
    if (isClosed() || isClosing) return;
    isClosing = true;
    await stopSyncing();
    stopListeners();

    if (save) {
      await this.save();
    }

    wow_wm_ffi.closeWallet(_walletManagerPointer, _getWalletPointer(), save);
    _walletPointer = null;
    isClosing = false;
  }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
