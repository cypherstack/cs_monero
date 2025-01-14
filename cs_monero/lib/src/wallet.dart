import 'dart:async';

import 'package:meta/meta.dart';

import '../cs_monero.dart';

abstract class Wallet {
  Timer? _pollingTimer;
  final List<WalletListener> _listeners = [];

  /// Add a [WalletListener] to the wallet.
  void addListener(WalletListener listener) {
    _listeners.add(listener);
  }

  /// Remove a [WalletListener] from the wallet.
  void removeListener(WalletListener listener) {
    _listeners.remove(listener);
  }

  /// Returns all [WalletListener]s.
  List<WalletListener> getListeners() => List.unmodifiable(_listeners);

  Duration pollingInterval = const Duration(seconds: 5);

  /// Start polling the wallet. [WalletListener] objects added to this wallet
  /// using [addListener] will have their callbacks triggered here as appropriate.
  ///
  /// Additional calls to [startListeners] will be ignored if it is already running.
  void startListeners() {
    _pollingTimer ??= Timer.periodic(
      pollingInterval,
      (_) {
        try {
          _poll();
        } catch (error, stackTrace) {
          for (final listener in getListeners()) {
            listener.onError?.call(error, stackTrace);
          }
        }
      },
    );
  }

  /// Stop polling the wallet, effectively stopping all listeners.
  void stopListeners() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  int? _lastDaemonHeight;
  int? _lastSyncHeight;
  BigInt? _lastBalanceUnlocked;
  BigInt? _lastBalanceFull;

  void _poll() async {
    Logging.log?.d("Polling");

    final full = getBalance();
    final unlocked = getUnlockedBalance();
    if (unlocked != _lastBalanceUnlocked || full != _lastBalanceFull) {
      Logging.log?.d("listener.onBalancesChanged");
      for (final listener in getListeners()) {
        listener.onBalancesChanged
            ?.call(newBalance: full, newUnlockedBalance: unlocked);
      }
    }
    _lastBalanceUnlocked = unlocked;
    _lastBalanceFull = full;

    final nodeHeight = getDaemonHeight();
    final heightChanged = nodeHeight != _lastDaemonHeight;
    if (heightChanged) {
      Logging.log?.d("listener.onNewBlock");
      for (final listener in getListeners()) {
        listener.onNewBlock?.call(nodeHeight);
      }
    }
    _lastDaemonHeight = nodeHeight;

    final currentSyncingHeight = getCurrentWalletSyncingHeight();
    if (currentSyncingHeight >= 0 &&
        currentSyncingHeight <= nodeHeight &&
        (heightChanged || currentSyncingHeight != _lastSyncHeight)) {
      Logging.log?.d("listener.onSyncingUpdate");
      for (final listener in getListeners()) {
        listener.onSyncingUpdate?.call(
          syncHeight: currentSyncingHeight,
          nodeHeight: nodeHeight,
        );
      }
    }

    _lastSyncHeight = currentSyncingHeight;
  }

  Timer? _autoSaveTimer;

  /// Configurable interval used when [startAutoSaving] is called.
  Duration autoSaveInterval = const Duration(minutes: 2);

  /// Start periodically calling [save]
  ///
  /// Will do nothing if wallet is closed.
  /// Auto saving will be cancelled if the wallet is closed.
  void startAutoSaving() {
    if (isClosed()) {
      return;
    }

    stopAutoSaving();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) async {
      if (isClosed()) {
        stopAutoSaving();
        return;
      }
      Logging.log?.d("Starting autosave");
      await save();
      Logging.log?.d("Finished autosave");
    });
  }

  /// Stop periodically calling [save].
  void stopAutoSaving() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  // TODO: handle this differently
  /// Rough fee estimation
  @Deprecated("Unverified hard coded values used")
  Future<int> estimateFee(TransactionPriority priority, int amount) async {
    // FIXME: hardcoded value;
    switch (priority) {
      case TransactionPriority.normal:
        return 24590000;
      case TransactionPriority.low:
        return 123050000;
      case TransactionPriority.medium:
        return 245029999;
      case TransactionPriority.high:
        return 614530000;
      case TransactionPriority.last:
        return 26021600000;
    }
  }

  // ===========================================================================
  // ======= Shared Internal ===================================================

  /// Do not use this outside this library.
  @protected
  Future<List<String>> checkAndProcessInputs({
    required List<Output> inputs,
    required BigInt sendAmount,
    required bool sweep,
  }) async {
    final inSum = inputs.map((e) => e.value).fold(BigInt.zero, (p, e) => p + e);
    if (inSum < sendAmount) {
      throw Exception("Not enough inputs to cover specified amount");
    }

    if (sweep) {
      if (sendAmount != inSum) {
        throw Exception(
          "Sweep all found mismatch of amount to send and selected inputs total value",
        );
      }
    } else {
      if (sendAmount == inSum) {
        throw Exception(
          "Amount is equal to sum of input values. Did you mean to do a sweep?",
        );
      }
      // if its not a sweep, normal logic should be fine so no need to do the
      // expensive process below
      return [];
    }

    await refreshOutputs();
    final allUnusedOutputs = await getOutputs();
    allUnusedOutputs.removeWhere((e) {
      if (e.isFrozen) {
        return true;
      }

      for (final input in inputs) {
        if (input.keyImage == e.keyImage) {
          return true;
        }
      }

      return false;
    });

    final List<Output> frozen = [];
    try {
      for (final utxo in allUnusedOutputs) {
        await freezeOutput(utxo.keyImage);
        frozen.add(utxo.copyWithFrozen(true));
      }

      return frozen.map((e) => e.keyImage).toList(growable: false);
    } catch (e, s) {
      Logging.log?.e(
        "checkAndProcessInputs temp. freezing failed.",
        error: e,
        stackTrace: s,
      );
      rethrow;
    } finally {
      // attempt to thaw any temp frozen outputs
      for (final utxo in frozen) {
        await thawOutput(utxo.keyImage);
      }
    }
  }

  /// Do not use this outside this library.
  @protected
  Future<void> postProcessInputs({
    required List<String> keyImages,
  }) async {
    try {
      for (final keyImage in keyImages) {
        await thawOutput(keyImage);
      }
    } catch (e, s) {
      Logging.log?.e(
        "postProcessInputs failed.",
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // ===========================================================================
  // ======= Interface =========================================================

  @protected
  Future<void> refreshOutputs();

  @protected
  Future<void> refreshTransactions();

  @protected
  int transactionCount();

  /// Returns the current block height of the wallet. Anything less than the
  /// [getDaemonHeight] value (+/- 1) likely indicates the wallet is not fully
  /// synced.
  int getCurrentWalletSyncingHeight();

  /// Returns a rough height estimate for a given [date].
  int getBlockChainHeightByDate(DateTime date);

  /// Initialize and connect to a daemon.
  Future<void> connect({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  });

  // Future<bool> createViewOnlyWalletFromCurrentWallet({
  //   required String path,
  //   required String password,
  //   String language = "English",
  // });

  /// Returns true if the wallet is a view only wallet.
  bool isViewOnly();

  // void setDaemonConnection(DaemonConnection connection);
  // DaemonConnection getDaemonConnection();
  // void setProxyUri(String proxyUri);

  /// Returns true if the wallet has an active daemon connection.
  Future<bool> isConnectedToDaemon();

  /// Returns true if the wallet is fully synced
  Future<bool> isSynced();

  // Version getVersion();
  // NetworkType getNetworkType();

  /// Returns the location where the wallet files are stored.
  String getPath();

  /// Returns the seed phrase (mnemonic) of the wallet.
  String getSeed();

  /// Returns the language of the seed phrase (mnemonic).
  String getSeedLanguage();

  /// Returns the private spend key for the wallet.
  String getPrivateSpendKey();

  /// Returns the private view key for the wallet.
  String getPrivateViewKey();

  /// Returns the public spend key for the wallet.
  String getPublicSpendKey();

  /// Returns the public view key for the wallet.
  String getPublicViewKey();

  /// Returns a receiving address given an [accountIndex] and sub[addressIndex].
  /// If the [addressIndex] is zero, the main address for the given
  /// [accountIndex] will be returned.
  Address getAddress({int accountIndex = 0, int addressIndex = 0});

  /// Returns the current chain height as seen by the connected daemon.
  int getDaemonHeight();

  // int getDaemonMaxPeerHeight();
  // int getApproximateChainHeight();
  // int getHeight();
  // int getHeightByDate(int year, int month, int day);

  /// Returns the height of the wallet used for rescanning/refreshing.
  int getRefreshFromBlockHeight();

  /// Set the height of the wallet used for rescanning/refreshing.
  void setRefreshFromBlockHeight(int startHeight);

  /// Sets the auto refresh interval and starts refreshing/syncing.
  void startSyncing({Duration interval = const Duration(seconds: 20)});

  /// Stop syncing/refreshing
  void stopSyncing();

  // Future<bool> rescanSpent();

  /// Rescans the wallet from [getRefreshFromBlockHeight].
  Future<bool> rescanBlockchain();

  /// Returns the wallet's full balance in atomic units.
  BigInt getBalance({int accountIndex = 0});

  /// Returns the wallet's unlocked balance in atomic units.
  BigInt getUnlockedBalance({int accountIndex = 0});

  // Disable for now
  // List<Account> getAccounts({bool includeSubaddresses = false});
  // Account getAccount(int accountIdx, {bool includeSubaddresses = false});
  // void createAccount({String? label});
  // void setAccountLabel(int accountIdx, String label);
  // void setSubaddressLabel(int accountIdx, int addressIdx, String label);

  String getTxKey(String txid);

  /// Returns a transaction given it's [txid]/hash
  Future<Transaction> getTx(String txid, {bool refresh = false});

  /// Returns transactions matching the given set of txids
  Future<List<Transaction>> getTxs({
    required Set<String> txids,
    bool refresh = false,
  });

  Future<List<Transaction>> getAllTxs({bool refresh = false});

  /// Returns all wallet transaction ids
  Future<List<String>> getAllTxids({bool refresh = false});

  // List<Transfer> getTransfers({int? accountIdx, int? subaddressIdx});

  /// Returns all known wallet outputs.
  /// Use the [includeSpent] flag to ignore used outputs if desired.
  /// Setting [refresh] to true will ensure the internal outputs state is
  /// refreshed before fetching.
  Future<List<Output>> getOutputs({
    bool includeSpent = false,
    bool refresh = false,
  });

  Future<bool> exportKeyImages({required String filename, bool all = false});
  Future<bool> importKeyImages({required String filename});

  /// Freeze an output given it's [keyImage]. Renders the output un-spendable.
  Future<void> freezeOutput(String keyImage);

  /// Un freeze a frozen output.
  Future<void> thawOutput(String keyImage);

  /// Create a single recipient transaction.
  ///
  /// Returns a [PendingTransaction], required for [commitTx].
  Future<PendingTransaction> createTx({
    required Recipient output,
    required TransactionPriority priority,
    required int accountIndex,
    List<Output>? preferredInputs,
    String paymentId = "",
    bool sweep = false,
  });

  /// Create a multi recipient transaction.
  ///
  /// Returns a [PendingTransaction], required for [commitTx].
  Future<PendingTransaction> createTxMultiDest({
    required List<Recipient> outputs,
    required TransactionPriority priority,
    required int accountIndex,
    String paymentId = "",
    List<Output>? preferredInputs,
    bool sweep = false,
  });

  // List<PendingTransaction> createTxs(TxConfig config);
  // Tx sweepOutput(TxConfig config);
  // List<Tx> sweepUnlocked(TxConfig config);
  // List<Tx> sweepDust({bool relay = false});

  // String relayTxMeta(String txMetadata);
  // String relayTx(Tx tx);
  // List<String> submitTxs(String signedTxHex);

  /// Commit/broadcast a transaction to the network.
  Future<void> commitTx(PendingTransaction tx);

  // Future<String> signMessage(
  //   String message,
  //   MessageSignatureType type,
  //   int accountIdx,
  //   int subaddressIdx,
  // );

  /// Sign a message
  Future<String> signMessage(
    String message,
    String address,
  );

  /// Verify a signed message
  Future<bool> verifyMessage(
    String message,
    String address,
    String signature,
  );

  /// Convert a decimal amount string to atomic units.
  /// Returns null on invalid string format.
  BigInt? amountFromString(String value);

  // String getTxKey(String txId);
  // CheckTx checkTxKey(String txId, String txKey, String address);

  // String getTxProof(String txId, String address, {String? message});
  // CheckTx checkTxProof(
  //     String txId, String address, String message, String signature);
  // String getSpendProof(String txId, {String? message});
  // bool checkSpendProof(String txId, String message, String signature);
  // String getReserveProofWallet(String message);
  // String getReserveProofAccount(int accountIdx, int amount, String message);
  // CheckReserve checkReserveProof(
  //     String address, String message, String signature);

  // void setTxNotes(List<String> txHashes, List<String> notes);
  // void setTxNote(String txHash, String note);
  // List<String> getTxNotes(List<String> txHashes);
  // String getTxNote(String txHash);
  // List<AddressBookEntry> getAddressBookEntries({List<int>? entryIndices});
  // int addAddressBookEntry(String address, String description);
  // void editAddressBookEntry(int entryIdx, bool setAddress, String address,
  //     bool setDescription, String description);
  // void deleteAddressBookEntry(int entryIdx);
  // void tagAccounts(String tag, List<int> accountIndices);
  // void untagAccounts(List<int> accountIndices);
  // List<AccountTag> getAccountTags();
  // void setAccountTagLabel(String tag, String label);

  // TODO
  // String getPaymentUri(TxConfig request);

  // SendRequest parsePaymentUri(String uri);
  // String getAttribute(String key);
  // void setAttribute(String key, String val);

  // bool isMultisigImportNeeded();
  // bool isMultisig();
  // MultisigInfo getMultisigInfo();
  // String prepareMultisig();
  // String makeMultisig(
  //     List<String> multisigHexes, int threshold, String password);
  // MultisigInitResult exchangeMultisigKeys(
  //     List<String> multisigHexes, String password);
  // String exportMultisigHex();
  // int importMultisigHex(List<String> multisigHexes);
  // MultisigSignResult signMultisigTxHex(String multisigTxHex);
  // List<String> submitMultisig(String signedMultisigHex);

  // void moveTo(String path);

  /// Returns the wallet password.
  String getPassword();

  /// Change the password of the wallet
  void changePassword(String newPassword);

  /// Saves the current state of the wallet to disk.
  Future<void> save();

  /// Close the wallet. If [save] is true, [save] will be called before closing.
  Future<void> close({bool save = false});

  /// A flag to check if the wallet is closed.
  bool isClosed();
}
