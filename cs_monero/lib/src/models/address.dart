/// Represents an address within a specific account and subaddress index.
///
/// In Monero (or Wownero), each account can have multiple subaddresses, and
/// each subaddress is identified by an index. This class encapsulates the
/// information necessary to identify a unique Monero (or Wownero) address.
class Address {
  /// Creates an [Address] with the given Monero (or Wownero) [value],
  /// [account] index, and [index] within the account. NOTE: No validation
  /// beyond negative [account] or [index] values occurs here!
  ///
  /// [value] is the actual Monero (or Wownero) address string.
  /// [account] is the account index in the Monero (or Wownero) wallet where
  /// this address resides.
  /// [index] is the subaddress index within the specified account.
  Address({
    required this.value,
    required this.account,
    required this.index,
  }) : assert(!account.isNegative && !index.isNegative);

  /// The actual Monero (or Wownero) address string.
  final String value;

  /// The account index in the Monero (or Wownero) wallet where this address is
  /// located.
  final int account;

  /// The subaddress index within the specified account.
  final int index;

  @override
  String toString() {
    return "Address { value: $value, account: $account, index: $index }";
  }
}
