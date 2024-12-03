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

class TxinGen extends TxInput {
  final BigInt height;

  TxinGen({required this.height});

  factory TxinGen.fromReader(ByteReader reader) {
    final height = reader.readVarInt();
    return TxinGen(height: height);
  }
}

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
