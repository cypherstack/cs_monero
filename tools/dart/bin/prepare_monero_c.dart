import 'dart:io';

import '../env.dart';
import '../util.dart';

void main() async {
  await createBuildDirs();

  final moneroCDir = Directory(envMoneroCDir);
  if (moneroCDir.existsSync() && _head() == kMoneroCHash) {
    l("monero_c dir already exists");
    return;
  } else {
    if (moneroCDir.existsSync()) {
      Directory.current = moneroCDir;
      l('Syncing monero_c to $kMoneroCHash...');
      await runAsync('git', ['fetch', 'origin', kMoneroCHash]);
      await runAsync('git', ['reset', '--hard']);
    } else {
      // Change directory to BUILD_DIR
      Directory.current = envBuildDir;

      // Clone the monero_c repository
      await runAsync('git', [
        'clone',
        kMoneroCRepo,
      ]);

      // Change directory to MONERO_C_DIR
      Directory.current = moneroCDir;
    }

    // Checkout specific commit and reset
    await runAsync('git', ['checkout', kMoneroCHash]);
    await runAsync('git', ['reset', '--hard']);

    // Update the monero submodule
    await runAsync(
      'git',
      ['submodule', 'update', '--init', '--force', '--recursive', 'monero'],
    );

    // Apply patches
    await runAsync('./apply_patches.sh', ['monero']);

    // Apply AV patches to monero_c.
    final moneroAVPatchPath = '$envProjectDir/patches/fix-monero-av.patch';
    l('Applying fix-monero-av.patch to monero_c...');
    await runAsync('git', [
      'apply',
      '--whitespace=nowarn',
      moneroAVPatchPath,
    ]);
  }
}

String _head() {
  final result = Process.runSync(
    "git",
    ["rev-parse", "HEAD"],
    workingDirectory: envMoneroCDir,
  );
  if (result.exitCode != 0) {
    throw Exception("code=${result.exitCode}, stderr=${result.stderr}");
  }
  return result.stdout.toString().trim();
}
