import '../utils/byte_reader.dart';

/// Represents a Monero transaction input as deserialized from a hex string.
abstract class TxInput {
  TxInput();

  factory TxInput.fromReader(ByteReader reader) {
    final inputTypeVarint = reader.readVarInt().toInt();

    switch (inputTypeVarint) {
      case 0xff:
        return TxinGen.fromReader(reader);
      case 0x2:
        return TxinToKey.fromReader(reader);
      default:
        throw Exception('Unsupported input type $inputTypeVarint');
    }
  }
}

/// Represents a coinbase input in a Monero transaction.
///
/// Coinbase inputs creates new coins which have no previous outputs and are
/// otherwise identified by the block height from which they were created.
class TxinGen extends TxInput {
  final BigInt height;

  TxinGen({required this.height});

  factory TxinGen.fromReader(ByteReader reader) {
    final height = reader.readVarInt();
    return TxinGen(height: height);
  }
}

/// Represents a key-based input in a Monero transaction.
///
/// A key-based input is used to spend a previously created output. It
/// contains information necessary to prove the output ownership and spend it:
/// - [amount]: The amount being spent (in atomic units).
/// - [keyOffsets]: A list of offsets into the blockchain output indices, used
///   to construct the ring signature for anonymity.
/// - [keyImage]: A cryptographic key image which prevents double-spends.
class TxinToKey extends TxInput {
  final BigInt amount;
  final List<BigInt> keyOffsets;
  final List<int> keyImage;

  TxinToKey({
    required this.amount,
    required this.keyOffsets,
    required this.keyImage,
  });

  factory TxinToKey.fromReader(ByteReader reader) {
    final amount = reader.readVarInt();

    final keyOffsetsCount = reader.readVarInt().toInt();
    final keyOffsets = <BigInt>[];
    for (var i = 0; i < keyOffsetsCount; i++) {
      keyOffsets.add(reader.readVarInt());
    }

    final keyImage = reader.readBytes(32);

    return TxinToKey(
      amount: amount,
      keyOffsets: keyOffsets,
      keyImage: keyImage,
    );
  }
}
