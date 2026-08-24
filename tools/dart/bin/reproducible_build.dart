import 'dart:io';

import '../env.dart';

const supportedPlatforms = {'android', 'ios', 'linux', 'macos', 'windows'};
const supportedActions = {'record', 'verify'};

Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      !supportedActions.contains(args[0]) ||
      !supportedPlatforms.contains(args[1])) {
    stderr.writeln(
      'Usage: dart tools/dart/bin/reproducible_build.dart '
      '<record|verify> <android|ios|linux|macos|windows>',
    );
    exitCode = 64;
    return;
  }

  final action = args[0];
  final platform = args[1];
  await _deleteBuildDirectory(envBuildDir, 'build');
  await _deleteBuildDirectory(envOutputsDir, 'built_outputs');

  final environment = <String, String>{
    ...Platform.environment,
    'SOURCE_DATE_EPOCH': '1',
    'ZERO_AR_DATE': '1',
    'TZ': 'UTC',
    'LC_ALL': 'C',
    'LANG': 'C',
  };

  await _runMelos('prepareMoneroC', environment);
  await _runMelos('build:$platform', environment);
  await _runMelos('copyLibs', environment);

  final binDirectory = '$envToolsDir${Platform.pathSeparator}dart'
      '${Platform.pathSeparator}bin';
  await _runDart(
    '$binDirectory${Platform.pathSeparator}reproducible_precompiled.dart',
    [action, platform],
    environment,
  );
}

Future<void> _runMelos(
  String script,
  Map<String, String> environment,
) async {
  stdout.writeln('Running existing Melos script: $script');
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'melos', 'run', script],
    workingDirectory: envProjectDir,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    exit(result);
  }
}

Future<void> _deleteBuildDirectory(String path, String expectedName) async {
  final project = Directory(envProjectDir).absolute.path;
  final target = Directory(path).absolute;
  final expected = '$project${Platform.pathSeparator}$expectedName';
  if (target.path != expected) {
    throw StateError('Refusing to delete unexpected path: ${target.path}');
  }
  if (target.existsSync()) {
    stdout.writeln('Removing ${target.path} for a clean build...');
    await target.delete(recursive: true);
  }
}

Future<void> _runDart(
  String script,
  List<String> arguments,
  Map<String, String> environment,
) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    [script, ...arguments],
    workingDirectory: envProjectDir,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    exit(result);
  }
}
