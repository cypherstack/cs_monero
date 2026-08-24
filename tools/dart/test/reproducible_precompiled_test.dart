import 'dart:io';

import '../reproducible_precompiled.dart';

Future<void> main() async {
  final temporary = await Directory.systemTemp.createTemp(
    'reproducible-precompiled-test.',
  );
  try {
    final nested = Directory('${temporary.path}${Platform.pathSeparator}nested')
      ..createSync();
    File(
      '${temporary.path}${Platform.pathSeparator}a.bin',
    ).writeAsStringSync('abc');
    File(
      '${nested.path}${Platform.pathSeparator}b.bin',
    ).writeAsStringSync('second');

    final hashes = await hashArtifactTree(temporary);
    _expect(hashes.keys.toList().join(',') == 'a.bin,nested/b.bin');
    _expect(
      hashes['a.bin'] ==
          'ba7816bf8f01cfea414140de5dae2223'
              'b00361a396177a9cb410ff61f20015ad',
    );

    final rendered = renderManifest('linux', hashes);
    final parsed = parseManifest(rendered);
    _expect(parsed.length == 2);
    _expect(compareManifests(parsed, hashes).matches);

    final changed = {...hashes, 'a.bin': '0' * 64};
    var comparison = compareManifests(parsed, changed);
    _expect(comparison.changed.single == 'a.bin');

    final missing = {...hashes}..remove('nested/b.bin');
    comparison = compareManifests(parsed, missing);
    _expect(comparison.missing.single == 'nested/b.bin');

    final unexpected = {...hashes, 'extra.bin': '1' * 64};
    comparison = compareManifests(parsed, unexpected);
    _expect(comparison.unexpected.single == 'extra.bin');

    stdout.writeln('reproducible_precompiled_test: OK');
  } finally {
    await temporary.delete(recursive: true);
  }
}

void _expect(bool condition) {
  if (!condition) {
    throw StateError('Expectation failed');
  }
}
