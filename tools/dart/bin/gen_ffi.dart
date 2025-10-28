import 'dart:io';

import '../env.dart';
import '../util.dart';

void main() async {
  final moneroCDir = Directory(envMoneroCDir);
  if (!moneroCDir.existsSync()) {
    throw Exception("Missing monero_c!: Expected $envMoneroCDir");
  } else {
    final thisDir = Directory.current;

    Directory.current = moneroCDir;
    final result = Process.runSync("git", ["rev-parse", "HEAD"]);
    if (result.exitCode != 0) {
      l(result.stderr);
      exit(result.exitCode);
    }
    if (result.stdout is! String) {
      throw Exception(
        "Expected result to be of type String but got \"${result.stdout}\" instead",
      );
    }
    final moneroCHash = (result.stdout as String).trim();

    if (moneroCHash != kMoneroCHash) {
      throw Exception(
        "Current monero_c hash does not match expected commit!",
      );
    }

    for (final coin in ["monero"]) {
      await runAsync(
        "dart",
        [
          "pub",
          "run",
          "ffigen",
          "--config",
          "$envToolsDir"
              "${Platform.pathSeparator}ffi_config"
              "${Platform.pathSeparator}$coin.yaml",
        ],
      );
    }

    Directory.current = thisDir;

    l("FFI bindings generation completed");
  }
}
