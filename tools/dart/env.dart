import 'dart:io';

const kMoneroCRepo = "https://github.com/cypherstack/monero_c";
const kMoneroCHash = "c023d0df4df8556a38090d9f89ff635e219841d9"; // TODO: Merge to #main.

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
