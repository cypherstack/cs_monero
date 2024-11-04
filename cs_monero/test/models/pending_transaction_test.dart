import 'dart:ffi';

import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group("$PendingTransaction", () {
    test("should correctly initialize all properties", () {
      // Arrange
      final BigInt amount = BigInt.from(1000000);
      final BigInt fee = BigInt.from(10000);
      final String txid = "abc123";
      final String hex = "0102030405060708090a0b0c0d0e0f10";
      final int pointerAddress = 123456; // Use a valid pointer address

      // Act
      final pendingTransaction = PendingTransaction(
        amount: amount,
        fee: fee,
        txid: txid,
        hex: hex,
        pointerAddress: pointerAddress,
      );

      // Assert
      expect(pendingTransaction.amount, amount);
      expect(pendingTransaction.fee, fee);
      expect(pendingTransaction.txid, txid);
      expect(pendingTransaction.hex, hex);
      expect(pendingTransaction.pointerAddress, pointerAddress);
    });

    test("should throw an error for negative amount", () {
      // Arrange & Act & Assert
      expect(
        () => PendingTransaction(
          amount: BigInt.from(-1000000), // negative amount
          fee: BigInt.from(10000),
          txid: "abc123",
          hex: "0102030405060708090a0b0c0d0e0f10",
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
      // Arrange & Act & Assert
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(-10000), // negative fee
          txid: "abc123",
          hex: "0102030405060708090a0b0c0d0e0f10",
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

    test("should throw an error for empty txid", () {
      // Arrange & Act & Assert
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txid: "", // empty txid
          hex: "0102030405060708090a0b0c0d0e0f10",
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("txid cannot be empty"),
          ),
        ),
      );
    });

    test("should throw an error for empty hex", () {
      // Arrange & Act & Assert
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txid: "abc123",
          hex: "", // empty hex
          pointerAddress: 123456,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("hex cannot be empty"),
          ),
        ),
      );
    });

    test("should throw an error for null pointerAddress", () {
      // Arrange & Act & Assert
      expect(
        () => PendingTransaction(
          amount: BigInt.from(1000000),
          fee: BigInt.from(10000),
          txid: "abc123",
          hex: "0102030405060708090a0b0c0d0e0f10",
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
