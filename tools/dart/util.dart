import 'dart:io';

import 'env.dart';

/// run a system process
Future<void> runAsync(
  String command,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final exitCode = await _run(
    command,
    arguments,
    environment: environment,
  );

  if (exitCode != 0) {
    l("$command exited with code $exitCode");
    exit(exitCode);
  }
}

/// Run a network-sensitive process again after transient failures.
Future<void> runAsyncWithRetries(
  String command,
  List<String> arguments, {
  Map<String, String>? environment,
  int attempts = 3,
}) async {
  if (attempts < 1) {
    throw ArgumentError.value(attempts, 'attempts', 'Must be positive');
  }

  for (var attempt = 1; attempt <= attempts; attempt++) {
    final exitCode = await _run(
      command,
      arguments,
      environment: environment,
    );
    if (exitCode == 0) {
      return;
    }
    if (attempt == attempts) {
      l("$command failed after $attempts attempts");
      exit(exitCode);
    }
    l(
      "$command attempt $attempt of $attempts exited with code $exitCode; "
      "retrying...",
    );
    await Future<void>.delayed(Duration(seconds: attempt * 5));
  }
}

Future<int> _run(
  String command,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    command,
    arguments,
    environment: environment,
  );

  process.stdout.transform(SystemEncoding().decoder).listen((data) {
    l('[stdout]: $data');
  });

  process.stderr.transform(SystemEncoding().decoder).listen((data) {
    l('[stderr]: $data');
  });

  // Wait for the process to complete
  return process.exitCode;
}

/// create some build dirs if they don't already exist
Future<void> createBuildDirs() async {
  await Future.wait([
    Directory(envBuildDir).create(recursive: true),
    Directory(envOutputsDir).create(recursive: true),
  ]);
}

/// extremely basic logger
void l(Object? o) {
  // ignore: avoid_print
  print(o);
}
