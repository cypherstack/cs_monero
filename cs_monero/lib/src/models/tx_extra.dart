import '../utils/byte_reader.dart';

abstract class TxExtraField {}

class TxExtraPubKey extends TxExtraField {
  final List<int> pubKey;
  TxExtraPubKey(this.pubKey);
}

class TxExtraNonce extends TxExtraField {
  final List<int> nonce;
  TxExtraNonce(this.nonce);
}

class TxExtraAdditionalPubKeys extends TxExtraField {
  final List<List<int>> pubKeys;
  TxExtraAdditionalPubKeys(this.pubKeys);
}

List<TxExtraField> parseExtraField(List<int> extra) {
  final reader = ByteReader(extra);
  final fields = <TxExtraField>[];

  while (!reader.isEOF) {
    final tag = reader.readByte();
    switch (tag) {
      case 0x00: // Padding
        // Continue reading padding bytes
        while (!reader.isEOF && reader.peekByte() == 0x00) {
          reader.readByte();
        }
        break;
      case 0x01: // tx_extra_pub_key
        final pubKey = reader.readBytes(32);
        fields.add(TxExtraPubKey(pubKey));
        break;
      case 0x02: // tx_extra_nonce
        final length = reader.readByte();
        final nonce = reader.readBytes(length);
        fields.add(TxExtraNonce(nonce));
        break;
      case 0x04: // tx_extra_additional_pub_keys
        final length = reader.readByte();
        final count = length ~/ 32;
        final pubKeys = <List<int>>[];
        for (var i = 0; i < count; i++) {
          pubKeys.add(reader.readBytes(32));
        }
        fields.add(TxExtraAdditionalPubKeys(pubKeys));
        break;
      default:
        continue;
      // throw Exception('Unknown tx extra tag $tag');
    }
  }

  return fields;
}
