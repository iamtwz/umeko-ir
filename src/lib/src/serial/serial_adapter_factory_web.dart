import 'serial_adapter.dart';
import 'web_serial_adapter.dart';

SerialAdapter createPlatformSerialAdapter() {
  return WebSerialAdapter();
}
