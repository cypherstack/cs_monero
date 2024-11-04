import "package:cs_monero/cs_monero.dart";
import "package:test/test.dart";

void main() {
  group("Address", () {
    test("should create an Address instance with correct properties", () {
      final address = Address(
        value: "SomeProbablyValidAddressString...",
        account: 0,
        index: 1,
      );

      expect(address.value, "SomeProbablyValidAddressString...");
      expect(address.account, 0);
      expect(address.index, 1);
    });

    test("toString returns the correct string representation", () {
      final address = Address(
        value: "SomeProbablyValidAddressString...",
        account: 0,
        index: 1,
      );

      expect(
        address.toString(),
        "Address { value: SomeProbablyValidAddressString..., account: 0, index: 1 }",
      );
    });

    test("throws AssertionError if account is negative", () {
      expect(
        () => Address(
          value: "SomeProbablyValidAddressString...",
          account: -1,
          index: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test("throws AssertionError if index is negative", () {
      expect(
        () => Address(
          value: "SomeProbablyValidAddressString...",
          account: 0,
          index: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
        "different Address instances with the same values are equal in content",
        () {
      final address1 = Address(
        value: "SomeProbablyValidAddressString...",
        account: 0,
        index: 1,
      );

      final address2 = Address(
        value: "SomeProbablyValidAddressString...",
        account: 0,
        index: 1,
      );

      expect(address1.toString(), address2.toString());
    });

    test("Address instances with different values are not equal in content",
        () {
      final address1 = Address(
        value: "SomeProbablyValidAddressString...",
        account: 0,
        index: 1,
      );

      final address2 = Address(
        value: "SomeProbablyValidAddressString...",
        account: 1,
        index: 2,
      );

      expect(address1.toString() == address2.toString(), false);
    });
  });
}
