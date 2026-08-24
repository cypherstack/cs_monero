import 'dart:io';

import '../env.dart';
import '../reproducible_precompiled.dart';

const supportedPlatforms = {'android', 'ios', 'linux', 'macos', 'windows'};
const supportedActions = {'print', 'record', 'verify'};

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _usage();
    return;
  }
  if (args.length < 2 ||
      !supportedActions.contains(args[0]) ||
      !supportedPlatforms.contains(args[1])) {
    _usage();
    exitCode = 64;
    return;
  }

  final action = args[0];
  final platform = args[1];
  String? inputOverride;
  String? manifestOverride;
  var force = false;

  for (var index = 2; index < args.length; index++) {
    switch (args[index]) {
      case '--force':
        force = true;
        break;
      case '--input':
        if (++index >= args.length) {
          throw ArgumentError('Missing value after --input');
        }
        inputOverride = args[index];
        break;
      case '--manifest':
        if (++index >= args.length) {
          throw ArgumentError('Missing value after --manifest');
        }
        manifestOverride = args[index];
        break;
      default:
        throw ArgumentError('Unknown argument: ${args[index]}');
    }
  }

  final input = Directory(
    inputOverride ?? '$envOutputsDir${Platform.pathSeparator}$platform',
  );
  final manifest = File(
    manifestOverride ??
        '$envProjectDir${Platform.pathSeparator}reproducibility'
            '${Platform.pathSeparator}manifests'
            '${Platform.pathSeparator}$platform.sha256',
  );
  final actual = await hashArtifactTree(input);
  final rendered = renderManifest(platform, actual);

  switch (action) {
    case 'print':
      stdout.write(rendered);
      return;
    case 'record':
      if (manifest.existsSync() && !force) {
        stderr.writeln(
          'Refusing to overwrite ${manifest.path}. '
          'Use verify, or pass --force after reviewing why the baseline changed.',
        );
        exitCode = 73;
        return;
      }
      manifest.parent.createSync(recursive: true);
      manifest.writeAsStringSync(rendered);
      final provenance = File(
        '${manifest.parent.path}${Platform.pathSeparator}'
        '$platform.provenance.txt',
      );
      provenance.writeAsStringSync(
        await collectProvenance(
          projectDirectory: envProjectDir,
          platform: platform,
        ),
      );
      stdout.writeln('Recorded ${actual.length} artifact hash(es):');
      stdout.writeln('  ${manifest.path}');
      stdout.writeln('  ${provenance.path}');
      return;
    case 'verify':
      if (!manifest.existsSync()) {
        stderr.writeln(
          'No baseline exists at ${manifest.path}. '
          'Run the matching repro:record:$platform command on the first host.',
        );
        exitCode = 66;
        return;
      }
      final expected = parseManifest(manifest.readAsStringSync());
      final comparison = compareManifests(expected, actual);
      stdout.writeln(formatComparison(comparison));

      final resultsDirectory = Directory(
        '$envProjectDir${Platform.pathSeparator}reproducibility'
        '${Platform.pathSeparator}results',
      )..createSync(recursive: true);
      File(
        '${resultsDirectory.path}${Platform.pathSeparator}'
        '$platform.current.sha256',
      ).writeAsStringSync(rendered);
      File(
        '${resultsDirectory.path}${Platform.pathSeparator}'
        '$platform.current.provenance.txt',
      ).writeAsStringSync(
        await collectProvenance(
          projectDirectory: envProjectDir,
          platform: platform,
        ),
      );

      if (!comparison.matches) {
        exitCode = 1;
      }
      return;
  }
}

void _usage() {
  stdout.writeln(
    'Usage: dart tools/dart/bin/reproducible_precompiled.dart '
    '<print|record|verify> <android|ios|linux|macos|windows> '
    '[--input DIR] [--manifest FILE] [--force]',
  );
}
