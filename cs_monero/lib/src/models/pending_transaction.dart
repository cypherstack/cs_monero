import 'dart:ffi';

/// Holds the pointer address of a pending transaction in the native code as
/// well as some associated data exposed to Dart.
class PendingTransaction {
  PendingTransaction({
    required this.amount,
    required this.fee,
    required this.txid,
    required this.hex,
    required this.pointerAddress,
  }) {
    if (amount.isNegative) throw Exception("Invalid amount");
    if (fee.isNegative) throw Exception("Invalid fee");
    if (txid.isEmpty) throw Exception("txid cannot be empty");
    if (hex.isEmpty) throw Exception("hex cannot be empty");
    if (pointerAddress == nullptr.address) {
      throw Exception("pointerAddress can not point to null");
    }
  }

  /// The amount in atomic units being transferred in this transaction.
  /// Does not include the [fee].
  final BigInt amount;

  /// The transaction fee in atomic units.
  final BigInt fee;

  /// The transaction Id (or hash).
  final String txid;

  /// The raw transaction data in hexadecimal format.
  final String hex;

  /// The address of the pointer to the underlying pending transaction object.
  final int pointerAddress;
}
