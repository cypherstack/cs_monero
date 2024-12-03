/// A bytes reader used for deserializing transactions from hex.
class ByteReader {
  final List<int> bytes;
  int offset = 0;

  ByteReader(this.bytes);

  int readByte() {
    if (offset >= bytes.length) {
      throw Exception('Unexpected end of bytes');
    }
    return bytes[offset++];
  }

  List<int> readBytes(int length) {
    if (offset + length > bytes.length) {
      throw Exception('Unexpected end of bytes');
    }
    final result = bytes.sublist(offset, offset + length);
    offset += length;
    return result;
  }

  int peekByte() {
    if (offset >= bytes.length) {
      throw Exception('Unexpected end of bytes');
    }
    return bytes[offset];
  }

  BigInt readVarInt() {
    int shift = 0;
    BigInt result = BigInt.zero;
    while (true) {
      final byte = readByte();
      result |= BigInt.from(byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        break;
      }
      shift += 7;
    }
    return result;
  }

  bool get isEOF => offset >= bytes.length;
}
