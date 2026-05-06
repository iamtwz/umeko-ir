import 'dart:io';

import 'android_usb_serial_adapter.dart';
import 'libserialport_adapter.dart';
import 'serial_adapter.dart';

SerialAdapter createPlatformSerialAdapter() {
  if (Platform.isAndroid) return AndroidUsbSerialAdapter();
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return LibSerialPortAdapter();
  }
  return const UnsupportedSerialAdapter(
    'Serial is not supported on this platform.',
  );
}
