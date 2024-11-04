import 'package:cs_monero_flutter_libs_android/cs_monero_flutter_libs_android.dart';
import 'package:cs_monero_flutter_libs_platform_interface/cs_monero_flutter_libs_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("$CsMoneroFlutterLibsAndroid", () {
    final platform = CsMoneroFlutterLibsAndroid();
    const MethodChannel channel =
        MethodChannel("cs_monero_flutter_libs_android");

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          return "42";
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test("getPlatformVersion", () async {
      expect(
        await platform.getPlatformVersion(
          overrideForBasicTestCoverageTesting: true,
        ),
        "42",
      );
    });
  });

  test("registerWith", () {
    CsMoneroFlutterLibsAndroid.registerWith();
    expect(
      CsMoneroFlutterLibsPlatform.instance,
      isA<CsMoneroFlutterLibsAndroid>(),
    );
  });
}
