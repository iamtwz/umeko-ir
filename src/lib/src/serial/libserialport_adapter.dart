import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'serial_adapter.dart';

class LibSerialPortAdapter implements SerialAdapter {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;
  final _controller = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async {
    final rawPorts = SerialPort.availablePorts;
    return rawPorts.map(_canonicalPortPath).where(_portPathExists).map((name) {
      final metadata = _readPortMetadata(name);
      return SerialPortDescriptor(
        id: name,
        label: name,
        description: metadata.description,
        vendorId: metadata.vendorId,
        productId: metadata.productId,
      );
    }).toList();
  }

  ({String? description, int? vendorId, int? productId}) _readPortMetadata(
    String name,
  ) {
    final port = SerialPort(name);
    try {
      return (
        description: _safeRead(() => port.description),
        vendorId: _safeRead(() => port.vendorId),
        productId: _safeRead(() => port.productId),
      );
    } finally {
      try {
        port.dispose();
      } catch (_) {
        // Metadata reads must not make refresh fail.
      }
    }
  }

  T? _safeRead<T>(T? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }

  String _canonicalPortPath(String name) {
    if (_portPathExists(name)) return name;
    final devPath = '/dev/$name';
    if (_portPathExists(devPath)) return devPath;
    return name;
  }

  bool _portPathExists(String name) {
    return File(name).existsSync();
  }

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    await disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!File(port.id).existsSync()) {
      throw StateError('Serial port disappeared: ${port.id}');
    }
    try {
      _port = _openConfiguredPort(port.id, options.baudRate);
    } catch (e) {
      if (options.baudRate == 115200 || !_isResultTooLarge(e)) rethrow;
      _port = _openConfiguredPort(port.id, 115200);
    }

    _reader = SerialPortReader(_port!, timeout: 50);
    _subscription = _reader!.stream.listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  SerialPort _openConfiguredPort(String path, int baudRate) {
    final serialPort = SerialPort(path);
    if (!serialPort.openReadWrite()) {
      final error = SerialPort.lastError;
      serialPort.dispose();
      throw StateError('Failed to open $path: $error');
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none);
    try {
      serialPort.config = config;
    } catch (e) {
      serialPort.close();
      serialPort.dispose();
      throw StateError('Failed to configure $path at $baudRate baud: $e');
    }
    return serialPort;
  }

  bool _isResultTooLarge(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('errno = 34') ||
        message.contains('result too large');
  }

  @override
  Future<void> write(Uint8List data) async {
    final port = _port;
    if (port == null || !port.isOpen) {
      throw StateError('Serial port is not open');
    }
    final written = port.write(data, timeout: 1000);
    if (written != data.length) {
      throw StateError(
        'Only wrote $written/${data.length} bytes: ${utf8.decode(data, allowMalformed: true)}',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
    } catch (_) {
      // The OS can invalidate a USB serial fd before the reader is cancelled.
    }
    _subscription = null;
    try {
      _reader?.close();
    } catch (_) {
      // Closing an already-invalid native serial handle should be idempotent.
    }
    _reader = null;
    try {
      _port?.close();
    } catch (_) {
      // Ignore native close errors after unplug/re-enumeration.
    }
    try {
      _port?.dispose();
    } catch (_) {
      // Ignore native dispose errors after unplug/re-enumeration.
    }
    _port = null;
  }
}
