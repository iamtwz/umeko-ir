import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/application/thermal_controller.dart';
import 'package:umeko_ir_flutter/src/serial/serial_adapter.dart';

void main() {
  test('deletePhoto reports busy and removes the gallery item', () async {
    final serial = _FakeSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    await controller.loadGallery();

    expect(container.read(thermalControllerProvider).gallery, hasLength(1));

    final delete = controller.deletePhoto('001.bin');
    expect(container.read(thermalControllerProvider).busy, isTrue);

    await delete;

    final state = container.read(thermalControllerProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.gallery, isEmpty);
  });

  test('clearPhotos reports busy and clears the gallery', () async {
    final serial = _FakeSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    await controller.loadGallery();

    expect(container.read(thermalControllerProvider).gallery, hasLength(1));

    final clear = controller.clearPhotos();
    expect(container.read(thermalControllerProvider).busy, isTrue);

    await clear;

    final state = container.read(thermalControllerProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.gallery, isEmpty);
    expect(
      serial.writes.map((write) => write.trim()),
      contains('clear_photos'),
    );
  });

  test(
    'connect auto-start stream handles write failures without throwing',
    () async {
      final serial = _FailingWriteSerialAdapter();
      final container = ProviderContainer(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
      );
      addTearDown(container.dispose);

      final controller = container.read(thermalControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.connect();

      final state = container.read(thermalControllerProvider);
      expect(state.connected, isFalse);
      expect(state.streaming, isFalse);
      expect(state.error, contains('Access denied'));
      expect(serial.connected, isFalse);
    },
  );

  test('stopStream handles serial write failures without throwing', () async {
    final serial = _CommandFailingSerialAdapter(failCommand: 'stop_stream');
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();

    expect(container.read(thermalControllerProvider).streaming, isTrue);

    await controller.stopStream();

    final state = container.read(thermalControllerProvider);
    expect(state.connected, isFalse);
    expect(state.streaming, isFalse);
    expect(state.error, contains('stop_stream'));
    expect(serial.connected, isFalse);
  });

  test('stream heartbeat write failure disconnects without throwing', () async {
    final serial = _NthStreamFailingSerialAdapter(failOnStreamWrite: 2);
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();

    expect(container.read(thermalControllerProvider).streaming, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final state = container.read(thermalControllerProvider);
    expect(state.connected, isFalse);
    expect(state.streaming, isFalse);
    expect(state.error, contains('heartbeat'));
    expect(serial.connected, isFalse);
  });
}

class _FakeSerialAdapter implements SerialAdapter {
  final _controller = StreamController<Uint8List>.broadcast();
  final _port = const SerialPortDescriptor(
    id: '/dev/cu.usbmodem-test',
    label: '/dev/cu.usbmodem-test',
    description: 'Pico',
    vendorId: 0x2e8a,
  );
  final List<String> writes = [];
  bool connected = false;

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => [_port];

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    connected = true;
  }

  @override
  Future<void> write(Uint8List data) async {
    writes.add(utf8.decode(data, allowMalformed: true));
    final command = writes.last.trim();
    if (command == 'ls') {
      _emitText('File: /001.bin, Size: ${24 * 32 * 4} bytes\r\nTotal: 1\r\n');
    } else if (command == 'cat /001.bin') {
      _controller.add(
        Uint8List.fromList([...utf8.encode('DATA:\r\n'), ..._payload()]),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  void _emitText(String text) {
    _controller.add(Uint8List.fromList(utf8.encode(text)));
  }

  Uint8List _payload() {
    final data = Uint8List(24 * 32 * 4);
    final view = ByteData.sublistView(data);
    for (var i = 0; i < 24 * 32; i++) {
      view.setFloat32(i * 4, 20 + i / 100, Endian.little);
    }
    return data;
  }
}

class _FailingWriteSerialAdapter implements SerialAdapter {
  final _controller = StreamController<Uint8List>.broadcast();
  final _port = const SerialPortDescriptor(
    id: 'COM3',
    label: 'COM3',
    description: 'Pico',
    vendorId: 0x2e8a,
  );
  bool connected = false;

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => [_port];

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    connected = true;
  }

  @override
  Future<void> write(Uint8List data) async {
    throw StateError('Serial port write failed: Access denied (errno=5)');
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }
}

class _CommandFailingSerialAdapter extends _FakeSerialAdapter {
  _CommandFailingSerialAdapter({required this.failCommand});

  final String failCommand;

  @override
  Future<void> write(Uint8List data) async {
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == failCommand) {
      throw StateError('Serial port write failed while sending $failCommand');
    }
    await super.write(data);
  }
}

class _NthStreamFailingSerialAdapter extends _FakeSerialAdapter {
  _NthStreamFailingSerialAdapter({required this.failOnStreamWrite});

  final int failOnStreamWrite;
  int streamWrites = 0;

  @override
  Future<void> write(Uint8List data) async {
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == 'stream') {
      streamWrites += 1;
      if (streamWrites == failOnStreamWrite) {
        throw StateError('Serial port write failed during heartbeat');
      }
    }
    await super.write(data);
  }
}
