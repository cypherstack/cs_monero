import 'dart:io';

import '../env.dart';
import '../util.dart';

void main() async {
  await createBuildDirs();

  final moneroCDir = Directory(envMoneroCDir);
  if (moneroCDir.existsSync()) {
    // TODO: something?
    l("monero_c dir already exists");
    return;
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

    // Checkout specific commit and reset
    await runAsync('git', ['checkout', kMoneroCHash]);
    await runAsync('git', ['reset', '--hard']);

    // Update submodules
    await runAsync(
      'git',
      ['submodule', 'update', '--init', '--force', '--recursive'],
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
