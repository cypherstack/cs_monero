import "package:cs_monero/cs_monero.dart";
import "package:test/test.dart";

void main() {
  group("$Output", () {
    test("should create an Output instance with correct properties", () {
      final output = Output(
        address: "SomeProbablyValidAddressString...",
        hash: "SomeProbablyValidHash...",
        keyImage: "SomeProbablyValidKeyImageString...",
        value: BigInt.from(1000000000000),
        isFrozen: false,
        isUnlocked: true,
        height: 2450000,
        spentHeight: 2450100,
        vout: 1,
        spent: true,
        coinbase: false,
      );

      expect(output.address, "SomeProbablyValidAddressString...");
      expect(output.hash, "SomeProbablyValidHash...");
      expect(output.keyImage, "SomeProbablyValidKeyImageString...");
      expect(output.value, BigInt.from(1000000000000));
      expect(output.isFrozen, false);
      expect(output.isUnlocked, true);
      expect(output.height, 2450000);
      expect(output.spentHeight, 2450100);
      expect(output.vout, 1);
      expect(output.spent, true);
      expect(output.coinbase, false);
    });

    test("copyWithFrozen updates isFrozen while retaining other properties",
        () {
      final output = Output(
        address: "SomeProbablyValidAddressString...",
        hash: "SomeProbablyValidHash...",
        keyImage: "SomeProbablyValidKeyImageString...",
        value: BigInt.from(1000000000000),
        isFrozen: false,
        isUnlocked: true,
        height: 2450000,
        spentHeight: 2450100,
        vout: 1,
        spent: true,
        coinbase: false,
      );

      final updatedOutput = output.copyWithFrozen(true);

      expect(updatedOutput.isFrozen, true);
      expect(updatedOutput.address, output.address);
      expect(updatedOutput.hash, output.hash);
      expect(updatedOutput.keyImage, output.keyImage);
      expect(updatedOutput.value, output.value);
      expect(updatedOutput.isUnlocked, output.isUnlocked);
      expect(updatedOutput.height, output.height);
      expect(updatedOutput.spentHeight, output.spentHeight);
      expect(updatedOutput.vout, output.vout);
      expect(updatedOutput.spent, output.spent);
      expect(updatedOutput.coinbase, output.coinbase);
    });

    test("should throw an error if keyImage is empty", () {
      expect(
        () => Output(
          address: "SomeProbablyValidAddressString...",
          hash: "SomeProbablyValidHash...",
          keyImage: "",
          value: BigInt.from(0),
          isFrozen: false,
          isUnlocked: false,
          height: 0,
          spentHeight: null,
          vout: 0,
          spent: false,
          coinbase: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test("should throw an error if value is negative", () {
      expect(
        () => Output(
          address: "SomeProbablyValidAddressString...",
          hash: "SomeProbablyValidHash...",
          keyImage: "SomeProbablyValidKeyImageString...",
          value: BigInt.from(-1000000000000), // Negative value
          isFrozen: false,
          isUnlocked: true,
          height: 2450000,
          spentHeight: 2450100,
          vout: 1,
          spent: true,
          coinbase: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test("should throw an error if vout is negative", () {
      expect(
        () => Output(
          address: "SomeProbablyValidAddressString...",
          hash: "SomeProbablyValidHash...",
          keyImage: "SomeProbablyValidKeyImageString...",
          value: BigInt.from(1000000000000),
          isFrozen: false,
          isUnlocked: true,
          height: 2450000,
          spentHeight: 2450100,
          vout: -1, // Negative value
          spent: true,
          coinbase: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
