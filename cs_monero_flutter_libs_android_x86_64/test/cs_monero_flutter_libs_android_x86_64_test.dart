import 'package:cs_monero_flutter_libs_android_x86_64/cs_monero_flutter_libs_android_x86_64.dart';
import 'package:cs_monero_flutter_libs_android_x86_64/cs_monero_flutter_libs_android_x86_64_method_channel.dart';
import 'package:cs_monero_flutter_libs_android_x86_64/cs_monero_flutter_libs_android_x86_64_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCsMoneroFlutterLibsAndroidX8664Platform
    with MockPlatformInterfaceMixin
    implements CsMoneroFlutterLibsAndroidX8664Platform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CsMoneroFlutterLibsAndroidX8664Platform initialPlatform =
      CsMoneroFlutterLibsAndroidX8664Platform.instance;

  test('$MethodChannelCsMoneroFlutterLibsAndroidX8664 is the default instance',
      () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelCsMoneroFlutterLibsAndroidX8664>(),
    );
  });

  test('getPlatformVersion', () async {
    final csMoneroFlutterLibsAndroidX8664Plugin =
        CsMoneroFlutterLibsAndroidX8664();
    final fakePlatform = MockCsMoneroFlutterLibsAndroidX8664Platform();
    CsMoneroFlutterLibsAndroidX8664Platform.instance = fakePlatform;

    expect(
      await csMoneroFlutterLibsAndroidX8664Plugin.getPlatformVersion(),
      '42',
    );
  });
}
