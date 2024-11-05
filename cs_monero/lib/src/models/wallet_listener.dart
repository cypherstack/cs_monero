/// A listener class for wallet-related events during synchronization/continuous
/// polling.
class WalletListener {
  WalletListener({
    this.onSyncingUpdate,
    this.onNewBlock,
    this.onBalancesChanged,
    this.onError,
  });

  /// Called when the wallet sync progress is updated.
  ///
  /// Parameters:
  /// - [syncHeight]: The current syncing height of the wallet.
  /// - [nodeHeight]: The height of the blockchain on the connected node.
  /// - [message]: An optional message that may provide additional context.
  final void Function({
    required int syncHeight,
    required int nodeHeight,
    String? message,
  })? onSyncingUpdate;

  /// Called when the daemon’s chain height changes, indicating new blocks.
  ///
  /// Parameters:
  /// - [height]: The new height of the blockchain.
  final void Function(
    int height,
  )? onNewBlock;

  /// Called when the wallet balance or unlocked balance updates.
  ///
  /// Parameters:
  /// - [newBalance]: The updated total wallet balance in atomic units.
  /// - [newUnlockedBalance]: The updated unlocked balance in atomic units.
  final void Function({
    required BigInt newBalance,
    required BigInt newUnlockedBalance,
  })? onBalancesChanged;

  /// Called when an error occurs during synchronization/polling.
  ///
  /// Parameters:
  /// - [error]: The error object describing what went wrong.
  /// - [stackTrace]: The stack trace at the point where the error occurred.
  final void Function(
    Object? error,
    StackTrace? stackTrace,
  )? onError;
}
