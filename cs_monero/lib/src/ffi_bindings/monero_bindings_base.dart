import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'generated_bindings_monero.g.dart';

String get _libName {
  if (Platform.isIOS || Platform.isMacOS) {
    return 'MoneroWallet.framework/MoneroWallet';
  } else if (Platform.isAndroid) {
    return 'libmonero_libwallet2_api_c.so';
  } else if (Platform.isWindows) {
    return 'monero_libwallet2_api_c.dll';
  } else if (Platform.isLinux) {
    return 'monero_libwallet2_api_c.so';
  } else {
    throw UnsupportedError(
      "Platform \"${Platform.operatingSystem}\" is not supported",
    );
  }
}

FfiMoneroC? _cachedBindings;
FfiMoneroC get bindings => _cachedBindings ??= FfiMoneroC(
      Platform.isIOS
          ? DynamicLibrary.process()
          : DynamicLibrary.open(
              _libName,
            ),
    );

final defaultSeparatorStr = ";";
final defaultSeparator = defaultSeparatorStr.toNativeUtf8().cast<Char>();

String convertAndFree(Pointer<Utf8> stringPointer) {
  final value = stringPointer.toDartString();
  bindings.MONERO_free(stringPointer.cast());
  return value;
}
