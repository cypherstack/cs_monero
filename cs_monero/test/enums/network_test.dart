import 'package:cs_monero/src/enums/network.dart';
import 'package:test/test.dart';

void main() {
  group("$Network", () {
    test("contains three values", () {
      expect(Network.values.length, 3);
    });

    test("each item has the correct associated value", () {
      expect(Network.mainnet.value, 0);
      expect(Network.testnet.value, 1);
      expect(Network.stagenet.value, 2);
    });
  });
}
