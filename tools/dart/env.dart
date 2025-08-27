import 'dart:io';

const kMoneroCRepo = "https://github.com/cypherstack/monero_c";
const kMoneroCHash = "fa4c9dff5f2372261b000d11bc87d3ae97dc0ae6"; // TODO: Merge to #main.

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
