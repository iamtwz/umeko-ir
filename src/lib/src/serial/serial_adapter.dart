import 'dart:async';
import 'dart:typed_data';

class SerialPortDescriptor {
  const SerialPortDescriptor({
    required this.id,
    required this.label,
    this.description,
    this.virtual = false,
    this.vendorId,
    this.productId,
  });

  final String id;
  final String label;
  final String? description;
  final bool virtual;
  final int? vendorId;
  final int? productId;
}

class SerialOptions {
  const SerialOptions({
    this.baudRate = 115200,
    this.dtr = true,
    this.rts = true,
  });

  final int baudRate;
  final bool dtr;
  final bool rts;
}

abstract interface class SerialAdapter {
  Future<List<SerialPortDescriptor>> listPorts();
  Future<void> connect(SerialPortDescriptor port, SerialOptions options);
  Stream<Uint8List> get input;
  Future<void> write(Uint8List data);
  Future<void> disconnect();
}

class UnsupportedSerialAdapter implements SerialAdapter {
  const UnsupportedSerialAdapter([
    this.reason = 'Serial is not supported on this platform yet.',
  ]);

  final String reason;

  @override
  Stream<Uint8List> get input => const Stream.empty();

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) {
    throw UnsupportedError(reason);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => const [];

  @override
  Future<void> write(Uint8List data) {
    throw UnsupportedError(reason);
  }
}
