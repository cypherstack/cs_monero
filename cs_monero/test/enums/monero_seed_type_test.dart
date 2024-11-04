import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
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
}
