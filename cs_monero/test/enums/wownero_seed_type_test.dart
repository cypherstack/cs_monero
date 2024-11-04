import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
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
