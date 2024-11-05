import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction', () {
    test('should create a valid transaction', () {
      final transaction = Transaction(
        displayLabel: 'Transaction 1',
        description: 'Test transaction',
        fee: BigInt.from(100),
        confirmations: 10,
        blockHeight: 5,
        accountIndex: 0,
        addressIndexes: {0, 1},
        paymentId: 'payment_id_123',
        amount: BigInt.from(1000),
        isSpend: true,
        hash: 'transaction_hash',
        key: 'transaction_key',
        timeStamp: DateTime.now(),
        minConfirms: MinConfirms.monero,
      );

      expect(transaction.displayLabel, 'Transaction 1');
      expect(transaction.fee, BigInt.from(100));
      expect(transaction.confirmations, 10);
      expect(transaction.blockHeight, 5);
      expect(transaction.accountIndex, 0);
      expect(transaction.addressIndexes, {0, 1});
      expect(transaction.paymentId, 'payment_id_123');
      expect(transaction.amount, BigInt.from(1000));
      expect(transaction.isSpend, true);
      expect(transaction.hash, 'transaction_hash');
      expect(transaction.key, 'transaction_key');
      expect(transaction.minConfirms, MinConfirms.monero);
    });

    test('should throw an exception for negative fee', () {
      expect(
        () => Transaction(
          displayLabel: 'Transaction 1',
          description: 'Test transaction',
          fee: BigInt.from(-1000),
          confirmations: 10,
          blockHeight: 5,
          accountIndex: 0,
          addressIndexes: {0, 1},
          paymentId: 'payment_id_123',
          amount: BigInt.from(1000),
          isSpend: true,
          hash: 'transaction_hash',
          key: 'transaction_key',
          timeStamp: DateTime.now(),
          minConfirms: MinConfirms.monero,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("negative fee"),
          ),
        ),
      );
    });

    test('should throw an exception for negative confirmations', () {
      expect(
        () => Transaction(
          displayLabel: 'Transaction 1',
          description: 'Test transaction',
          fee: BigInt.from(100),
          confirmations: -1,
          blockHeight: 5,
          accountIndex: 0,
          addressIndexes: {0, 1},
          paymentId: 'payment_id_123',
          amount: BigInt.from(1000),
          isSpend: true,
          hash: 'transaction_hash',
          key: 'transaction_key',
          timeStamp: DateTime.now(),
          minConfirms: MinConfirms.monero,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("negative confirmations"),
          ),
        ),
      );
    });

    test('should throw an exception for negative accountIndex', () {
      expect(
        () => Transaction(
          displayLabel: 'Transaction 1',
          description: 'Test transaction',
          fee: BigInt.from(100),
          confirmations: 10,
          blockHeight: 5,
          accountIndex: -1,
          addressIndexes: {0, 1},
          paymentId: 'payment_id_123',
          amount: BigInt.from(1000),
          isSpend: true,
          hash: 'transaction_hash',
          key: 'transaction_key',
          timeStamp: DateTime.now(),
          minConfirms: MinConfirms.monero,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("negative accountIndex"),
          ),
        ),
      );
    });

    test('should throw an exception for negative amount', () {
      expect(
        () => Transaction(
          displayLabel: 'Transaction 1',
          description: 'Test transaction',
          fee: BigInt.from(100),
          confirmations: 10,
          blockHeight: 5,
          accountIndex: 0,
          addressIndexes: {0, 1},
          paymentId: 'payment_id_123',
          amount: BigInt.from(-100000),
          isSpend: true,
          hash: 'transaction_hash',
          key: 'transaction_key',
          timeStamp: DateTime.now(),
          minConfirms: MinConfirms.monero,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("negative amount"),
          ),
        ),
      );
    });

    test('should correctly determine if transaction is confirmed', () {
      final transaction = Transaction(
        displayLabel: 'Transaction 1',
        description: 'Test transaction',
        fee: BigInt.from(100),
        confirmations: 10,
        blockHeight: 5,
        accountIndex: 0,
        addressIndexes: {0, 1},
        paymentId: 'payment_id_123',
        amount: BigInt.from(1000),
        isSpend: true,
        hash: 'transaction_hash',
        key: 'transaction_key',
        timeStamp: DateTime.now(),
        minConfirms: MinConfirms.monero,
      );

      expect(transaction.isConfirmed, true);
    });

    test('should correctly determine if transaction is pending', () {
      final transaction = Transaction(
        displayLabel: 'Transaction 1',
        description: 'Test transaction',
        fee: BigInt.from(100),
        confirmations: 1,
        blockHeight: 5,
        accountIndex: 0,
        addressIndexes: {0, 1},
        paymentId: 'payment_id_123',
        amount: BigInt.from(1000),
        isSpend: true,
        hash: 'transaction_hash',
        key: 'transaction_key',
        timeStamp: DateTime.now(),
        minConfirms: MinConfirms.monero,
      );

      expect(transaction.isPending, true);
    });
  });
}
