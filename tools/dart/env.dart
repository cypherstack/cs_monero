import 'dart:io';

const kMoneroCRepo = "https://github.com/cypherstack/monero_c";
const kMoneroCHash = "1e96d79026cf80f73e4476d4e5a8be9485b93bc1"; // TODO: Merge to #main.

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
