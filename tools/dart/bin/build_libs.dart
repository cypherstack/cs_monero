import 'dart:io';
import 'dart:math';

import '../create_framework.dart';
import '../env.dart';
import '../util.dart';

void main(List<String> args) async {
  const platforms = ["android", "ios", "macos", "linux", "windows"];
  const coins = ["monero"];

  if (args.length != 1) {
    throw ArgumentError(
      "Missing platform argument. Expected one of $platforms",
    );
  }
  final platform = args.first;
  if (!platforms.contains(args.first)) {
    throw ArgumentError(args.first);
  }

  final moneroCDir = Directory(envMoneroCDir);
  if (!moneroCDir.existsSync()) {
    l("Did not find monero_c. Calling prepare_monero_c.dart...");
    await runAsync(
      "dart",
      [
        "$envToolsDir"
            "${Platform.pathSeparator}dart"
            "${Platform.pathSeparator}bin"
            "${Platform.pathSeparator}prepare_monero_c.dart",
      ],
    );
  }

  final thisDir = Directory.current;
  Directory.current = moneroCDir;

  final nProc = _getNProc(platform);
  final triples = _getTriples(platform);
  final version = _moneroCVersion();

  for (final triple in triples) {
    for (final coin in coins) {
      await runAsync("./build_single.sh", [coin, triple, "-j$nProc"]);
    }

    // clean unneeded files between triples
    if (triple != triples.last) {
      await sbsCleanup();
    }
  }

  Directory.current = thisDir;

  final builtOutputsDirPath = "$envOutputsDir"
      "${Platform.pathSeparator}$platform";

  // copy to built_outputs as required
  switch (platform) {
    case "android":
      final triples = _getTriples("android");
      final basePath = "$builtOutputsDirPath"
          "${Platform.pathSeparator}jniLibs";

      for (final triple in triples) {
        final mapping = _mapAndroid(triple);
        final dir = Directory(
          "$basePath"
          "${Platform.pathSeparator}$mapping",
        )..createSync(
            recursive: true,
          );
        for (final coin in coins) {
          await runAsync(
            "cp",
            [
              _releasedLibPath(version, triple, coin, "so"),
              "${dir.path}"
                  "${Platform.pathSeparator}lib${coin}_libwallet2_api_c.so",
            ],
          );
        }
      }

      break;

    case "ios":
    case "macos":
      final dir = Directory(
        "$builtOutputsDirPath"
        "${Platform.pathSeparator}Frameworks",
      )..createSync(
          recursive: true,
        );

      // ios and macos only have 1 triple currently
      final triple = _getTriples(platform).first;
      final xmrDylib = _releasedLibPath(version, triple, "monero", "dylib");

      await createFramework(
        frameworkName: "MoneroWallet",
        pathToDylib: xmrDylib,
        targetDirFrameworks: dir.path,
        layout: platform == "ios"
            ? FrameworkLayout.flat
            : FrameworkLayout.versioned,
      );

      break;

    case "linux":
      final dir = Directory(builtOutputsDirPath)
        ..createSync(
          recursive: true,
        );
      for (final coin in coins) {
        await runAsync(
          "cp",
          [
            _releasedLibPath(version, triples.first, coin, "so"),
            "${dir.path}"
                "${Platform.pathSeparator}${coin}_libwallet2_api_c.so",
          ],
        );
      }
      break;

    case "windows":
      final dir = Directory(builtOutputsDirPath)
        ..createSync(
          recursive: true,
        );
      await runAsync(
        "cp",
        [
          _releasedLibPath(version, triples.first, "monero", "dll"),
          "${dir.path}"
              "${Platform.pathSeparator}monero_libwallet2_api_c.dll",
        ],
      );

      for (final name in _windowsDlls) {
        final dll = _windowsDllPath(name);
        if (!File(dll).existsSync()) {
          throw Exception(
            "$dll is missing. The windows package ships it as a commited"
            " binary; restore it from git before building.",
          );
        }
        await runAsync(
          "cp",
          [
            dll,
            "${dir.path}"
                "${Platform.pathSeparator}$name",
          ],
        );
      }
      break;

    default:
      throw Exception("Not sure how you got this far tbh");
  }

  await sbsCleanup();
}

const _windowsDlls = ["libssp-0.dll", "libwinpthread-1.dll"];

String _windowsDllPath(String name) => "$envProjectDir"
    "${Platform.pathSeparator}cs_monero_flutter_libs_windows"
    "${Platform.pathSeparator}windows"
    "${Platform.pathSeparator}lib"
    "${Platform.pathSeparator}$name";

/// The tag build_single.sh names its release directory after.
String _moneroCVersion() {
  final result = Process.runSync(
    "git",
    ["describe", "--tags"],
    workingDirectory: envMoneroCDir,
  );
  if (result.exitCode != 0) {
    throw Exception("code=${result.exitCode}, stderr=${result.stderr}");
  }
  return result.stdout.toString().trim();
}

/// `release/<version>/<triple>/lib<coin>_wallet2_api_c.<ext>`
String _releasedLibPath(
  String version,
  String triple,
  String coin,
  String ext,
) =>
    "$envMoneroCDir"
    "${Platform.pathSeparator}release"
    "${Platform.pathSeparator}$version"
    "${Platform.pathSeparator}$triple"
    "${Platform.pathSeparator}lib${coin}_wallet2_api_c.$ext";

String _mapAndroid(String triple) {
  switch (triple) {
    case "x86_64-linux-android":
      return "x86_64";
    case "aarch64-linux-android":
      return "arm64-v8a";
    case "armv7a-linux-androideabi":
      return "armeabi-v7a";
    default:
      throw ArgumentError("Unsupported triple: $triple");
  }
}

List<String> _getTriples(String platform) {
  switch (platform) {
    case "android":
      return [
        "x86_64-linux-android",
        "armv7a-linux-androideabi",
        "aarch64-linux-android",
      ];

    case "ios":
      return ["aarch64-apple-ios"];

    case "macos":
      return ["aarch64-apple-darwin"];

    case "linux":
      return ["x86_64-linux-gnu"];

    case "windows":
      return ["x86_64-w64-mingw32"];

    default:
      throw ArgumentError(platform, "platform");
  }
}

String _getNProc(String platform) {
  final result = Platform.isMacOS
      ? Process.runSync("sysctl", ["-n", "hw.physicalcpu"])
      : Process.runSync("nproc", []);
  if (result.exitCode != 0) {
    throw Exception("code=${result.exitCode}, stderr=${result.stderr}");
  }
  final nProc = int.parse(result.stdout.toString());

  switch (platform) {
    case "android":
    case "linux":
      return max(1, (nProc * 0.8).floor()).toString();

    case "ios":
    case "macos":
    case "windows":
      return nProc.toString();

    default:
      throw ArgumentError(platform, "platform");
  }
}
