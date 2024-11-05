import 'dart:io';

const kMoneroCRepo = "https://github.com/MrCyjaneK/monero_c";
const kMoneroCHash = "1ef9024e43e774ac2c2976c33bf9024549c9c61b";

final envProjectDir =
    File.fromUri(Platform.script).parent.parent.parent.parent.path;

String get envToolsDir => "$envProjectDir${Platform.pathSeparator}tools";
String get envBuildDir => "$envProjectDir${Platform.pathSeparator}build";
String get envMoneroCDir => "$envBuildDir${Platform.pathSeparator}monero_c";
String get envOutputsDir =>
    "$envProjectDir${Platform.pathSeparator}built_outputs";
