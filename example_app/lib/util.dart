import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cs_monero/cs_monero.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<String> pathForWalletDir({
  required String name,
  required String type,
  required bool createIfNotExists,
}) async {
  Directory root = await getApplicationDocumentsDirectory();
  if (Platform.isIOS) {
    root = (await getLibraryDirectory());
  }

  final walletsDir = Directory(
    '${root.path}${Platform.pathSeparator}cs_monero_example_app${Platform.pathSeparator}wallets',
  );
  final walletDire = Directory(
    '${walletsDir.path}${Platform.pathSeparator}$type${Platform.pathSeparator}$name',
  );

  if (createIfNotExists && !walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<String> pathForWallet({
  required String name,
  required String type,
  required bool createIfNotExists,
}) async =>
    await pathForWalletDir(
      name: name,
      type: type,
      createIfNotExists: createIfNotExists,
    ).then((path) => '$path${Platform.pathSeparator}$name');

Future<List<String>> loadWalletNames(String walletType) async {
  String path = await pathForWalletDir(
    name: "dummy",
    type: walletType,
    createIfNotExists: true,
  );

  path = path.substring(0, path.lastIndexOf("${Platform.pathSeparator}dummy"));

  final dir = Directory(path);

  if (!dir.existsSync()) {
    return [];
  }

  final names = dir
      .listSync()
      .whereType<Directory>()
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .toList();
  names.remove("dummy");

  return names;
}

String formattedAmount(BigInt value, Type walletType) {
  final int decimalPlaces;
  switch (walletType) {
    case const (MoneroWallet):
      decimalPlaces = 12;
      break;

    default:
      return "error";
  }

  final amount = value.toDouble() / pow(10, decimalPlaces);

  return amount.toStringAsFixed(decimalPlaces);
}

void onSyncingUpdate({
  required int syncHeight,
  required int nodeHeight,
  String? message,
}) {
  Logging.log
      ?.i("~~~~~~~~~~ onSyncingUpdate ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  Logging.log?.i("message: $message");
  Logging.log?.i("syncingHeight: $syncHeight");
  Logging.log?.i("nodeHeight: $nodeHeight");
  Logging.log?.i("remaining: ${nodeHeight - syncHeight}");
  Logging.log?.i(
    "sync percent: ${(syncHeight / nodeHeight * 100).toStringAsFixed(2)}",
  );
  Logging.log
      ?.i("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
}

Future<T> minWaitFuture<T>(
  Future<T> future, {
  required Duration delay,
}) async {
  final results = await Future.wait(
    [
      future,
      Future<dynamic>.delayed(delay),
    ],
  );

  return results.first as T;
}

Future<T?> showLoading<T>({
  required Future<T> whileFuture,
  required BuildContext context,
  bool rootNavigator = false,
  void Function(Object error, StackTrace? st)? onError,
  Duration? delay,
}) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
          child: const Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    ),
  );
  StackTrace? st;
  Object? error;
  T? result;

  try {
    if (delay != null) {
      result = await minWaitFuture(whileFuture, delay: delay);
    } else {
      result = await whileFuture;
    }
  } catch (e, s) {
    st = s;
    error = e;
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: rootNavigator).pop();
    if (error != null) {
      onError?.call(error, st);
    }
  }

  return result;
}
