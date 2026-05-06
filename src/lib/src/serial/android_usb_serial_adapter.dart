import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import 'serial_adapter.dart';

class AndroidUsbSerialAdapter implements SerialAdapter {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _controller = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async {
    final devices = await UsbSerial.listDevices();
    return devices.map((device) {
      return SerialPortDescriptor(
        id: device.deviceId.toString(),
        label: device.productName ?? device.deviceName,
        description:
            '${device.deviceName} ${device.vid?.toRadixString(16) ?? ''}:${device.pid?.toRadixString(16) ?? ''}',
        vendorId: device.vid,
        productId: device.pid,
      );
    }).toList();
  }

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    await disconnect();
    final devices = await UsbSerial.listDevices();
    final device = devices.firstWhere(
      (item) => item.deviceId.toString() == port.id,
    );
    final usbPort = await device.create();
    if (usbPort == null || !await usbPort.open()) {
      throw StateError('Failed to open USB serial device ${port.label}');
    }
    await usbPort.setPortParameters(
      options.baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    await usbPort.setDTR(options.dtr);
    await usbPort.setRTS(options.rts);
    _port = usbPort;
    _subscription = usbPort.inputStream?.listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  @override
  Future<void> write(Uint8List data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port is not open');
    await port.write(data);
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _port?.close();
    _port = null;
  }
}
