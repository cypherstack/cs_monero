import 'dart:async';
import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../cs_monero.dart';
import '../deprecated/get_height_by_date.dart';
import '../ffi_bindings/monero_wallet_manager_bindings.dart' as xmr_wm_ffi;
import '../isolated/worker.dart';

class MoneroWallet extends Wallet {
  // internal constructor
  MoneroWallet._(int pointer, this._worker) : _walletPointer = pointer;

  final Worker _worker;

  // shared pointer
  static final int _walletManagerPointerAddress =
      xmr_wm_ffi.getWalletManager().address;

  int? _walletPointer;
  int _getWalletPointer() {
    if (_walletPointer == null) {
      throw Exception(
        "MoneroWallet was closed!",
      );
    }
    return _walletPointer!;
  }

  StreamSubscription<dynamic>? _subscription;

  @override
  Future<void> startListeners() async {
    await stopListeners();

    await _worker.runTask<bool>(
      Task(
        func: FuncName.startPolling,
        args: {
          "wallet": _getWalletPointer(),
          "seconds": pollingInterval.inSeconds,
        },
      ),
    );

    _worker.eventStream.listen((data) {
      Logging.log?.t("Polling event: $data");

      if (data is Map) {
        final type = data["type"] as String;

        final listeners = getListeners();

        switch (type) {
          case "onBalancesChanged":
            final full = BigInt.from(data["full"] as int);
            final unlocked = BigInt.from(data["unlocked"] as int);
            for (final listener in listeners) {
              listener.onBalancesChanged
                  ?.call(newBalance: full, newUnlockedBalance: unlocked);
            }
            break;

          case "onNewBlock":
            final nodeHeight = data["nodeHeight"] as int;
            for (final listener in listeners) {
              listener.onNewBlock?.call(nodeHeight);
            }
            break;

          case "onSyncingUpdate":
            final nodeHeight = data["nodeHeight"] as int;
            final currentSyncingHeight = data["syncHeight"] as int;
            for (final listener in listeners) {
              listener.onSyncingUpdate?.call(
                syncHeight: currentSyncingHeight,
                nodeHeight: nodeHeight,
              );
            }
            break;

          default:
            throw Exception("Unknown event type: $type");
        }
      }
    });
  }

  @override
  Future<void> stopListeners() async {
    await _subscription?.cancel();
    await _worker.runTask<bool>(
      Task(
        func: FuncName.stopPolling,
        args: {
          "wallet": _getWalletPointer(),
          "seconds": pollingInterval.inSeconds,
        },
      ),
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
  /// - **networkType** (`Network`, required): Specifies the Monero network type.
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
  ///   networkType: Network.mainnet,
  /// );
  /// ```
  static Future<MoneroWallet> create({
    required String path,
    required String password,
    String language = "English",
    required MoneroSeedType seedType,
    required Network networkType,
    String seedOffset = "",
  }) async {
    final worker = await Worker.spawn();

    final int walletPointerAddress;
    switch (seedType) {
      case MoneroSeedType.sixteen:
        walletPointerAddress = await worker.runTask(
          Task(
            func: FuncName.createPolySeedWallet,
            args: {
              "wm": _walletManagerPointerAddress,
              "lang": language,
              "path": path,
              "pw": password,
              "offset": seedOffset,
              "net": networkType.value,
            },
          ),
        );
        break;

      case MoneroSeedType.twentyFive:
        walletPointerAddress = await worker.runTask(
          Task(
            func: FuncName.createWallet,
            args: {
              "wm": _walletManagerPointerAddress,
              "lang": language,
              "path": path,
              "pw": password,
              "net": networkType.value,
            },
          ),
        );

        break;
    }

    final wallet = MoneroWallet._(walletPointerAddress, worker);
    return wallet;
  }

  /// Restores a Monero wallet from a mnemonic seed phrase.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path where the wallet will be stored.
  /// - **password** (`String`, required): The password used to encrypt the wallet file.
  /// - **seed** (`String`, required): The mnemonic seed phrase for restoring the wallet.
  /// - **networkType** (`Network`, required): Specifies the Monero network type.
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
  ///   networkType: Network.mainnet,
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
    required Network networkType,
    int restoreHeight = 0,
    String seedOffset = "",
  }) async {
    final worker = await Worker.spawn();
    final int walletPointerAddress;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      walletPointerAddress = await worker.runTask(
        Task(
          func: FuncName.recoverWallet,
          args: {
            "wm": _walletManagerPointerAddress,
            "seed": seed,
            "path": path,
            "pw": password,
            "offset": seedOffset,
            "net": networkType.value,
            "height": restoreHeight,
          },
        ),
      );
    } else if (seedLength == 16) {
      walletPointerAddress = await worker.runTask(
        Task(
          func: FuncName.recoverWalletFromPolyseed,
          args: {
            "wm": _walletManagerPointerAddress,
            "seed": seed,
            "path": path,
            "pw": password,
            "offset": seedOffset,
            "net": networkType.value,
          },
        ),
      );
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    final wallet = MoneroWallet._(walletPointerAddress, worker);
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
  /// - **networkType** (`Network`, required): Specifies the Monero network type.
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
  ///   networkType: Network.mainnet,
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
    required Network networkType,
    int restoreHeight = 0,
  }) =>
      restoreWalletFromKeys(
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
  /// - **networkType** (`Network`, required): Specifies the Monero network type.
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
  ///   networkType: Network.mainnet,
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
    required Network networkType,
    int restoreHeight = 0,
  }) async {
    final worker = await Worker.spawn();
    final walletPointerAddress = await worker.runTask<int>(
      Task(
        func: FuncName.recoverWalletFromKeys,
        args: {
          "wm": _walletManagerPointerAddress,
          "path": path,
          "pw": password,
          "lang": language,
          "addr": address,
          "vk": viewKey,
          "sp": spendKey,
          "net": networkType.value,
          "height": restoreHeight,
        },
      ),
    );

    final wallet = MoneroWallet._(walletPointerAddress, worker);
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
  /// - **networkType** (`Network`, optional): Specifies the Monero network type.
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
  ///   networkType: Network.mainnet,
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
    required Network networkType,
    int restoreHeight = 0,
  }) async {
    final worker = await Worker.spawn();
    final walletPointerAddress = await worker.runTask<int>(
      Task(
        func: FuncName.restoreDeterministicWalletFromSpendKey,
        args: {
          "wm": _walletManagerPointerAddress,
          "path": path,
          "pw": password,
          "lang": language,
          "sp": spendKey,
          "net": networkType.value,
          "height": restoreHeight,
        },
      ),
    );

    final wallet = MoneroWallet._(walletPointerAddress, worker);
    return wallet;
  }

  /// Loads an existing Monero wallet from the specified path with the provided password.
  ///
  /// ### Parameters:
  /// - **path** (`String`, required): The file path to the existing wallet file to be loaded.
  /// - **password** (`String`, required): The password used to decrypt the wallet file.
  /// - **networkType** (`Network`, required): Specifies the Monero network type.
  ///
  /// ### Returns:
  /// An instance of [MoneroWallet] representing the loaded wallet.
  ///
  /// ### Example:
  /// ```dart
  /// final wallet = MoneroWallet.loadWallet(
  ///   path: '/path/to/existing_wallet',
  ///   password: 'secure_password',
  ///   networkType: Network.mainnet,
  /// );
  /// ```
  ///
  /// ### Errors:
  /// Throws an error if the wallet file cannot be found, the password is incorrect,
  /// or the file cannot be read due to other I/O issues.
  static Future<MoneroWallet> loadWallet({
    required String path,
    required String password,
    required Network networkType,
  }) async {
    final worker = await Worker.spawn();
    final walletPointerAddress = await worker.runTask<int>(
      Task(
        func: FuncName.loadWallet,
        args: {
          "wm": _walletManagerPointerAddress,
          "path": path,
          "pw": password,
          "net": networkType.value,
        },
      ),
    );

    final wallet = MoneroWallet._(walletPointerAddress, worker);
    return wallet;
  }

  // ===========================================================================
  // special check to see if wallet exists
  static bool isWalletExist(String path) => xmr_wm_ffi.walletExists(
        Pointer<Void>.fromAddress(_walletManagerPointerAddress),
        path,
      );

  // ===========================================================================
  // === Internal overrides ====================================================

  @override
  @protected
  Future<void> refreshOutputs() => _worker.runTask(
        Task(
          func: FuncName.refreshCoins,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  @protected
  Future<void> refreshTransactions() => _worker.runTask(
        Task(
          func: FuncName.refreshTransactions,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  @protected
  Future<int> transactionCount() => _worker.runTask(
        Task(
          func: FuncName.transactionCount,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  // ===========================================================================
  // === Overrides =============================================================

  @override
  Future<int> getCurrentWalletSyncingHeight() => _worker.runTask(
        Task(
          func: FuncName.getWalletBlockChainHeight,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getMoneroHeightByDate(date: date);
  }

  @override
  Future<bool> connect({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  }) {
    Logging.log?.i("init (initConnection()) node address: $daemonAddress");

    return _worker.runTask(
      Task(
        func: FuncName.initWallet,
        args: {
          "wp": _getWalletPointer(),
          "addr": daemonAddress,
          "u": daemonUsername ?? "",
          "p": daemonPassword ?? "",
          "sock": socksProxyAddress ?? "",
          "ssl": useSSL,
          "lite": isLightWallet,
          "trust": trusted,
        },
      ),
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
  Future<bool> isViewOnly() => _worker.runTask(
        Task(
          func: FuncName.isViewOnly,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  // @override
  // void setProxyUri(String proxyUri) {
  //   monero.Wallet_setProxy(_getWalletPointer(), address: proxyUri);
  // }

  @override
  Future<bool> isConnectedToDaemon() async {
    final result = await _worker.runTask<int>(
      Task(
        func: FuncName.isConnectedToDaemon,
        args: {
          "wp": _getWalletPointer(),
        },
      ),
    );
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
      return await _worker.runTask(
        Task(
          func: FuncName.isSynchronized,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );
    }

    return false;
  }

  @override
  Future<String> getPath() => _worker.runTask(
        Task(
          func: FuncName.getWalletPath,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<String> getSeed({String seedOffset = ""}) => _worker.runTask(
        Task(
          func: FuncName.getSeed,
          args: {
            "wp": _getWalletPointer(),
            "offset": seedOffset,
          },
        ),
      );

  @override
  Future<String> getSeedLanguage() => _worker.runTask(
        Task(
          func: FuncName.getSeedLanguage,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<String> getPrivateSpendKey() => _worker.runTask(
        Task(
          func: FuncName.getPrivateSpendKey,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<String> getPrivateViewKey() => _worker.runTask(
        Task(
          func: FuncName.getPrivateViewKey,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<String> getPublicSpendKey() => _worker.runTask(
        Task(
          func: FuncName.getPublicSpendKey,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<String> getPublicViewKey() => _worker.runTask(
        Task(
          func: FuncName.getPublicViewKey,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<Address> getAddress({
    int accountIndex = 0,
    int addressIndex = 0,
  }) async {
    final address = Address(
      value: await _worker.runTask(
        Task(
          func: FuncName.getAddress,
          args: {
            "wp": _getWalletPointer(),
            "idx": addressIndex,
            "acc": accountIndex,
          },
        ),
      ),
      account: accountIndex,
      index: addressIndex,
    );

    return address;
  }

  @override
  Future<int> getDaemonHeight() => _worker.runTask(
        Task(
          func: FuncName.getDaemonBlockChainHeight,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<int> getRefreshFromBlockHeight() => _worker.runTask(
        Task(
          func: FuncName.getWalletRefreshFromBlockHeight,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<void> setRefreshFromBlockHeight(int startHeight) => _worker.runTask(
        Task(
          func: FuncName.setWalletRefreshFromBlockHeight,
          args: {
            "wp": _getWalletPointer(),
            "height": startHeight,
          },
        ),
      );

  @override
  Future<void> startSyncing({Duration interval = const Duration(seconds: 10)}) {
    // 10 seconds seems to be the default in monero core
    return _worker.runTask(
      Task(
        func: FuncName.startSyncing,
        args: {
          "wp": _getWalletPointer(),
          "millis": interval.inMilliseconds,
        },
      ),
    );
  }

  @override
  Future<void> stopSyncing() => _worker.runTask(
        Task(
          func: FuncName.stopSyncing,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  // /// returns true on success
  // @override
  // Future<bool> rescanSpent() async {
  //   final address = _getWalletPointer().address;
  //   final result = await Isolate.run(() {
  //     return monero.Wallet_rescanSpent(Pointer.fromAddress(address));
  //   });
  //   return result;
  // }

  @override
  Future<void> rescanBlockchain() => _worker.runTask(
        Task(
          func: FuncName.rescanBlockchainAsync,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<BigInt> getBalance({int accountIndex = 0}) async => BigInt.from(
        await _worker.runTask(
          Task(
            func: FuncName.getBalance,
            args: {
              "wp": _getWalletPointer(),
              "acc": accountIndex,
            },
          ),
        ),
      );

  @override
  Future<BigInt> getUnlockedBalance({int accountIndex = 0}) async =>
      BigInt.from(
        await _worker.runTask(
          Task(
            func: FuncName.getUnlockedBalance,
            args: {
              "wp": _getWalletPointer(),
              "acc": accountIndex,
            },
          ),
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
  Future<String> getTxKey(String txid) => _worker.runTask(
        Task(
          func: FuncName.getTxKey,
          args: {
            "wp": _getWalletPointer(),
            "txid": txid,
          },
        ),
      );

  @override
  Future<Transaction> getTx(String txid, {bool refresh = false}) async {
    return Transaction.fromRawMap(
      await _worker.runTask(
        Task(
          func: FuncName.getTx,
          args: {
            "wp": _getWalletPointer(),
            "txid": txid,
            "refresh": refresh,
          },
        ),
      ),
    );
  }

  @override
  Future<List<Transaction>> getTxs({
    required Set<String> txids,
    bool refresh = false,
  }) async {
    final List<Map<String, dynamic>> txs = await _worker.runTask(
      Task(
        func: FuncName.getTxs,
        args: {
          "wp": _getWalletPointer(),
          "refresh": refresh,
          "txids": txids.toList(),
        },
      ),
    );

    return txs.map(Transaction.fromRawMap).toList();
  }

  @override
  Future<List<Transaction>> getAllTxs({bool refresh = false}) async {
    final List<Map<String, dynamic>> all = await _worker.runTask(
      Task(
        func: FuncName.getAllTxs,
        args: {
          "wp": _getWalletPointer(),
          "refresh": refresh,
        },
      ),
    );

    return all.map(Transaction.fromRawMap).toList();
  }

  @override
  Future<List<String>> getAllTxids({bool refresh = false}) => _worker.runTask(
        Task(
          func: FuncName.getAllTxids,
          args: {
            "wp": _getWalletPointer(),
            "refresh": refresh,
          },
        ),
      );

  @override
  Future<List<Output>> getOutputs({
    bool includeSpent = false,
    bool refresh = false,
  }) async {
    try {
      final List<Map<String, dynamic>> all = await _worker.runTask(
        Task(
          func: FuncName.getOutputs,
          args: {
            "wp": _getWalletPointer(),
            "refresh": refresh,
            "includeSpent": includeSpent,
          },
        ),
      );

      return all.map(Output.fromRawMap).toList();
    } catch (e, s) {
      Logging.log?.w("getOutputs failed", error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> exportKeyImages({
    required String filename,
    bool all = false,
  }) =>
      _worker.runTask(
        Task(
          func: FuncName.exportKeyImages,
          args: {
            "wp": _getWalletPointer(),
            "all": all,
            "fname": filename,
          },
        ),
      );

  @override
  Future<bool> importKeyImages({required String filename}) => _worker.runTask(
        Task(
          func: FuncName.importKeyImages,
          args: {
            "wp": _getWalletPointer(),
            "fname": filename,
          },
        ),
      );

  @override
  Future<void> freezeOutput(String keyImage) => _worker.runTask(
        Task(
          func: FuncName.freezeOutput,
          args: {
            "wp": _getWalletPointer(),
            "ki": keyImage,
          },
        ),
      );

  @override
  Future<void> thawOutput(String keyImage) => _worker.runTask(
        Task(
          func: FuncName.thawOutput,
          args: {
            "wp": _getWalletPointer(),
            "ki": keyImage,
          },
        ),
      );

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
      final pending = await _worker.runTask<Map<String, dynamic>>(
        Task(
          func: FuncName.createTransaction,
          args: {
            "wp": _getWalletPointer(),
            "addr": output.address,
            "amt": output.amount.toInt(),
            "acc": accountIndex,
            "prio": priority.value,
            "pid": paymentId,
            "sweep": sweep,
            "kis": inputsToUse.map((e) => e.keyImage).toList(),
          },
        ),
      );

      return PendingTransaction(
        amount: BigInt.from(pending["amount"] as int),
        fee: BigInt.from(pending["fee"] as int),
        txid: pending["txid"] as String,
        hex: pending["hex"] as String,
        pointerAddress: pending["pointerAddress"] as int,
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
      final pending = await _worker.runTask<Map<String, dynamic>>(
        Task(
          func: FuncName.createTransactionMultiDest,
          args: {
            "wp": _getWalletPointer(),
            "addrs": outputs.map((e) => e.address).toList(),
            "amts": outputs.map((e) => e.amount.toInt()).toList(),
            "acc": accountIndex,
            "prio": priority.value,
            "pid": paymentId,
            "sweep": sweep,
            "kis": inputsToUse.map((e) => e.keyImage).toList(),
          },
        ),
      );

      return PendingTransaction(
        amount: BigInt.from(pending["amount"] as int),
        fee: BigInt.from(pending["fee"] as int),
        txid: pending["txid"] as String,
        hex: pending["hex"] as String,
        pointerAddress: pending["pointerAddress"] as int,
      );
    } finally {
      if (processedInputs != null) {
        await postProcessInputs(keyImages: processedInputs);
      }
    }
  }

  @override
  Future<bool> commitTx(PendingTransaction tx) => _worker.runTask(
        Task(
          func: FuncName.commitTx,
          args: {
            "ptr": tx.pointerAddress,
          },
        ),
      );

  @override
  Future<String> signMessage(
    String message,
    String address,
  ) =>
      _worker.runTask(
        Task(
          func: FuncName.signMessage,
          args: {
            "wp": _getWalletPointer(),
            "msg": message,
            "addr": address,
          },
        ),
      );

  @override
  Future<bool> verifyMessage(
    String message,
    String address,
    String signature,
  ) =>
      _worker.runTask(
        Task(
          func: FuncName.verifyMessage,
          args: {
            "wp": _getWalletPointer(),
            "msg": message,
            "addr": address,
            "sig": signature,
          },
        ),
      );

  // @override
  // String getPaymentUri(TxConfig request) {
  //   throw UnimplementedError("TODO");
  // }

  @override
  Future<bool> validateAddress(
    String address, {
    required Network networkType,
  }) =>
      _worker.runTask(
        Task(
          func: FuncName.validateAddress,
          args: {
            "addr": address,
            "net": networkType.value,
          },
        ),
      );

  @override
  Future<BigInt?> amountFromString(String value) async {
    try {
      // not sure what protections or validation is done internally
      // so lets do some extra for now
      double.parse(value);

      // if that parse succeeded the following should produce a valid result

      return BigInt.from(
        await _worker.runTask(
          Task(
            func: FuncName.amountFromString,
            args: {
              "amt": value,
            },
          ),
        ),
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
  Future<String> getPassword() => _worker.runTask(
        Task(
          func: FuncName.getPassword,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  @override
  Future<bool> changePassword(String newPassword) => _worker.runTask(
        Task(
          func: FuncName.changePassword,
          args: {
            "wp": _getWalletPointer(),
            "pw": newPassword,
          },
        ),
      );

  @override
  Future<void> save() => _worker.runTask(
        Task(
          func: FuncName.save,
          args: {
            "wp": _getWalletPointer(),
          },
        ),
      );

  // TODO probably get rid of this. Not a good API/Design
  bool isClosing = false;
  @override
  Future<void> close({bool save = false}) async {
    if (isClosed() || isClosing) return;
    isClosing = true;
    await stopSyncing();
    await stopListeners();

    await _worker.runTask<void>(
      Task(
        func: FuncName.close,
        args: {
          "wm": _walletManagerPointerAddress,
          "wp": _getWalletPointer(),
          "save": save,
        },
      ),
    );
    _walletPointer = null;
    isClosing = false;
  }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
