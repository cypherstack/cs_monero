import 'package:cs_monero_flutter_libs_android_armeabi_v7a/cs_monero_flutter_libs_android_armeabi_v7a.dart';
import 'package:cs_monero_flutter_libs_android_armeabi_v7a/cs_monero_flutter_libs_android_armeabi_v7a_method_channel.dart';
import 'package:cs_monero_flutter_libs_android_armeabi_v7a/cs_monero_flutter_libs_android_armeabi_v7a_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCsMoneroFlutterLibsAndroidArmeabiV7aPlatform
    with MockPlatformInterfaceMixin
    implements CsMoneroFlutterLibsAndroidArmeabiV7aPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CsMoneroFlutterLibsAndroidArmeabiV7aPlatform initialPlatform =
      CsMoneroFlutterLibsAndroidArmeabiV7aPlatform.instance;

  test(
      '$MethodChannelCsMoneroFlutterLibsAndroidArmeabiV7a is the default instance',
      () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelCsMoneroFlutterLibsAndroidArmeabiV7a>(),
    );
  });

  test('getPlatformVersion', () async {
    final csMoneroFlutterLibsAndroidArmeabiV7aPlugin =
        CsMoneroFlutterLibsAndroidArmeabiV7a();
    final fakePlatform = MockCsMoneroFlutterLibsAndroidArmeabiV7aPlatform();
    CsMoneroFlutterLibsAndroidArmeabiV7aPlatform.instance = fakePlatform;

    expect(
      await csMoneroFlutterLibsAndroidArmeabiV7aPlugin.getPlatformVersion(),
      '42',
    );
  });
}
