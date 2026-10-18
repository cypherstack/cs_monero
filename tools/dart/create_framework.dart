import 'dart:io';

import 'util.dart';

const _kIosMinimumVersion = "16.0";

enum FrameworkLayout {
  versioned,
  flat,
}

Future<void> createFramework({
  required String frameworkName,
  required String pathToDylib,
  required String targetDirFrameworks,
  required FrameworkLayout layout,
}) async {
  final flat = layout == FrameworkLayout.flat;

  final frameworkDir = Directory(
    "$targetDirFrameworks"
    "${Platform.pathSeparator}$frameworkName.framework",
  );

  if (await frameworkDir.exists()) {
    await frameworkDir.delete(recursive: true);
  }
  await frameworkDir.create(recursive: true);

  final versionADir = Directory(
    "${frameworkDir.path}"
    "${Platform.pathSeparator}Versions"
    "${Platform.pathSeparator}A",
  );
  final binaryDir = flat ? frameworkDir : versionADir;
  final resourcesDir = flat
      ? frameworkDir
      : Directory(
          "${versionADir.path}"
          "${Platform.pathSeparator}Resources",
        );
  await resourcesDir.create(recursive: true);

  final binaryPath = "${binaryDir.path}"
      "${Platform.pathSeparator}$frameworkName";

  await runAsync(
    mach0ToolPath("lipo"),
    [
      "-create",
      pathToDylib,
      "-output",
      binaryPath,
    ],
  );

  await runAsync(mach0ToolPath("install_name_tool"), [
    "-id",
    flat
        ? "@rpath"
            "${Platform.pathSeparator}$frameworkName.framework"
            "${Platform.pathSeparator}$frameworkName"
        : "@rpath"
            "${Platform.pathSeparator}$frameworkName.framework"
            "${Platform.pathSeparator}Versions"
            "${Platform.pathSeparator}A"
            "${Platform.pathSeparator}$frameworkName",
    binaryPath,
  ]);

  await File(
    "${resourcesDir.path}"
    "${Platform.pathSeparator}Info.plist",
  ).writeAsString(_infoPlist(frameworkName, layout));

  if (!flat) {
    await _versionedSymlinks(frameworkDir, frameworkName);
  }

  l("Framework $frameworkName created successfully in ${frameworkDir.path}");
}

String _infoPlist(String frameworkName, FrameworkLayout layout) {
  if (layout == FrameworkLayout.flat) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
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
            <string>iPhoneOS</string>
        </array>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        <key>MinimumOSVersion</key>
        <string>$_kIosMinimumVersion</string>
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
''';
  }

  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
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
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
</dict>
</plist>
''';
}

Future<void> _versionedSymlinks(
  Directory frameworkDir,
  String frameworkName,
) async {
  final temp = Directory.current;

  Directory.current = frameworkDir;
  await Link(frameworkName).create(
    "Versions"
    "${Platform.pathSeparator}Current"
    "${Platform.pathSeparator}$frameworkName",
  );
  await Link("Resources").create(
    "Versions"
    "${Platform.pathSeparator}Current"
    "${Platform.pathSeparator}Resources",
  );

  Directory.current = Directory(
    "${frameworkDir.path}"
    "${Platform.pathSeparator}Versions",
  );
  await Link("Current").create("A", recursive: false);

  Directory.current = temp;
}
