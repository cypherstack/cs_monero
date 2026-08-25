import 'dart:io';

import 'env.dart';

/// run a system process
Future<void> runAsync(String command, List<String> arguments) async {
  final process = await Process.start(command, arguments);

  process.stdout.transform(SystemEncoding().decoder).listen((data) {
    l('[stdout]: $data');
  });

  process.stderr.transform(SystemEncoding().decoder).listen((data) {
    l('[stderr]: $data');
  });

  // Wait for the process to complete
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    l("$command exited with code $exitCode");
    exit(exitCode);
  }
}

/// Clean files between builds to save space.
/// Keep the shared source files, which can be reused
/// for the next build
Future<void> sbsCleanup() {
  final depends = "$envMoneroCDir"
      "${Platform.pathSeparator}contrib"
      "${Platform.pathSeparator}depends";

  return runAsync("sh", [
    "-c",
    r'cd "$1" && rm -rf simplybs/_ simplybs/_native _native ./*-*-* '
        r'simplybs/.buildlib/*_*/work simplybs/.buildlib/*_*/staging',
    "sh",
    depends,
  ]);
}

/// Locate a Mach-O toolchain binary
String mach0ToolPath(String name) {
  final fromDepends = "$envMoneroCDir"
      "${Platform.pathSeparator}contrib"
      "${Platform.pathSeparator}depends"
      "${Platform.pathSeparator}_native"
      "${Platform.pathSeparator}bin"
      "${Platform.pathSeparator}$name";

  return File(fromDepends).existsSync() ? fromDepends : name;
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
