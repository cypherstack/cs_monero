import 'dart:ffi';

import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group("$PendingTransaction", () {
    test("should correctly initialize all properties", () {
      final BigInt amount = BigInt.from(1000000);
      final BigInt fee = BigInt.from(10000);
      final List<String> txids = ["abc123"];
      final List<String> hexes = ["0102030405060708090a0b0c0d0e0f10"];
      final int pointerAddress = 123456; // Use a valid pointer address

      final pendingTransaction = PendingTransaction(
        amount: amount,
        fee: fee,
        txids: txids,
        hexes: hexes,
        pointerAddress: pointerAddress,
      );

      expect(pendingTransaction.amount, amount);
      expect(pendingTransaction.fee, fee);
      expect(pendingTransaction.txids, txids);
      expect(pendingTransaction.hexes, hexes);
      expect(pendingTransaction.pointerAddress, pointerAddress);
    });

    test("should preserve each transaction in a split payment", () {
      final pendingTransaction = PendingTransaction(
        amount: BigInt.from(1000000),
        fee: BigInt.from(10000),
        txids: ["abc123", "def456"],
        hexes: ["010203", "0405060708"],
        pointerAddress: 123456,
      );

      expect(pendingTransaction.txids, ["abc123", "def456"]);
      expect(pendingTransaction.hexes, ["010203", "0405060708"]);
    });

    test("should throw an error for negative amount", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(-1000000), // negative amount
          fee: BigInt.from(10000),
          txids: ["abc123"],
          hexes: ["0102030405060708090a0b0c0d0e0f10"],
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("Invalid amount"),
          ),
        ),
      );
    });

    test("should throw an error for negative fee", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(-10000), // negative fee
          txids: ["abc123"],
          hexes: ["0102030405060708090a0b0c0d0e0f10"],
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("Invalid fee"),
          ),
        ),
      );
    });

    test("should throw an error for empty txids", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txids: [],
          hexes: ["0102030405060708090a0b0c0d0e0f10"],
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("txids cannot be empty"),
          ),
        ),
      );
    });

    test("should throw an error for empty hexes", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txids: ["abc123"],
          hexes: [],
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("hexes cannot be empty"),
          ),
        ),
      );
    });

    test("should throw an error for an empty txid in a split payment", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txids: ["abc123", ""],
          hexes: ["010203", "040506"],
          pointerAddress: 123456,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test("should throw an error for empty hex in a split payment", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txids: ["abc123", "def456"],
          hexes: ["010203", ""],
          pointerAddress: 123456,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test("should throw an error for null pointerAddress", () {
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txids: ["abc123"],
          hexes: ["0102030405060708090a0b0c0d0e0f10"],
          pointerAddress: nullptr.address, // null pointerAddress
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("pointerAddress can not point to null"),
          ),
        ),
      );
    });
  });
}
