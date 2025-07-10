import 'dart:io';

const kMoneroCRepo = "https://github.com/MrCyjaneK/monero_c";
const kMoneroCHash = "a27fbcb24d91143715ed930a05aaa4d853fba1f2";

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
