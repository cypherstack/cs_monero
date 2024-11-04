/// Represents a Monero transaction output.
///
/// In Monero (or Wownero), an output is a part of a transaction that can be
/// used as input in subsequent transactions. This class encapsulates
/// information about the specific output, including its address, hash, value,
/// and more.
class Output {
  /// Creates an [Output] with the specified Monero transaction details. NOTE:
  /// No validation of any properties (besides a negative [value] or [vout],
  /// and a non empty [keyImage]) occurs here.
  ///
  /// [address] is the receiving Monero address.
  /// [hash] is the transaction hash of the output.
  /// [keyImage] is the unique identifier of the output.
  /// [value] represents the amount of Monero in atomic units.
  /// [isFrozen] indicates if the output is currently frozen.
  /// [isUnlocked] shows if the output is available for spending.
  /// [height] is the blockchain height at which the output was created.
  /// [spentHeight] is the blockchain height at which the output was spent,
  /// or `null` if it is unspent.
  /// [vout] represents the output index within the transaction.
  /// [spent] indicates if the output has been spent.
  /// [coinbase] identifies if the output is from a coinbase transaction.
  Output({
    required this.address,
    required this.hash,
    required this.keyImage,
    required this.value,
    required this.isFrozen,
    required this.isUnlocked,
    required this.height,
    required this.spentHeight,
    required this.vout,
    required this.spent,
    required this.coinbase,
  }) : assert(!value.isNegative && !vout.isNegative && keyImage.isNotEmpty);

  /// The receiving Monero address.
  final String address;

  /// The hash of the transaction in which this output was created.
  final String hash;

  /// The value of the output, in atomic units.
  final BigInt value;

  /// A unique identifier for this output.
  /// See https://monero.stackexchange.com/questions/2883/what-is-a-key-image
  final String keyImage;

  /// Whether this output is frozen, preventing it from being spent.
  final bool isFrozen;

  /// Whether this output is unlocked and available for spending.
  final bool isUnlocked;

  /// The blockchain height where this output was created.
  final int height;

  /// The blockchain height where this output was spent, or `null` if unspent.
  final int? spentHeight;

  /// The output index within the transaction.
  final int vout;

  /// Whether this output has already been spent.
  final bool spent;

  /// Whether this output originates from a coinbase transaction.
  final bool coinbase;

  /// Returns a copy of this [Output] instance, with the [isFrozen] status
  /// updated.
  Output copyWithFrozen(bool isFrozen) => Output(
        address: address,
        hash: hash,
        keyImage: keyImage,
        value: value,
        isFrozen: isFrozen,
        isUnlocked: isUnlocked,
        height: height,
        spentHeight: spentHeight,
        vout: vout,
        spent: spent,
        coinbase: coinbase,
      );
}
