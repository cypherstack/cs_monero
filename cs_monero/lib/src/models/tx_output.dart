import '../utils/byte_reader.dart';

abstract class TxOutputTarget {}

class TxoutToKey extends TxOutputTarget {
  final List<int> key;

  TxoutToKey({required this.key});

  factory TxoutToKey.fromReader(ByteReader reader) {
    final key = reader.readBytes(32);
    return TxoutToKey(key: key);
  }
}

/// Represents a Monero transaction output as deserialized from a hex string.
///
/// Distinct from the Output class used elsewhere in the codebase, this class
/// represents the output of a transaction, not the output of a wallet, and only
/// contains that information which can be deserialized from a transaction in
/// hex as would be returned from a node's JSON-RPC API.
class TxOutput {
  final BigInt amount;
  final TxOutputTarget target;

  TxOutput({required this.amount, required this.target});

  factory TxOutput.fromReader(ByteReader reader) {
    final amount = reader.readVarInt();

    return TxOutput(
      amount: amount,
      target: TxoutToKey.fromReader(reader),
    );
  }
}
