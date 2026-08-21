import 'dart:io';

import 'util.dart';

Future<void> createIosFramework({
  required String frameworkName,
  required String pathToDylib,
  String? pathToSimulatorDylib,
  required String targetDirFrameworks,
}) async {
  // Build the individual slice frameworks in a staging dir; an XCFramework
  // is then created from them (device and simulator slices are both arm64
  // and cannot be combined with lipo).
  final stagingDir = Directory(
    "$targetDirFrameworks"
    "${Platform.pathSeparator}.$frameworkName-staging",
  );
  await deleteIfExists(stagingDir.path);
  await stagingDir.create(recursive: true);

  final deviceFrameworkDir = await _createSliceFramework(
    frameworkName: frameworkName,
    pathToDylib: pathToDylib,
    parentDir: "${stagingDir.path}${Platform.pathSeparator}device",
    isSimulator: false,
  );

  String? simulatorFrameworkDir;
  if (pathToSimulatorDylib != null) {
    simulatorFrameworkDir = await _createSliceFramework(
      frameworkName: frameworkName,
      pathToDylib: pathToSimulatorDylib,
      parentDir: "${stagingDir.path}${Platform.pathSeparator}simulator",
      isSimulator: true,
    );
  }

  final xcframeworkPath = "$targetDirFrameworks"
      "${Platform.pathSeparator}$frameworkName.xcframework";
  await deleteIfExists(xcframeworkPath);

  await runAsync('xcodebuild', [
    '-create-xcframework',
    '-framework',
    deviceFrameworkDir,
    if (simulatorFrameworkDir != null) ...[
      '-framework',
      simulatorFrameworkDir,
    ],
    '-output',
    xcframeworkPath,
  ]);

  await deleteIfExists(stagingDir.path);

  l("XCFramework $frameworkName created successfully in $xcframeworkPath");
}

/// Creates a single-platform .framework containing [pathToDylib] and
/// returns the path to the created framework directory.
Future<String> _createSliceFramework({
  required String frameworkName,
  required String pathToDylib,
  required String parentDir,
  required bool isSimulator,
}) async {
  final frameworkDir = Directory(
    "$parentDir"
    "${Platform.pathSeparator}$frameworkName.framework",
  );
  await frameworkDir.create(recursive: true);

  // Change directory to the framework directory and run commands
  final temp = Directory.current;
  Directory.current = frameworkDir;
  await runAsync(
    "lipo",
    [
      "-create",
      pathToDylib,
      "-output",
      "${frameworkDir.path}"
          "${Platform.pathSeparator}$frameworkName",
    ],
  );
  await runAsync("install_name_tool", [
    "-id",
    "@rpath"
        "${Platform.pathSeparator}$frameworkName.framework"
        "${Platform.pathSeparator}$frameworkName",
    "${frameworkDir.path}"
        "${Platform.pathSeparator}$frameworkName",
  ]);
  Directory.current = temp;

  // Create Info.plist file
  final plistFile = File(
    "${frameworkDir.path}"
    "${Platform.pathSeparator}Info.plist",
  );
  await plistFile.writeAsString('''
<plist version="1.0">
    <dict>
        <key>BuildMachineOSBuild</key>
        <string>23E224</string>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>$frameworkName</string>
        <key>CFBundleIdentifier</key>
        <string>com.cypherstack.$frameworkName</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>$frameworkName</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
            <string>${isSimulator ? "iPhoneSimulator" : "iPhoneOS"}</string>
        </array>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        <key>MinimumOSVersion</key>
        <string>15.0</string>
        <key>UIDeviceFamily</key>
        <array>
            <integer>1</integer>
        </array>
        <key>UIRequiredDeviceCapabilities</key>
        <array>
            <string>arm64</string>
        </array>
    </dict>
</plist>
''');

  return frameworkDir.path;
}

Future<void> deleteIfExists(String path) async {
  final entity = FileSystemEntity.typeSync(path);
  if (entity != FileSystemEntityType.notFound) {
    await Directory(path).delete(recursive: true).catchError((_) {
      return File(path).delete();
    });
  }
}
