import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'monero_bindings_base.dart';

/// Will throw on failure
void checkWalletStatus(Pointer<Void> walletPointer) {
  final status = bindings.MONERO_Wallet_status(walletPointer);

  if (status == 0) {
    return;
  }
  final stringPointer = bindings.MONERO_Wallet_errorString(
    walletPointer,
  ).cast<Utf8>();

  throw Exception(convertAndFree(stringPointer));
}

bool storeWallet(Pointer<Void> walletPointer, {required String path}) {
  final pathPointer = path.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_store(walletPointer, pathPointer);
  } finally {
    calloc.free(pathPointer);
  }
}

bool initWallet(
  Pointer<Void> walletPointer, {
  required String daemonAddress,
  int upperTransactionSizeLimit = 0,
  String daemonUsername = "",
  String daemonPassword = "",
  bool useSsl = false,
  bool lightWallet = false,
  String proxyAddress = "",
}) {
  final daemonAddressPointer = daemonAddress.toNativeUtf8().cast<Char>();
  final daemonUsernamePointer = daemonUsername.toNativeUtf8().cast<Char>();
  final daemonPasswordPointer = daemonPassword.toNativeUtf8().cast<Char>();
  final proxyAddressPointer = proxyAddress.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_init(
      walletPointer,
      daemonAddressPointer,
      upperTransactionSizeLimit,
      daemonUsernamePointer,
      daemonPasswordPointer,
      useSsl,
      lightWallet,
      proxyAddressPointer,
    );
  } finally {
    calloc.free(daemonAddressPointer);
    calloc.free(daemonUsernamePointer);
    calloc.free(daemonPasswordPointer);
    calloc.free(proxyAddressPointer);
  }
}

void setTrustedDaemon(Pointer<Void> walletPointer, {required bool arg}) {
  bindings.MONERO_Wallet_setTrustedDaemon(walletPointer, arg);
}

bool isWatchOnly(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_watchOnly(walletPointer);
}

int isConnected(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_connected(walletPointer);
}

bool isSynchronized(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_synchronized(walletPointer);
}

String getWalletPath(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_path(walletPointer).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== Address ======================================================

bool validateAddress(String address, int networkType) {
  final addressPointer = address.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_addressValid(addressPointer, networkType);
  } finally {
    calloc.free(addressPointer);
  }
}

String getWalletAddress(
  Pointer<Void> walletPointer, {
  int accountIndex = 0,
  int addressIndex = 0,
}) {
  final stringPointer = bindings.MONERO_Wallet_address(
    walletPointer,
    accountIndex,
    addressIndex,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== Chain ========================================================

int getWalletBlockChainHeight(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_blockChainHeight(walletPointer);
}

int getDaemonBlockChainHeight(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_daemonBlockChainHeight(walletPointer);
}

void setWalletRefreshFromBlockHeight(
  Pointer<Void> walletPointer, {
  required int refreshFromBlockHeight,
}) {
  bindings.MONERO_Wallet_setRefreshFromBlockHeight(
    walletPointer,
    refreshFromBlockHeight,
  );
}

int getWalletRefreshFromBlockHeight(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_getRefreshFromBlockHeight(walletPointer);
}

void setWalletAutoRefreshInterval(
  Pointer<Void> walletPointer, {
  required int millis,
}) {
  bindings.MONERO_Wallet_setAutoRefreshInterval(walletPointer, millis);
}

void refreshWalletAsync(Pointer<Void> walletPointer) {
  bindings.MONERO_Wallet_refreshAsync(walletPointer);
}

void startWalletRefresh(Pointer<Void> walletPointer) {
  bindings.MONERO_Wallet_startRefresh(walletPointer);
}

void pauseWalletRefresh(Pointer<Void> walletPointer) {
  bindings.MONERO_Wallet_pauseRefresh(walletPointer);
}

void stopWallet(Pointer<Void> walletPointer) {
  bindings.MONERO_Wallet_stop(walletPointer);
}

void rescanWalletBlockchainAsync(Pointer<Void> walletPointer) {
  bindings.MONERO_Wallet_rescanBlockchainAsync(walletPointer);
}

// =============================================================================
// ============== Balance ======================================================

int getWalletBalance(Pointer<Void> walletPointer, {required int accountIndex}) {
  return bindings.MONERO_Wallet_balance(walletPointer, accountIndex);
}

int getWalletUnlockedBalance(
  Pointer<Void> walletPointer, {
  required int accountIndex,
}) {
  return bindings.MONERO_Wallet_unlockedBalance(walletPointer, accountIndex);
}

// =============================================================================
// ============== History/Transactions =========================================

String getTxKey(Pointer<Void> walletPointer, {required String txid}) {
  final txidPointer = txid.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_Wallet_getTxKey(
      walletPointer,
      txidPointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(txidPointer);
  }
}

Pointer<Void> getTransactionHistoryPointer(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_history(walletPointer);
}

void refreshTransactionHistory(Pointer<Void> txHistoryPointer) {
  bindings.MONERO_TransactionHistory_refresh(txHistoryPointer);
}

int getTransactionHistoryCount(Pointer<Void> txHistoryPointer) {
  return bindings.MONERO_TransactionHistory_count(txHistoryPointer);
}

Pointer<Void> getTransactionInfoPointer(
  Pointer<Void> txHistoryPointer, {
  required int index,
}) {
  return bindings.MONERO_TransactionHistory_transaction(
    txHistoryPointer,
    index,
  );
}

Pointer<Void> getTransactionInfoPointerByTxid(
  Pointer<Void> txHistoryPointer, {
  required String txid,
}) {
  final txidPointer = txid.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_TransactionHistory_transactionById(
      txHistoryPointer,
      txidPointer,
    );
  } finally {
    calloc.free(txidPointer);
  }
}

// =============================================================================
// ============== Transactions =================================================

Pointer<Void> createTransaction(
  Pointer<Void> walletPointer, {
  required String address,
  required String paymentId,
  required int amount,
  required int pendingTransactionPriority,
  required int subaddressAccount,
  List<String> preferredInputs = const [],
}) {
  final addressPointer = address.toNativeUtf8().cast<Char>();
  final paymentIdPointer = paymentId.toNativeUtf8().cast<Char>();
  final preferredInputsPointer = preferredInputs
      .join(
        defaultSeparatorStr,
      )
      .toNativeUtf8()
      .cast<Char>();

  try {
    return bindings.MONERO_Wallet_createTransaction(
      walletPointer,
      addressPointer,
      paymentIdPointer,
      amount,
      0, // mixin count/ring size. Ignored here, core code will use appropriate value
      pendingTransactionPriority,
      subaddressAccount,
      preferredInputsPointer,
      defaultSeparator,
    );
  } finally {
    calloc.free(addressPointer);
    calloc.free(paymentIdPointer);
    calloc.free(preferredInputsPointer);
  }
}

Pointer<Void> createTransactionMultiDest(
  Pointer<Void> walletPointer, {
  required List<String> addresses,
  required String paymentId,
  required bool isSweepAll,
  required List<int> amounts,
  required int pendingTransactionPriority,
  required int subaddressAccount,
  List<String> preferredInputs = const [],
}) {
  final addressesPointer = addresses.join(defaultSeparatorStr).toNativeUtf8();
  final paymentIdPointer = paymentId.toNativeUtf8();
  final amountsPointer = amounts
      .map((e) => e.toString())
      .join(
        defaultSeparatorStr,
      )
      .toNativeUtf8();
  final preferredInputsPointer = preferredInputs
      .join(
        defaultSeparatorStr,
      )
      .toNativeUtf8();

  try {
    return bindings.MONERO_Wallet_createTransactionMultDest(
      walletPointer,
      addressesPointer.cast(),
      defaultSeparator,
      paymentIdPointer.cast(),
      isSweepAll,
      amountsPointer.cast(),
      defaultSeparator,
      0, // mixin count/ring size. Ignored here, core code will use appropriate value
      pendingTransactionPriority,
      subaddressAccount,
      preferredInputsPointer.cast(),
      defaultSeparator,
    );
  } finally {
    calloc.free(addressesPointer);
    calloc.free(paymentIdPointer);
    calloc.free(amountsPointer);
    calloc.free(preferredInputsPointer);
  }
}

// =============================================================================
// ============== Pending Transaction ==========================================

/// Will throw on failure
void checkPendingTransactionStatus(Pointer<Void> pendingTransactionPointer) {
  final status = bindings.MONERO_PendingTransaction_status(
    pendingTransactionPointer,
  );
  if (status == 0) {
    return;
  }
  final stringPointer = bindings.MONERO_PendingTransaction_errorString(
    pendingTransactionPointer,
  ).cast<Utf8>();

  throw Exception(convertAndFree(stringPointer));
}

int getPendingTransactionAmount(Pointer<Void> pendingTransactionPointer) {
  return bindings.MONERO_PendingTransaction_amount(pendingTransactionPointer);
}

int getPendingTransactionFee(Pointer<Void> pendingTransactionPointer) {
  return bindings.MONERO_PendingTransaction_fee(pendingTransactionPointer);
}

String getPendingTransactionTxid(
  Pointer<Void> pendingTransactionPointer, {
  String separator = "",
}) {
  final separatorPointer = separator.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_PendingTransaction_txid(
      pendingTransactionPointer,
      separatorPointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(separatorPointer);
  }
}

String getPendingTransactionHex(
  Pointer<Void> pendingTransactionPointer, {
  String separator = "",
}) {
  final separatorPointer = separator.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_PendingTransaction_hex(
      pendingTransactionPointer,
      separatorPointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(separatorPointer);
  }
}

bool commitPendingTransaction(
  Pointer<Void> pendingTransactionPointer, {
  String filename = "",
  bool overwrite = false,
}) {
  final filenamePointer = filename.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_PendingTransaction_commit(
      pendingTransactionPointer,
      filenamePointer,
      overwrite,
    );
  } finally {
    calloc.free(filenamePointer);
  }
}

// =============================================================================
// ============== Coins ========================================================

Pointer<Void> getCoinsPointer(Pointer<Void> walletPointer) {
  return bindings.MONERO_Wallet_coins(walletPointer);
}

void refreshCoins(Pointer<Void> coinsPointer) {
  bindings.MONERO_Coins_refresh(coinsPointer);
}

int getCoinsCount(Pointer<Void> coinsPointer) {
  return bindings.MONERO_Coins_count(coinsPointer);
}

int getAllCoinsSize(Pointer<Void> coinsPointer) {
  return bindings.MONERO_Coins_getAll_size(coinsPointer);
}

Pointer<Void> getCoinInfoPointer(Pointer<Void> coinsPointer, int index) {
  return bindings.MONERO_Coins_coin(coinsPointer, index);
}

void freezeCoin(Pointer<Void> coinsPointer, {required int index}) {
  bindings.MONERO_Coins_setFrozen(coinsPointer, index);
}

void thawCoin(Pointer<Void> coinsPointer, {required int index}) {
  bindings.MONERO_Coins_thaw(coinsPointer, index);
}

// =============================================================================
// ============== Coins Info ===================================================

int getInternalOutputIndexForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_internalOutputIndex(coinsInfoPointer);
}

bool isFrozenCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_frozen(coinsInfoPointer);
}

bool isSpentCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_spent(coinsInfoPointer);
}

int getSpentHeightForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_spentHeight(coinsInfoPointer);
}

int getAmountForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_amount(coinsInfoPointer);
}

int getBlockHeightForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_blockHeight(coinsInfoPointer);
}

bool isUnlockedCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_unlocked(coinsInfoPointer);
}

bool isCoinbaseCoinsInfo(Pointer<Void> coinsInfoPointer) {
  return bindings.MONERO_CoinsInfo_coinbase(coinsInfoPointer);
}

String getAddressForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  final stringPointer = bindings.MONERO_CoinsInfo_address(
    coinsInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getKeyImageForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  final stringPointer = bindings.MONERO_CoinsInfo_keyImage(
    coinsInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getHashForCoinsInfo(Pointer<Void> coinsInfoPointer) {
  final stringPointer = bindings.MONERO_CoinsInfo_hash(
    coinsInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== Key Images ===================================================

bool exportWalletKeyImages(
  Pointer<Void> walletPointer,
  String filename, {
  required bool all,
}) {
  final filenamePointer = filename.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_exportKeyImages(
      walletPointer,
      filenamePointer,
      all,
    );
  } finally {
    calloc.free(filenamePointer);
  }
}

bool importWalletKeyImages(Pointer<Void> walletPointer, String filename) {
  final filenamePointer = filename.toNativeUtf8().cast<Char>();

  try {
    return bindings.MONERO_Wallet_importKeyImages(
      walletPointer,
      filenamePointer,
    );
  } finally {
    calloc.free(filenamePointer);
  }
}

// =============================================================================
// ============== Sign/Verify ==================================================

String signMessageWith(
  Pointer<Void> walletPointer, {
  required String message,
  required String address,
}) {
  final messagePointer = message.toNativeUtf8().cast<Char>();
  final addressPointer = address.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_Wallet_signMessage(
      walletPointer,
      messagePointer,
      addressPointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(messagePointer);
    calloc.free(addressPointer);
  }
}

bool verifySignedMessageWithWallet(
  Pointer<Void> walletPointer, {
  required String message,
  required String address,
  required String signature,
}) {
  final messagePointer = message.toNativeUtf8().cast<Char>();
  final addressPointer = address.toNativeUtf8().cast<Char>();
  final signaturePointer = signature.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_verifySignedMessage(
      walletPointer,
      messagePointer,
      addressPointer,
      signaturePointer,
    );
  } finally {
    calloc.free(messagePointer);
    calloc.free(addressPointer);
    calloc.free(signaturePointer);
  }
}

// =============================================================================
// ============== Seed/Password ================================================

String getWalletSeed(
  Pointer<Void> walletPointer, {
  required String seedOffset,
}) {
  final seedOffsetPointer = seedOffset.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_Wallet_seed(
      walletPointer,
      seedOffsetPointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(seedOffsetPointer);
  }
}

String getWalletSeedLanguage(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_getSeedLanguage(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getWalletPolyseed(
  Pointer<Void> walletPointer, {
  required String passphrase,
}) {
  final passphrasePointer = passphrase.toNativeUtf8().cast<Char>();
  try {
    final stringPointer = bindings.MONERO_Wallet_getPolyseed(
      walletPointer,
      passphrasePointer,
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(passphrasePointer);
  }
}

String createPolyseed({String language = "English"}) {
  final languagePointer = language.toNativeUtf8();
  try {
    final stringPointer = bindings.MONERO_Wallet_createPolyseed(
      languagePointer.cast(),
    ).cast<Utf8>();
    return convertAndFree(stringPointer);
  } finally {
    calloc.free(languagePointer);
  }
}

bool setWalletPassword(
  Pointer<Void> walletPointer, {
  required String password,
}) {
  final passwordPointer = password.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_setPassword(walletPointer, passwordPointer);
  } finally {
    calloc.free(passwordPointer);
  }
}

String getWalletPassword(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_getPassword(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== Keys =========================================================

String getWalletSecretViewKey(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_secretViewKey(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getWalletPublicViewKey(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_publicViewKey(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getWalletSecretSpendKey(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_secretSpendKey(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getWalletPublicSpendKey(Pointer<Void> walletPointer) {
  final stringPointer = bindings.MONERO_Wallet_publicSpendKey(
    walletPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== TransactionInfo ==============================================

int getTransactionInfoAmount(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_amount(txInfoPointer);
}

int getTransactionInfoFee(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_fee(txInfoPointer);
}

int getTransactionInfoConfirmations(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_confirmations(txInfoPointer);
}

int getTransactionInfoBlockHeight(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_blockHeight(txInfoPointer);
}

int getTransactionInfoTimestamp(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_timestamp(txInfoPointer);
}

int getTransactionInfoAccount(Pointer<Void> txInfoPointer) {
  return bindings.MONERO_TransactionInfo_subaddrAccount(txInfoPointer);
}

Set<int> getTransactionSubaddressIndexes(Pointer<Void> txInfoPointer) {
  final stringPointer = bindings.MONERO_TransactionInfo_subaddrIndex(
    txInfoPointer,
    defaultSeparator,
  ).cast<Utf8>();
  final indexesString = convertAndFree(stringPointer);
  final indexes = indexesString.split(", ").map(int.parse);
  return indexes.toSet();
}

bool getTransactionInfoIsSpend(Pointer<Void> txInfoPointer) {
  // 0 is incoming, 1 is outgoing
  return bindings.MONERO_TransactionInfo_direction(txInfoPointer) == 1;
}

String getTransactionInfoLabel(Pointer<Void> txInfoPointer) {
  final stringPointer = bindings.MONERO_TransactionInfo_label(
    txInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getTransactionInfoDescription(Pointer<Void> txInfoPointer) {
  final stringPointer = bindings.MONERO_TransactionInfo_description(
    txInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getTransactionInfoPaymentId(Pointer<Void> txInfoPointer) {
  final stringPointer = bindings.MONERO_TransactionInfo_paymentId(
    txInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

String getTransactionInfoHash(Pointer<Void> txInfoPointer) {
  final stringPointer = bindings.MONERO_TransactionInfo_hash(
    txInfoPointer,
  ).cast<Utf8>();
  return convertAndFree(stringPointer);
}

// =============================================================================
// ============== Other ========================================================

int amountFromString(String amount) {
  final amountPointer = amount.toNativeUtf8().cast<Char>();
  try {
    return bindings.MONERO_Wallet_amountFromString(amountPointer);
  } finally {
    calloc.free(amountPointer);
  }
}
