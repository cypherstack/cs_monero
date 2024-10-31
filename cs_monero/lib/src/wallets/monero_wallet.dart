import 'dart:ffi';
import 'dart:isolate';

import 'package:compat/old_cw_core/get_height_by_date.dart';
import 'package:meta/meta.dart';

import '../../cs_monero.dart';
import '../enums/min_confirms.dart';
import '../ffi_bindings/monero_wallet_bindings.dart' as xmr_ffi;
import '../ffi_bindings/monero_wallet_manager_bindings.dart' as xmr_wm_ffi;

class MoneroWallet extends Wallet {
  // internal constructor
  MoneroWallet._(Pointer<Void> pointer, String path)
      : _walletPointer = pointer,
        _path = path;
  final String _path;

  // shared pointer
  static Pointer<Void>? _walletManagerPointerCached;
  static final Pointer<Void> _walletManagerPointer = Pointer.fromAddress((() {
    try {
      // monero.printStarts = true;
      _walletManagerPointerCached ??= xmr_wm_ffi.getWalletManager();
      Logging.log?.i("ptr: $_walletManagerPointerCached");
    } catch (e, s) {
      Logging.log?.e("Failed to initialize wm ptr", error: e, stackTrace: s);
    }
    return _walletManagerPointerCached!.address;
  })());

  // internal map of wallets
  static final Map<String, MoneroWallet> _openedWalletsByPath = {};

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

  static Future<MoneroWallet> create({
    required String path,
    required String password,
    String language = "English",
    required MoneroSeedType seedType,
    int networkType = 0,
  }) async {
    final Pointer<Void> walletPointer;
    switch (seedType) {
      case MoneroSeedType.sixteen:
        final seed = xmr_ffi.createPolyseed(language: language);
        walletPointer = xmr_wm_ffi.createWalletFromPolyseed(
          _walletManagerPointer,
          path: path,
          password: password,
          mnemonic: seed,
          seedOffset: "",
          newWallet: true,
          restoreHeight: 0, // ignored by core underlying code
          kdfRounds: 1,
        );
        break;

      case MoneroSeedType.twentyFive:
        walletPointer = xmr_wm_ffi.createWallet(
          _walletManagerPointer,
          path: path,
          password: password,
          language: language,
          networkType: networkType,
        );
        break;
    }

    xmr_ffi.checkWalletStatus(walletPointer);

    final address = walletPointer.address;
    await Isolate.run(() {
      xmr_ffi.storeWallet(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  /// 16 word polyseed restores will ignore the [restoreHeight] param.
  static Future<MoneroWallet> restoreWalletFromSeed({
    required String path,
    required String password,
    required String seed,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final Pointer<Void> walletPointer;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      walletPointer = xmr_wm_ffi.recoveryWallet(
        _walletManagerPointer,
        path: path,
        password: password,
        mnemonic: seed,
        restoreHeight: restoreHeight,
        seedOffset: "",
        networkType: networkType,
      );
    } else if (seedLength == 16) {
      walletPointer = xmr_wm_ffi.createWalletFromPolyseed(
        _walletManagerPointer,
        path: path,
        password: password,
        mnemonic: seed,
        seedOffset: "",
        newWallet: false,
        restoreHeight: 0, // ignored by core underlying code
        kdfRounds: 1,
        networkType: networkType,
      );
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    xmr_ffi.checkWalletStatus(walletPointer);

    final address = walletPointer.address;
    await Isolate.run(() {
      xmr_ffi.storeWallet(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet createViewOnlyWallet({
    required String path,
    required String password,
    required String address,
    required String viewKey,
    int networkType = 0,
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

  static MoneroWallet restoreWalletFromKeys({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) {
    final walletPointer = xmr_wm_ffi.createWalletFromKeys(
      _walletManagerPointer,
      path: path,
      password: password,
      language: language,
      addressString: address,
      viewKeyString: viewKey,
      spendKeyString: spendKey,
      networkType: networkType,
      restoreHeight: restoreHeight,
    );

    xmr_ffi.checkWalletStatus(walletPointer);

    final wallet = MoneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet restoreDeterministicWalletFromSpendKey({
    required String path,
    required String password,
    required String language,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) {
    final walletPointer = xmr_wm_ffi.createDeterministicWalletFromSpendKey(
      _walletManagerPointer,
      path: path,
      password: password,
      language: language,
      spendKeyString: spendKey,
      newWallet: true, // TODO(mrcyjanek): safe to remove
      restoreHeight: restoreHeight,
    );

    xmr_ffi.checkWalletStatus(walletPointer);

    // TODO check if we should grab seed and cache it here?
    // monero.Wallet_setCacheAttribute(walletPointer, key: "cakewallet.seed", value: seed);

    final wallet = MoneroWallet._(walletPointer, path);
    wallet.save();
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet loadWallet({
    required String path,
    required String password,
    int networkType = 0,
  }) {
    MoneroWallet? wallet = _openedWalletsByPath[path];
    if (wallet != null) {
      return wallet;
    }

    try {
      final walletPointer = xmr_wm_ffi.openWallet(
        _walletManagerPointer,
        path: path,
        password: password,
      );
      wallet = MoneroWallet._(walletPointer, path);
      _openedWalletsByPath[path] = wallet;
    } catch (e, s) {
      Logging.log?.e("", error: e, stackTrace: s);
      rethrow;
    }

    xmr_ffi.checkWalletStatus(wallet._getWalletPointer());
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

  @override
  @protected
  int syncHeight() => xmr_ffi.getWalletBlockChainHeight(_getWalletPointer());

  // ===========================================================================
  // === Overrides =============================================================

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getMoneroHeigthByDate(date: date);
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
    final current = syncHeight();
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
              xmr_ffi.getCoinInfoPointer(_coinsPointer!, i))) {
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
              xmr_ffi.getCoinInfoPointer(_coinsPointer!, i))) {
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
          tx.pointerAddress!,
        ),
      );
    });

    xmr_ffi.checkPendingTransactionStatus(
      Pointer<Void>.fromAddress(
        tx.pointerAddress!,
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
    _openedWalletsByPath.remove(_path);
    isClosing = false;
  }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
