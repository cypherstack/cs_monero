import 'package:cs_monero_flutter_libs_platform_interface/cs_monero_flutter_libs_platform_interface.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('cs_monero_flutter_libs_linux');

class CsMoneroFlutterLibsLinux extends CsMoneroFlutterLibsPlatform {
  /// Registers this class as the default instance of [CsMoneroFlutterLibsPlatform].
  static void registerWith() {
    CsMoneroFlutterLibsPlatform.instance = CsMoneroFlutterLibsLinux();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}