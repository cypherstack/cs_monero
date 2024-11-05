import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group("$Recipient", () {
    test("creates a valid recipient", () {
      final recipient = Recipient(
        address: "SomeProbablyValidAddressString",
        amount: BigInt.from(1000),
      );
      expect(recipient.address, "SomeProbablyValidAddressString");
      expect(recipient.amount, BigInt.from(1000));
    });

    test("throws an error for empty address", () {
      expect(
        () => Recipient(address: "", amount: BigInt.from(1000)),
        throwsA(isA<AssertionError>()),
      );
    });

    test("throws an error for negative amount", () {
      expect(
        () => Recipient(
          address: "SomeProbablyValidAddressString",
          amount: BigInt.from(-1000),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
