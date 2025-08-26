import 'dart:io';

const kMoneroCRepo = "https://github.com/cypherstack/monero_c";
const kMoneroCHash = "937cbd0651a7dd805a7a13e47436b2b97fc7317d"; // TODO: Merge to #main.

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
