import 'package:cs_monero/cs_monero.dart';
import 'package:cs_monero/src/enums/min_confirms.dart';
import 'package:test/test.dart';

void main() {
  group("$MinConfirms", () {
    test("contains two values", () {
      expect(MinConfirms.values.length, 2);
    });

    test("each confirmation type has the correct associated value", () {
      expect(MinConfirms.monero.value, 10);
      expect(MinConfirms.wownero.value, 15);
    });

    test("values are accessible by index", () {
      expect(MinConfirms.values[0], MinConfirms.monero);
      expect(MinConfirms.values[1], MinConfirms.wownero);
    });

    test("toString returns correct value", () {
      expect(MinConfirms.monero.toString(), "MinConfirms.monero");
      expect(MinConfirms.wownero.toString(), "MinConfirms.wownero");
    });
  });

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

  group("$MoneroSeedType", () {
    test("contains two values", () {
      expect(MoneroSeedType.values.length, 2);
    });

    test("values are correct", () {
      expect(MoneroSeedType.sixteen.index, 0);
      expect(MoneroSeedType.twentyFive.index, 1);
    });

    test("values are accessible by index", () {
      expect(MoneroSeedType.values[0], MoneroSeedType.sixteen);
      expect(MoneroSeedType.values[1], MoneroSeedType.twentyFive);
    });

    test("toString returns correct value", () {
      expect(MoneroSeedType.sixteen.toString(), "MoneroSeedType.sixteen");
      expect(MoneroSeedType.twentyFive.toString(), "MoneroSeedType.twentyFive");
    });
  });

  group("$WowneroSeedType", () {
    test("contains three values", () {
      expect(WowneroSeedType.values.length, 3);
    });

    test("values are correct", () {
      expect(WowneroSeedType.fourteen.index, 0);
      expect(WowneroSeedType.sixteen.index, 1);
      expect(WowneroSeedType.twentyFive.index, 2);
    });

    test("values are accessible by index", () {
      expect(WowneroSeedType.values[0], WowneroSeedType.fourteen);
      expect(WowneroSeedType.values[1], WowneroSeedType.sixteen);
      expect(WowneroSeedType.values[2], WowneroSeedType.twentyFive);
    });

    test("toString returns correct value", () {
      expect(WowneroSeedType.fourteen.toString(), "WowneroSeedType.fourteen");
      expect(WowneroSeedType.sixteen.toString(), "WowneroSeedType.sixteen");
      expect(
        WowneroSeedType.twentyFive.toString(),
        "WowneroSeedType.twentyFive",
      );
    });
  });
}
