import 'dart:ffi';

/// Holds the pointer address of a pending transaction in the native code as
/// well as some associated data exposed to Dart. A payment may be split into
/// multiple transactions.
class PendingTransaction {
  PendingTransaction({
    required this.amount,
    required this.fee,
    required this.txids,
    required this.hexes,
    required this.pointerAddress,
  }) {
    if (amount.isNegative) throw Exception("Invalid amount");
    if (fee.isNegative) throw Exception("Invalid fee");
    if (txids.isEmpty || txids.any((txid) => txid.isEmpty)) {
      throw Exception("txids cannot be empty or contain empty entries");
    }
    if (hexes.isEmpty || hexes.any((hex) => hex.isEmpty)) {
      throw Exception("hexes cannot be empty or contain empty entries");
    }
    if (pointerAddress == nullptr.address) {
      throw Exception("pointerAddress can not point to null");
    }
  }

  /// The total amount in atomic units being transferred across all transactions.
  /// Does not include the [fee].
  final BigInt amount;

  /// The total fee in atomic units across all transactions.
  final BigInt fee;

  /// The transaction IDs (hashes), one per transaction.
  final List<String> txids;

  /// The raw transaction hex strings, in the same order as [txids].
  final List<String> hexes;

  /// The address of the pointer to the underlying pending transaction object.
  final int pointerAddress;
}
