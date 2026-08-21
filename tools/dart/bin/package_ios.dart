import 'dart:io';

import '../create_ios_xcframework.dart';
import '../env.dart';
import '../util.dart';

/// Packaging-only counterpart of build_libs.dart for iOS: creates the
/// MoneroWallet/WowneroWallet XCFrameworks from the dylibs already present
/// in monero_c/release (device and, when available, simulator slices)
/// without rebuilding anything.
void main() async {
  final builtOutputsDirPath = "$envOutputsDir"
      "${Platform.pathSeparator}ios";

  final dir = Directory(
    "$builtOutputsDirPath"
    "${Platform.pathSeparator}Frameworks",
  )..createSync(
      recursive: true,
    );

  String dylibPath(String coin, String triple) => "$envMoneroCDir"
      "${Platform.pathSeparator}release"
      "${Platform.pathSeparator}$coin"
      "${Platform.pathSeparator}${triple}_libwallet2_api_c.dylib";

  for (final (coin, name) in [
    ("monero", "MoneroWallet"),
    ("wownero", "WowneroWallet"),
  ]) {
    final device = dylibPath(coin, "aarch64-apple-ios");
    final sim = dylibPath(coin, "aarch64-apple-iossimulator");
    if (!File(device).existsSync()) {
      l("Skipping $name: $device not found");
      continue;
    }
    await createIosFramework(
      frameworkName: name,
      pathToDylib: device,
      pathToSimulatorDylib: File(sim).existsSync() ? sim : null,
      targetDirFrameworks: dir.path,
    );
  }
}
