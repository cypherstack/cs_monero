import 'package:cs_monero_flutter_libs_android_arm64_v8a/cs_monero_flutter_libs_android_arm64_v8a.dart';
import 'package:cs_monero_flutter_libs_android_armeabi_v7a/cs_monero_flutter_libs_android_armeabi_v7a.dart';
import 'package:cs_monero_flutter_libs_android_x86_64/cs_monero_flutter_libs_android_x86_64.dart';
import 'package:cs_monero_flutter_libs_platform_interface/cs_monero_flutter_libs_platform_interface.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('cs_monero_flutter_libs_android');

class CsMoneroFlutterLibsAndroid extends CsMoneroFlutterLibsPlatform {
  /// Registers this class as the default instance of [CsMoneroFlutterLibsPlatform].
  static void registerWith() {
    CsMoneroFlutterLibsPlatform.instance = CsMoneroFlutterLibsAndroid();
  }

  @override
  Future<String?> getPlatformVersion({
    bool overrideForBasicTestCoverageTesting = false,
  }) async {
    if (!overrideForBasicTestCoverageTesting) {
      // make calls so flutter doesn't tree shake
      await Future.wait([
        CsMoneroFlutterLibsAndroidArm64V8a().getPlatformVersion(),
        CsMoneroFlutterLibsAndroidArmeabiV7a().getPlatformVersion(),
        CsMoneroFlutterLibsAndroidX8664().getPlatformVersion(),
      ]);
    }

    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
