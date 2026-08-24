import 'dart:io';

const manifestFormat = 'stack-wallet-precompiled-sha256-v1';

class ManifestComparison {
  const ManifestComparison({
    required this.changed,
    required this.missing,
    required this.unexpected,
  });

  final List<String> changed;
  final List<String> missing;
  final List<String> unexpected;

  bool get matches => changed.isEmpty && missing.isEmpty && unexpected.isEmpty;
}

Future<Map<String, String>> hashArtifactTree(Directory input) async {
  if (!input.existsSync()) {
    throw StateError('Artifact directory does not exist: ${input.path}');
  }

  final files = <File>[];
  await for (final entity in input.list(recursive: true, followLinks: false)) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      files.add(File(entity.path));
    }
  }

  if (files.isEmpty) {
    throw StateError('Artifact directory contains no files: ${input.path}');
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  final hashes = <String, String>{};
  for (final file in files) {
    final relativePath = _relativePath(input, file);
    if (relativePath.contains('\n') || relativePath.contains('\r')) {
      throw StateError('Artifact path contains a newline: $relativePath');
    }
    hashes[relativePath] = await sha256File(file);
  }
  return hashes;
}

Future<String> sha256File(File file) async {
  final candidates = <(String, List<String>)>[
    ('sha256sum', [file.path]),
    ('shasum', ['-a', '256', file.path]),
    ('certutil', ['-hashfile', file.path, 'SHA256']),
  ];

  Object? lastError;
  for (final candidate in candidates) {
    try {
      final result = await Process.run(candidate.$1, candidate.$2);
      if (result.exitCode != 0) {
        continue;
      }
      final output = '${result.stdout}\n${result.stderr}';
      final match = RegExp(
        r'(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])',
      ).firstMatch(output);
      if (match != null) {
        return match.group(0)!.toLowerCase();
      }
    } on ProcessException catch (error) {
      lastError = error;
    }
  }

  throw StateError(
    'No working SHA-256 tool found for ${file.path}. '
    'Tried sha256sum, shasum, and certutil. Last error: $lastError',
  );
}

String renderManifest(String platform, Map<String, String> hashes) {
  final sortedPaths = hashes.keys.toList()..sort();
  final lines = <String>[
    '# $manifestFormat',
    '# platform: $platform',
    for (final path in sortedPaths) '${hashes[path]}  $path',
  ];
  return '${lines.join('\n')}\n';
}

Map<String, String> parseManifest(String contents) {
  final lines = contents.split('\n');
  if (lines.isEmpty || lines.first.trim() != '# $manifestFormat') {
    throw FormatException('Unsupported or missing manifest format header');
  }

  final hashes = <String, String>{};
  final entryPattern = RegExp(r'^([0-9a-fA-F]{64})  (.+)$');
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final match = entryPattern.firstMatch(line);
    if (match == null) {
      throw FormatException('Invalid manifest line: $line');
    }
    final path = match.group(2)!;
    if (hashes.containsKey(path)) {
      throw FormatException('Duplicate manifest path: $path');
    }
    hashes[path] = match.group(1)!.toLowerCase();
  }

  if (hashes.isEmpty) {
    throw FormatException('Manifest contains no artifact hashes');
  }
  return hashes;
}

ManifestComparison compareManifests(
  Map<String, String> expected,
  Map<String, String> actual,
) {
  final expectedPaths = expected.keys.toSet();
  final actualPaths = actual.keys.toSet();
  final missing = expectedPaths.difference(actualPaths).toList()..sort();
  final unexpected = actualPaths.difference(expectedPaths).toList()..sort();
  final changed = expectedPaths
      .intersection(actualPaths)
      .where((path) => expected[path] != actual[path])
      .toList()
    ..sort();

  return ManifestComparison(
    changed: changed,
    missing: missing,
    unexpected: unexpected,
  );
}

String formatComparison(ManifestComparison comparison) {
  if (comparison.matches) {
    return 'All precompiled artifact hashes match the recorded baseline.';
  }

  final lines = <String>['Precompiled artifact verification failed:'];
  for (final path in comparison.changed) {
    lines.add('  changed: $path');
  }
  for (final path in comparison.missing) {
    lines.add('  missing: $path');
  }
  for (final path in comparison.unexpected) {
    lines.add('  unexpected: $path');
  }
  return lines.join('\n');
}

Future<String> collectProvenance({
  required String projectDirectory,
  required String platform,
}) async {
  final sections = <String>[
    'format=$manifestFormat',
    'platform=$platform',
    'dart_os=${Platform.operatingSystem}',
    'dart_os_version=${Platform.operatingSystemVersion}',
    for (final key in [
      'SOURCE_DATE_EPOCH',
      'ZERO_AR_DATE',
      'CC',
      'CXX',
      'SDKROOT',
      'MACOSX_DEPLOYMENT_TARGET',
    ])
      if (Platform.environment[key] case final value?) '$key=$value',
  ];

  final commands = <(String, String, List<String>)>[
    ('source commit', 'git', ['-C', projectDirectory, 'rev-parse', 'HEAD']),
    ('source status', 'git', ['-C', projectDirectory, 'status', '--short']),
    (
      'monero_c commit',
      'git',
      [
        '-C',
        '$projectDirectory${Platform.pathSeparator}build'
            '${Platform.pathSeparator}monero_c',
        'rev-parse',
        'HEAD',
      ],
    ),
    (
      'monero_c status',
      'git',
      [
        '-C',
        '$projectDirectory${Platform.pathSeparator}build'
            '${Platform.pathSeparator}monero_c',
        'status',
        '--short',
      ],
    ),
    (
      'monero_c submodules',
      'git',
      [
        '-C',
        '$projectDirectory${Platform.pathSeparator}build'
            '${Platform.pathSeparator}monero_c',
        'submodule',
        'status',
        '--recursive',
      ],
    ),
    ('uname', 'uname', ['-a']),
    ('macOS', 'sw_vers', []),
    ('Xcode', 'xcodebuild', ['-version']),
    ('Dart', Platform.resolvedExecutable, ['--version']),
    ('Flutter', 'flutter', ['--version']),
    ('Melos', Platform.resolvedExecutable, ['run', 'melos', '--version']),
    (
      'Dart dependencies',
      Platform.resolvedExecutable,
      ['pub', 'deps', '--style=compact'],
    ),
    ('CMake', 'cmake', ['--version']),
    ('Clang', 'clang', ['--version']),
    ('GCC', 'gcc', ['--version']),
    ('MinGW GCC', 'x86_64-w64-mingw32-gcc', ['--version']),
    ('Homebrew packages', 'brew', ['list', '--versions']),
    (
      'Debian packages',
      'dpkg-query',
      [
        '-W',
        '-f=\${Package}=\${Version}\\n',
        'autoconf',
        'automake',
        'build-essential',
        'ccache',
        'cmake',
        'g++',
        'g++-mingw-w64-x86-64',
        'gcc',
        'gcc-mingw-w64-x86-64',
        'libtool',
        'make',
        'pkg-config',
      ],
    ),
  ];

  for (final command in commands) {
    try {
      final result = await Process.run(command.$2, command.$3);
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      sections.add('');
      sections.add('[${command.$1}] exit=${result.exitCode}');
      if (stdout.isNotEmpty) {
        sections.add(stdout);
      }
      if (stderr.isNotEmpty) {
        sections.add(stderr);
      }
    } on ProcessException catch (error) {
      sections.add('');
      sections.add('[${command.$1}] unavailable: $error');
    }
  }

  return '${sections.join('\n')}\n';
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path;
  final filePath = file.absolute.path;
  final prefix = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  if (!filePath.startsWith(prefix)) {
    throw StateError('${file.path} is outside ${root.path}');
  }
  return filePath
      .substring(prefix.length)
      .split(Platform.pathSeparator)
      .join('/');
}
