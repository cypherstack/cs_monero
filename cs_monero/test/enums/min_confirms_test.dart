import 'package:cs_monero/cs_monero.dart';
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
}
