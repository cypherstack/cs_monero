/// Represents a recipient in a transaction, including their address and the
/// amount to be transferred.
class Recipient {
  /// Creates a [Recipient] with the given [address] and [amount].
  ///
  /// Throws an assertion error if [address] is empty or [amount] is negative.
  Recipient({
    required this.address,
    required this.amount,
  }) : assert(address.isNotEmpty && !amount.isNegative);

  /// The address of the recipient where the funds will be sent.
  final String address;

  /// The amount of funds to be transferred to the recipient,
  /// represented in atomic units.
  final BigInt amount;
}
