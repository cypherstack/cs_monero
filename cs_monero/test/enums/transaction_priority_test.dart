import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group("$TransactionPriority", () {
    test("contains five values", () {
      expect(TransactionPriority.values.length, 5);
    });

    test("each priority has the correct associated value", () {
      expect(TransactionPriority.normal.value, 0);
      expect(TransactionPriority.low.value, 1);
      expect(TransactionPriority.medium.value, 2);
      expect(TransactionPriority.high.value, 3);
      expect(TransactionPriority.last.value, 4);
    });

    test("values are accessible by index", () {
      expect(TransactionPriority.values[0], TransactionPriority.normal);
      expect(TransactionPriority.values[1], TransactionPriority.low);
      expect(TransactionPriority.values[2], TransactionPriority.medium);
      expect(TransactionPriority.values[3], TransactionPriority.high);
      expect(TransactionPriority.values[4], TransactionPriority.last);
    });

    test("toString returns correct value", () {
      expect(
        TransactionPriority.normal.toString(),
        "TransactionPriority.normal",
      );
      expect(TransactionPriority.low.toString(), "TransactionPriority.low");
      expect(
        TransactionPriority.medium.toString(),
        "TransactionPriority.medium",
      );
      expect(TransactionPriority.high.toString(), "TransactionPriority.high");
      expect(TransactionPriority.last.toString(), "TransactionPriority.last");
    });
  });
}
