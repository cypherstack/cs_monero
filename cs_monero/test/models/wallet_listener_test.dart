import 'package:cs_monero/cs_monero.dart';
import 'package:test/test.dart';

void main() {
  group('WalletListener', () {
    test('should invoke onSyncingUpdate callback with correct parameters', () {
      bool callbackInvoked = false;
      final int syncHeight = 5;
      final int nodeHeight = 10;
      final String message = "Syncing...";

      final listener = WalletListener(
        onSyncingUpdate: ({
          required int syncHeight,
          required int nodeHeight,
          String? message,
        }) {
          callbackInvoked = true;
          expect(syncHeight, 5);
          expect(nodeHeight, 10);
          expect(message, "Syncing...");
        },
      );

      listener.onSyncingUpdate!(
        syncHeight: syncHeight,
        nodeHeight: nodeHeight,
        message: message,
      );
      expect(callbackInvoked, true);
    });

    test('should invoke onNewBlock callback with correct height', () {
      bool callbackInvoked = false;
      final int height = 15;

      final listener = WalletListener(
        onNewBlock: (int height) {
          callbackInvoked = true;
          expect(height, 15);
        },
      );

      listener.onNewBlock!(height);
      expect(callbackInvoked, true);
    });

    test('should invoke onBalancesChanged callback with correct balances', () {
      bool callbackInvoked = false;
      final BigInt newBalance = BigInt.from(1000);
      final BigInt newUnlockedBalance = BigInt.from(800);

      final listener = WalletListener(
        onBalancesChanged: ({
          required BigInt newBalance,
          required BigInt newUnlockedBalance,
        }) {
          callbackInvoked = true;
          expect(newBalance, BigInt.from(1000));
          expect(newUnlockedBalance, BigInt.from(800));
        },
      );

      listener.onBalancesChanged!(
        newBalance: newBalance,
        newUnlockedBalance: newUnlockedBalance,
      );
      expect(callbackInvoked, true);
    });

    test('should invoke onError callback with correct parameters', () {
      bool callbackInvoked = false;
      final Object error = "An error occurred";
      final StackTrace stackTrace = StackTrace.current;

      final listener = WalletListener(
        onError: (Object? error, StackTrace? stackTrace) {
          callbackInvoked = true;
          expect(error, "An error occurred");
          expect(stackTrace, isNotNull);
        },
      );

      listener.onError!(error, stackTrace);
      expect(callbackInvoked, true);
    });

    test('should not throw when callbacks are null', () {
      final listener = WalletListener(); // No callbacks provided

      // These calls should not throw an exception
      expect(
        () => listener.onSyncingUpdate?.call(syncHeight: 0, nodeHeight: 0),
        returnsNormally,
      );
      expect(() => listener.onNewBlock?.call(0), returnsNormally);
      expect(
        () => listener.onBalancesChanged
            ?.call(newBalance: BigInt.zero, newUnlockedBalance: BigInt.zero),
        returnsNormally,
      );
      expect(() => listener.onError?.call(null, null), returnsNormally);
    });
  });
}
