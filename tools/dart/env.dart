import 'dart:io';

const kMoneroCRepo = "https://github.com/MrCyjaneK/monero_c";
const kMoneroCHash = "414d36309cf1f1a54ad1040392094ada46dda7b1";

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
