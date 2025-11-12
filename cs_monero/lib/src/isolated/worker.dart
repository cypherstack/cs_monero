import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:uuid/uuid.dart';

import '../ffi_bindings/monero_wallet_bindings.dart' as xmr_ffi;
import '../ffi_bindings/monero_wallet_manager_bindings.dart' as xmr_wm_ffi;
import '../logging.dart';

enum FuncName {
  createPolySeedWallet,
  createWallet,
  recoverWalletFromPolyseed,
  recoverWallet,
  recoverWalletFromKeys,
  restoreDeterministicWalletFromSpendKey,
  loadWallet,
  refreshCoins,
  refreshTransactions,
  transactionCount,
  getWalletBlockChainHeight,
  initWallet,
  isViewOnly,
  isConnectedToDaemon,
  isSynchronized,
  getWalletPath,
  getSeed,
  getSeedLanguage,
  getPrivateSpendKey,
  getPrivateViewKey,
  getPublicSpendKey,
  getPublicViewKey,
  getAddress,
  getDaemonBlockChainHeight,
  getWalletRefreshFromBlockHeight,
  setWalletRefreshFromBlockHeight,
  startSyncing,
  stopSyncing,
  rescanBlockchainAsync,
  getBalance,
  getUnlockedBalance,
  getTxKey,
  getTx,
  getTxs,
  getAllTxs,
  getAllTxids,
  getOutputs,
  exportKeyImages,
  importKeyImages,
  freezeOutput,
  thawOutput,
  createTransaction,
  createTransactionMultiDest,
  commitTx,
  signMessage,
  verifyMessage,
  validateAddress,
  amountFromString,
  getPassword,
  changePassword,
  save,
  close,
  startPolling,
  stopPolling,
}

class Task {
  final String id = const Uuid().v4();
  final FuncName func;
  final Map<String, dynamic> args;

  Task({required this.func, this.args = const {}});
}

class Result<T> {
  final bool success;
  final T? value;
  final Object? error;

  Result({required this.success, this.value, this.error});
}

class Worker {
  final SendPort _commands;
  final ReceivePort _responses;
  final ReceivePort _events;
  final Map<String, Completer<dynamic>> _activeRequests = {};
  final StreamController<dynamic> _eventStream = StreamController.broadcast();
  Stream<dynamic> get eventStream => _eventStream.stream;

  Worker._(this._responses, this._commands, this._events) {
    _responses.listen(_handleResponsesFromIsolate);
    _events.listen((event) => _eventStream.add(event));
  }

  static Future<Worker> spawn() async {
    final initPort = ReceivePort();
    await Isolate.spawn(_startWorkerIsolate, initPort.sendPort);

    final commandPort = await initPort.first as SendPort;

    final receivePort = ReceivePort();
    final eventPort = ReceivePort();
    commandPort.send((receivePort.sendPort, eventPort.sendPort));

    return Worker._(receivePort, commandPort, eventPort);
  }

  Future<T> runTask<T>(Task task) async {
    final completer = Completer<T>.sync();
    _activeRequests[task.id] = completer;
    _commands.send(task);

    return await completer.future;
  }

  void _handleResponsesFromIsolate(dynamic message) {
    final (String id, dynamic value, Object? error) =
        message as (String, dynamic, Object?);
    final completer = _activeRequests.remove(id);
    if (completer == null) return;

    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete(value);
    }
  }

  static void _startWorkerIsolate(SendPort mainSendPort) {
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    late SendPort resultPort;
    late SendPort eventPort;

    Timer? pollingTimer;
    int? lastDaemonHeight;
    int? lastSyncHeight;
    int? lastBalanceUnlocked;
    int? lastBalanceFull;

    void startPolling(int wallet, int seconds) {
      pollingTimer?.cancel();

      final walletPointer = Pointer<Void>.fromAddress(wallet);

      pollingTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
        final full = xmr_ffi.getWalletBalance(
          walletPointer,
          accountIndex: 0, // TODO
        );
        final unlocked = xmr_ffi.getWalletUnlockedBalance(
          walletPointer,
          accountIndex: 0, // TODO
        );

        if (unlocked != lastBalanceUnlocked || full != lastBalanceFull) {
          eventPort.send({
            "type": "onBalancesChanged",
            "full": full,
            "unlocked": unlocked,
          });
        }
        lastBalanceFull = full;
        lastBalanceUnlocked = unlocked;

        final nodeHeight = xmr_ffi.getDaemonBlockChainHeight(walletPointer);
        final heightChanged = nodeHeight != lastDaemonHeight;
        if (heightChanged) {
          eventPort.send({
            "type": "onNewBlock",
            "nodeHeight": nodeHeight,
          });
        }
        lastDaemonHeight = nodeHeight;

        final currentSyncingHeight =
            xmr_ffi.getWalletBlockChainHeight(walletPointer);

        if (currentSyncingHeight >= 0 &&
            currentSyncingHeight <= nodeHeight &&
            (heightChanged || currentSyncingHeight != lastSyncHeight)) {
          eventPort.send({
            "type": "onSyncingUpdate",
            "syncHeight": currentSyncingHeight,
            "nodeHeight": nodeHeight,
          });
        }
        lastSyncHeight = currentSyncingHeight;
      });
    }

    // Stop polling
    void stopPolling() {
      pollingTimer?.cancel();
      pollingTimer = null;
    }

    commandPort.listen((message) async {
      if (message is (SendPort, SendPort)) {
        (resultPort, eventPort) = message;
        return;
      }

      if (message is Task) {
        try {
          final dynamic result;

          switch (message.func) {
            case FuncName.startPolling:
              startPolling(
                message.args["wallet"] as int,
                message.args["seconds"] as int,
              );
              result = true;
              break;
            case FuncName.stopPolling:
              stopPolling();
              result = true;
              break;

            default:
              result = _executeTask(message);
          }

          resultPort.send((message.id, result, null));
        } catch (e) {
          resultPort.send((message.id, null, e));
        }
      }
    });
  }

  void dispose() {
    _eventStream.close();
    _responses.close();
    _events.close();
  }

  static dynamic _executeTask(Task task) {
    final args = task.args;
    return switch (task.func) {
      FuncName.createPolySeedWallet => _createPolySeedWallet(args),
      FuncName.createWallet => _createWallet(args),
      FuncName.recoverWalletFromPolyseed => _recoverWalletFromPolyseed(args),
      FuncName.recoverWallet => _recoverWallet(args),
      FuncName.recoverWalletFromKeys => _restoreWalletFromKeys(args),
      FuncName.restoreDeterministicWalletFromSpendKey =>
        _restoreDeterministicWalletFromSpendKey(args),
      FuncName.loadWallet => _openWallet(args),
      FuncName.refreshCoins => _refreshCoins(args),
      FuncName.refreshTransactions => _refreshTransactions(args),
      FuncName.transactionCount => _transactionCount(args),
      FuncName.getWalletBlockChainHeight => _getWalletBlockChainHeight(args),
      FuncName.initWallet => _initWallet(args),
      FuncName.isViewOnly => _isViewOnly(args),
      FuncName.isConnectedToDaemon => _isConnectedToDaemon(args),
      FuncName.isSynchronized => _isSynchronized(args),
      FuncName.getWalletPath => _getWalletPath(args),
      FuncName.getSeed => _getSeed(args),
      FuncName.getSeedLanguage => _getSeedLanguage(args),
      FuncName.getPrivateSpendKey => _getPrivateSpendKey(args),
      FuncName.getPrivateViewKey => _getPrivateViewKey(args),
      FuncName.getPublicSpendKey => _getPublicSpendKey(args),
      FuncName.getPublicViewKey => _getPublicViewKey(args),
      FuncName.getAddress => _getAddress(args),
      FuncName.getDaemonBlockChainHeight => _getDaemonBlockChainHeight(args),
      FuncName.getWalletRefreshFromBlockHeight =>
        _getWalletRefreshFromBlockHeight(args),
      FuncName.setWalletRefreshFromBlockHeight =>
        _setRefreshFromBlockHeight(args),
      FuncName.startSyncing => _startSyncing(args),
      FuncName.stopSyncing => _stopSyncing(args),
      FuncName.rescanBlockchainAsync => _rescanWalletBlockchainAsync(args),
      FuncName.getBalance => _getBalance(args),
      FuncName.getUnlockedBalance => _getUnlockedBalance(args),
      FuncName.getTxKey => _getTxKey(args),
      FuncName.getTx => _getTx(args),
      FuncName.getTxs => _getTxs(args),
      FuncName.getAllTxs => _getAllTxs(args),
      FuncName.getAllTxids => _getAllTxids(args),
      FuncName.getOutputs => _getOutputs(args),
      FuncName.exportKeyImages => _exportKeyImages(args),
      FuncName.importKeyImages => _importKeyImages(args),
      FuncName.freezeOutput => _freezeOutput(args),
      FuncName.thawOutput => _thawOutput(args),
      FuncName.createTransaction => _createTransaction(args),
      FuncName.createTransactionMultiDest => _createTransactionMultiDest(args),
      FuncName.commitTx => _commitTx(args),
      FuncName.signMessage => _signMessage(args),
      FuncName.verifyMessage => _verifyMessage(args),
      FuncName.validateAddress => _validateAddress(args),
      FuncName.amountFromString => _amountFromString(args),
      FuncName.getPassword => _getPassword(args),
      FuncName.changePassword => _changePassword(args),
      FuncName.save => _save(args),
      FuncName.close => _close(args),
      FuncName.startPolling =>
        throw ArgumentError("Start polling should not be run here"),
      FuncName.stopPolling =>
        throw ArgumentError("Stop polling should not be run here"),
    };
  }
}

int _createPolySeedWallet(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final language = args["lang"] as String;
  final path = args["path"] as String;
  final password = args["pw"] as String;
  final seedOffset = args["offset"] as String;
  final networkType = args["net"] as int;

  final seed = xmr_ffi.createPolyseed(language: language);
  final walletPointer = xmr_wm_ffi.createWalletFromPolyseed(
    wmPointer,
    path: path,
    password: password,
    mnemonic: seed,
    seedOffset: seedOffset,
    newWallet: true,
    networkType: networkType,
    restoreHeight: 0, // ignored by core underlying code
    kdfRounds: 1,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _createWallet(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final language = args["lang"] as String;
  final path = args["path"] as String;
  final password = args["pw"] as String;
  final networkType = args["net"] as int;

  final walletPointer = xmr_wm_ffi.createWallet(
    wmPointer,
    path: path,
    password: password,
    networkType: networkType,
    language: language,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _recoverWallet(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final path = args["path"] as String;
  final password = args["pw"] as String;
  final networkType = args["net"] as int;
  final restoreHeight = args["height"] as int;
  final seed = args["seed"] as String;
  final seedOffset = args["offset"] as String;

  final walletPointer = xmr_wm_ffi.recoveryWallet(
    wmPointer,
    path: path,
    password: password,
    networkType: networkType,
    seedOffset: seedOffset,
    mnemonic: seed,
    restoreHeight: restoreHeight,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _recoverWalletFromPolyseed(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final path = args["path"] as String;
  final seed = args["seed"] as String;
  final password = args["pw"] as String;
  final seedOffset = args["offset"] as String;
  final networkType = args["net"] as int;

  final walletPointer = xmr_wm_ffi.createWalletFromPolyseed(
    wmPointer,
    path: path,
    password: password,
    mnemonic: seed,
    seedOffset: seedOffset,
    newWallet: false,
    networkType: networkType,
    restoreHeight: 0, // ignored by core underlying code
    kdfRounds: 1,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _restoreWalletFromKeys(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final path = args["path"] as String;
  final language = args["lang"] as String;
  final viewKey = args["vk"] as String;
  final password = args["pw"] as String;
  final spendKey = args["sp"] as String;
  final address = args["addr"] as String;
  final networkType = args["net"] as int;
  final restoreHeight = args["height"] as int;

  final walletPointer = xmr_wm_ffi.createWalletFromKeys(
    wmPointer,
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

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _restoreDeterministicWalletFromSpendKey(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final path = args["path"] as String;
  final language = args["lang"] as String;
  final password = args["pw"] as String;
  final spendKey = args["sp"] as String;
  final networkType = args["net"] as int;
  final restoreHeight = args["height"] as int;

  final walletPointer = xmr_wm_ffi.createDeterministicWalletFromSpendKey(
    wmPointer,
    path: path,
    password: password,
    language: language,
    newWallet: true,
    spendKeyString: spendKey,
    networkType: networkType,
    restoreHeight: restoreHeight,
    kdfRounds: 1,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

int _openWallet(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final path = args["path"] as String;
  final password = args["pw"] as String;
  final networkType = args["net"] as int;

  final walletPointer = xmr_wm_ffi.openWallet(
    wmPointer,
    path: path,
    password: password,
    networkType: networkType,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  xmr_ffi.storeWallet(walletPointer, path: path);

  return walletPointer.address;
}

void _refreshCoins(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final coinsPointer = xmr_ffi.getCoinsPointer(walletPointer);
  xmr_ffi.refreshCoins(coinsPointer);
}

void _refreshTransactions(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final txHistoryPtr = xmr_ffi.getTransactionHistoryPointer(walletPointer);
  xmr_ffi.refreshTransactionHistory(txHistoryPtr);
}

int _transactionCount(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final txHistoryPtr = xmr_ffi.getTransactionHistoryPointer(walletPointer);
  return xmr_ffi.getTransactionHistoryCount(txHistoryPtr);
}

int _getWalletBlockChainHeight(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletBlockChainHeight(walletPointer);
}

bool _initWallet(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final daemonAddress = args["addr"] as String;
  final daemonUsername = args["u"] as String;
  final daemonPassword = args["p"] as String;
  final socksProxyAddress = args["sock"] as String;
  final useSSL = args["ssl"] as bool;
  final isLightWallet = args["lite"] as bool;
  final trusted = args["trust"] as bool;

  final init = xmr_ffi.initWallet(
    walletPointer,
    daemonAddress: daemonAddress,
    daemonUsername: daemonUsername,
    daemonPassword: daemonPassword,
    proxyAddress: socksProxyAddress,
    useSsl: useSSL,
    lightWallet: isLightWallet,
  );

  xmr_ffi.checkWalletStatus(walletPointer);

  if (init) {
    xmr_ffi.setTrustedDaemon(walletPointer, arg: trusted);
  }

  return init;
}

bool _isViewOnly(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.isWatchOnly(walletPointer);
}

int _isConnectedToDaemon(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.isConnected(walletPointer);
}

bool _isSynchronized(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.isSynchronized(walletPointer);
}

String _getWalletPath(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletPath(walletPointer);
}

String _getSeed(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final seedOffset = args["offset"] as String;
  final polySeed = xmr_ffi.getWalletPolyseed(
    walletPointer,
    passphrase: seedOffset,
  );
  if (polySeed != "") {
    return polySeed;
  }
  final legacy = xmr_ffi.getWalletSeed(
    walletPointer,
    seedOffset: seedOffset,
  );
  return legacy;
}

String _getSeedLanguage(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletSeedLanguage(walletPointer);
}

String _getPrivateSpendKey(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletSecretSpendKey(walletPointer);
}

String _getPrivateViewKey(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletSecretViewKey(walletPointer);
}

String _getPublicSpendKey(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletPublicSpendKey(walletPointer);
}

String _getPublicViewKey(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletPublicViewKey(walletPointer);
}

String _getAddress(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final addressIndex = args["idx"] as int;
  final accountIndex = args["acc"] as int;
  return xmr_ffi.getWalletAddress(
    walletPointer,
    accountIndex: accountIndex,
    addressIndex: addressIndex,
  );
}

int _getDaemonBlockChainHeight(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getDaemonBlockChainHeight(walletPointer);
}

int _getWalletRefreshFromBlockHeight(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.getWalletRefreshFromBlockHeight(walletPointer);
}

void _setRefreshFromBlockHeight(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final refreshFromBlockHeight = args["height"] as int;
  xmr_ffi.setWalletRefreshFromBlockHeight(
    walletPointer,
    refreshFromBlockHeight: refreshFromBlockHeight,
  );
}

void _startSyncing(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final millis = args["millis"] as int;
  xmr_ffi.setWalletAutoRefreshInterval(walletPointer, millis: millis);
  xmr_ffi.refreshWalletAsync(walletPointer);
  return xmr_ffi.startWalletRefresh(walletPointer);
}

void _stopSyncing(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  xmr_ffi.pauseWalletRefresh(walletPointer);
  xmr_ffi.stopWallet(walletPointer);
}

void _rescanWalletBlockchainAsync(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final result = xmr_ffi.rescanWalletBlockchainAsync(walletPointer);
  return result;
}

int _getBalance(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final accountIndex = args["acc"] as int;
  return xmr_ffi.getWalletBalance(walletPointer, accountIndex: accountIndex);
}

int _getUnlockedBalance(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final accountIndex = args["acc"] as int;
  return xmr_ffi.getWalletUnlockedBalance(
    walletPointer,
    accountIndex: accountIndex,
  );
}

String _getTxKey(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final txid = args["txid"] as String;
  return xmr_ffi.getTxKey(walletPointer, txid: txid);
}

Map<String, dynamic> _getTx(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final txid = args["txid"] as String;
  final refresh = args["refresh"] as bool;
  final txHistoryPointer = xmr_ffi.getTransactionHistoryPointer(walletPointer);

  if (refresh) {
    xmr_ffi.refreshTransactionHistory(txHistoryPointer);
  }

  final infoPointer =
      xmr_ffi.getTransactionInfoPointerByTxid(txHistoryPointer, txid: txid);

  return {
    "displayLabel": xmr_ffi.getTransactionInfoLabel(infoPointer),
    "description": xmr_ffi.getTransactionInfoDescription(infoPointer),
    "fee": xmr_ffi.getTransactionInfoFee(infoPointer).toString(),
    "confirmations": xmr_ffi.getTransactionInfoConfirmations(infoPointer),
    "blockHeight": xmr_ffi.getTransactionInfoBlockHeight(infoPointer),
    "accountIndex": xmr_ffi.getTransactionInfoAccount(infoPointer),
    "addressIndexes":
        xmr_ffi.getTransactionSubaddressIndexes(infoPointer).toList(),
    "paymentId": xmr_ffi.getTransactionInfoPaymentId(infoPointer),
    "amount": xmr_ffi.getTransactionInfoAmount(infoPointer).toString(),
    "isSpend": xmr_ffi.getTransactionInfoIsSpend(infoPointer),
    "hash": xmr_ffi.getTransactionInfoHash(infoPointer),
    "key": xmr_ffi.getTxKey(walletPointer, txid: txid),
    "timeStamp": xmr_ffi.getTransactionInfoTimestamp(infoPointer),
  };
}

List<Map<String, dynamic>> _getTxs(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final refresh = args["refresh"] as bool;
  final txids = args["txids"] as List<String>;
  final txHistoryPointer = xmr_ffi.getTransactionHistoryPointer(walletPointer);

  if (refresh) {
    xmr_ffi.refreshTransactionHistory(txHistoryPointer);
  }

  final List<Map<String, dynamic>> results = [];

  for (final txid in txids) {
    final infoPointer =
        xmr_ffi.getTransactionInfoPointerByTxid(txHistoryPointer, txid: txid);

    results.add({
      "displayLabel": xmr_ffi.getTransactionInfoLabel(infoPointer),
      "description": xmr_ffi.getTransactionInfoDescription(infoPointer),
      "fee": xmr_ffi.getTransactionInfoFee(infoPointer).toString(),
      "confirmations": xmr_ffi.getTransactionInfoConfirmations(infoPointer),
      "blockHeight": xmr_ffi.getTransactionInfoBlockHeight(infoPointer),
      "accountIndex": xmr_ffi.getTransactionInfoAccount(infoPointer),
      "addressIndexes":
          xmr_ffi.getTransactionSubaddressIndexes(infoPointer).toList(),
      "paymentId": xmr_ffi.getTransactionInfoPaymentId(infoPointer),
      "amount": xmr_ffi.getTransactionInfoAmount(infoPointer).toString(),
      "isSpend": xmr_ffi.getTransactionInfoIsSpend(infoPointer),
      "hash": xmr_ffi.getTransactionInfoHash(infoPointer),
      "key": xmr_ffi.getTxKey(walletPointer, txid: txid),
      "timeStamp": xmr_ffi.getTransactionInfoTimestamp(infoPointer),
    });
  }

  return results;
}

List<Map<String, dynamic>> _getAllTxs(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final refresh = args["refresh"] as bool;
  final txHistoryPointer = xmr_ffi.getTransactionHistoryPointer(walletPointer);

  if (refresh) {
    xmr_ffi.refreshTransactionHistory(txHistoryPointer);
  }

  final count = xmr_ffi.getTransactionHistoryCount(txHistoryPointer);

  final List<Map<String, dynamic>> results = [];

  final txids = List.generate(
    count,
    (index) => xmr_ffi.getTransactionInfoHash(
      xmr_ffi.getTransactionInfoPointer(
        txHistoryPointer,
        index: index,
      ),
    ),
  );

  for (final txid in txids) {
    final infoPointer =
        xmr_ffi.getTransactionInfoPointerByTxid(txHistoryPointer, txid: txid);

    results.add({
      "displayLabel": xmr_ffi.getTransactionInfoLabel(infoPointer),
      "description": xmr_ffi.getTransactionInfoDescription(infoPointer),
      "fee": xmr_ffi.getTransactionInfoFee(infoPointer).toString(),
      "confirmations": xmr_ffi.getTransactionInfoConfirmations(infoPointer),
      "blockHeight": xmr_ffi.getTransactionInfoBlockHeight(infoPointer),
      "accountIndex": xmr_ffi.getTransactionInfoAccount(infoPointer),
      "addressIndexes":
          xmr_ffi.getTransactionSubaddressIndexes(infoPointer).toList(),
      "paymentId": xmr_ffi.getTransactionInfoPaymentId(infoPointer),
      "amount": xmr_ffi.getTransactionInfoAmount(infoPointer).toString(),
      "isSpend": xmr_ffi.getTransactionInfoIsSpend(infoPointer),
      "hash": xmr_ffi.getTransactionInfoHash(infoPointer),
      "key": xmr_ffi.getTxKey(walletPointer, txid: txid),
      "timeStamp": xmr_ffi.getTransactionInfoTimestamp(infoPointer),
    });
  }

  return results;
}

List<String> _getAllTxids(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final refresh = args["refresh"] as bool;
  final txHistoryPointer = xmr_ffi.getTransactionHistoryPointer(walletPointer);

  if (refresh) {
    xmr_ffi.refreshTransactionHistory(txHistoryPointer);
  }

  final count = xmr_ffi.getTransactionHistoryCount(txHistoryPointer);

  return List.generate(
    count,
    (index) => xmr_ffi.getTransactionInfoHash(
      xmr_ffi.getTransactionInfoPointer(
        txHistoryPointer,
        index: index,
      ),
    ),
  );
}

List<Map<String, dynamic>> _getOutputs(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final refresh = args["refresh"] as bool;
  final includeSpent = args["includeSpent"] as bool;

  final coinsPointer = xmr_ffi.getCoinsPointer(walletPointer);

  if (refresh) {
    xmr_ffi.refreshCoins(coinsPointer);
  }

  final count = xmr_ffi.getCoinsCount(coinsPointer);

  final result = <Map<String, dynamic>>[];

  for (int i = 0; i < count; i++) {
    final coinInfoPointer = xmr_ffi.getCoinInfoPointer(coinsPointer, i);

    final hash = xmr_ffi.getHashForCoinsInfo(coinInfoPointer);

    if (hash.isNotEmpty) {
      final spent = xmr_ffi.isSpentCoinsInfo(coinInfoPointer);

      if (includeSpent || !spent) {
        final utxo = {
          "address": xmr_ffi.getAddressForCoinsInfo(coinInfoPointer),
          "hash": hash,
          "keyImage": xmr_ffi.getKeyImageForCoinsInfo(coinInfoPointer),
          "value": xmr_ffi.getAmountForCoinsInfo(coinInfoPointer),
          "isFrozen": xmr_ffi.isFrozenCoinsInfo(coinInfoPointer),
          "isUnlocked": xmr_ffi.isUnlockedCoinsInfo(coinInfoPointer),
          "vout": xmr_ffi.getInternalOutputIndexForCoinsInfo(coinInfoPointer),
          "spent": spent,
          "spentHeight": spent
              ? xmr_ffi.getSpentHeightForCoinsInfo(coinInfoPointer)
              : null,
          "height": xmr_ffi.getBlockHeightForCoinsInfo(coinInfoPointer),
          "coinbase": xmr_ffi.isCoinbaseCoinsInfo(coinInfoPointer),
        };

        result.add(utxo);
      }
    } else {
      Logging.log?.w("Found empty hash in monero utxo?!");
    }
  }

  return result;
}

bool _exportKeyImages(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final filename = args["fname"] as String;
  final all = args["all"] as bool;
  return xmr_ffi.exportWalletKeyImages(walletPointer, filename, all: all);
}

bool _importKeyImages(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final filename = args["fname"] as String;
  return xmr_ffi.importWalletKeyImages(walletPointer, filename);
}

void _freezeOutput(Map<String, dynamic> args) {
  final keyImage = args["ki"] as String;
  if (keyImage.isEmpty) {
    throw Exception("Attempted freeze of empty keyImage");
  }
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final coinsPointer = xmr_ffi.getCoinsPointer(walletPointer);

  final count = xmr_ffi.getAllCoinsSize(coinsPointer);

  for (int i = 0; i < count; i++) {
    if (keyImage ==
        xmr_ffi.getKeyImageForCoinsInfo(
          xmr_ffi.getCoinInfoPointer(coinsPointer, i),
        )) {
      xmr_ffi.freezeCoin(coinsPointer, index: i);
      return;
    }
  }

  throw Exception(
    "No matching keyImage found",
  );
}

void _thawOutput(Map<String, dynamic> args) {
  final keyImage = args["ki"] as String;
  if (keyImage.isEmpty) {
    throw Exception("Attempted thaw of empty keyImage");
  }
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final coinsPointer = xmr_ffi.getCoinsPointer(walletPointer);

  final count = xmr_ffi.getAllCoinsSize(coinsPointer);

  for (int i = 0; i < count; i++) {
    if (keyImage ==
        xmr_ffi.getKeyImageForCoinsInfo(
          xmr_ffi.getCoinInfoPointer(coinsPointer, i),
        )) {
      xmr_ffi.thawCoin(coinsPointer, index: i);
      return;
    }
  }

  throw Exception(
    "No matching keyImage found",
  );
}

Map<String, dynamic> _createTransaction(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);

  final recipientAddress = args["addr"] as String;
  final amount = args["amt"] as int;
  final subaddressAccount = args["acc"] as int;
  final pendingTransactionPriority = args["prio"] as int;
  final paymentId = args["pid"] as String;
  final sweep = args["sweep"] as bool;
  final inputs = args["kis"] as List<String>;

  final pendingTxPointer = xmr_ffi.createTransaction(
    walletPointer,
    address: recipientAddress,
    paymentId: paymentId,
    amount: sweep ? 0 : amount,
    pendingTransactionPriority: pendingTransactionPriority,
    subaddressAccount: subaddressAccount,
    preferredInputs: inputs,
  );

  xmr_ffi.checkPendingTransactionStatus(pendingTxPointer);

  return {
    "amount": xmr_ffi.getPendingTransactionAmount(pendingTxPointer),
    "fee": xmr_ffi.getPendingTransactionFee(pendingTxPointer),
    "txid": xmr_ffi.getPendingTransactionTxid(pendingTxPointer),
    "hex": xmr_ffi.getPendingTransactionHex(pendingTxPointer),
    "pointerAddress": pendingTxPointer.address,
  };
}

Map<String, dynamic> _createTransactionMultiDest(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);

  final recipientAddresses = args["addrs"] as List<String>;
  final amounts = args["amts"] as List<int>;
  final subaddressAccount = args["acc"] as int;
  final pendingTransactionPriority = args["prio"] as int;
  final paymentId = args["pid"] as String;
  final sweep = args["sweep"] as bool;
  final inputs = args["kis"] as List<String>;

  final pendingTxPointer = xmr_ffi.createTransactionMultiDest(
    walletPointer,
    addresses: recipientAddresses,
    paymentId: paymentId,
    amounts: amounts,
    pendingTransactionPriority: pendingTransactionPriority,
    subaddressAccount: subaddressAccount,
    preferredInputs: inputs,
    isSweepAll: sweep,
  );

  xmr_ffi.checkPendingTransactionStatus(pendingTxPointer);

  return {
    "amount": xmr_ffi.getPendingTransactionAmount(pendingTxPointer),
    "fee": xmr_ffi.getPendingTransactionFee(pendingTxPointer),
    "txid": xmr_ffi.getPendingTransactionTxid(pendingTxPointer),
    "hex": xmr_ffi.getPendingTransactionHex(pendingTxPointer),
    "pointerAddress": pendingTxPointer.address,
  };
}

bool _commitTx(Map<String, dynamic> args) {
  final pendingTxPointer = Pointer<Void>.fromAddress(args["ptr"] as int);
  final result = xmr_ffi.commitPendingTransaction(
    pendingTxPointer,
  );

  xmr_ffi.checkPendingTransactionStatus(pendingTxPointer);

  return result;
}

String _signMessage(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final address = args["addr"] as String;
  final message = args["msg"] as String;
  return xmr_ffi.signMessageWith(
    walletPointer,
    message: message,
    address: address,
  );
}

bool _verifyMessage(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final address = args["addr"] as String;
  final message = args["msg"] as String;
  final signature = args["sig"] as String;

  return xmr_ffi.verifySignedMessageWithWallet(
    walletPointer,
    message: message,
    address: address,
    signature: signature,
  );
}

bool _validateAddress(Map<String, dynamic> args) {
  final address = args["addr"] as String;
  final networkType = args["net"] as int;
  return xmr_ffi.validateAddress(address, networkType);
}

int _amountFromString(Map<String, dynamic> args) {
  return xmr_ffi.amountFromString(args["amt"] as String);
}

String _getPassword(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);

  return xmr_ffi.getWalletPassword(walletPointer);
}

bool _changePassword(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final newPassword = args["pw"] as String;

  return xmr_ffi.setWalletPassword(walletPointer, password: newPassword);
}

bool _save(Map<String, dynamic> args) {
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  return xmr_ffi.storeWallet(walletPointer, path: "");
}

void _close(Map<String, dynamic> args) {
  final wmPointer = Pointer<Void>.fromAddress(args["wm"] as int);
  final walletPointer = Pointer<Void>.fromAddress(args["wp"] as int);
  final save = args["save"] as bool;

  if (save) {
    xmr_ffi.storeWallet(walletPointer, path: "");
  }

  xmr_wm_ffi.closeWallet(wmPointer, walletPointer, save);
}
