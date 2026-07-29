import 'dart:io';

const kMoneroCRepo = "https://github.com/MrCyjaneK/monero_c";
const kMoneroCHash = "3bfb3856a838f2bf6b729501837bb0295dedf25d";

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
