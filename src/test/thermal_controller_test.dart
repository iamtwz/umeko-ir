import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/application/thermal_controller.dart';
import 'package:umeko_ir_flutter/src/core/dual_vision.dart';
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

  test('loadGallery restarts serial session when stream is active', () async {
    final serial = _FakeSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();

    expect(container.read(thermalControllerProvider).streaming, isTrue);

    await controller.loadGallery();

    final commands = serial.writes.map((write) => write.trim()).toList();
    expect(commands, containsAllInOrder(['stream', 'stop_stream', 'ls']));
    expect(serial.connectCount, 2);
    expect(serial.disconnectCount, 1);
    expect(container.read(thermalControllerProvider).streaming, isFalse);
    expect(container.read(thermalControllerProvider).gallery, hasLength(1));
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

  test(
    'dual-vision writes preserve confirmed parameters and parse flips',
    () async {
      final serial = _DualVisionSerialAdapter();
      final container = ProviderContainer(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
      );
      addTearDown(container.dispose);

      final controller = container.read(thermalControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.connect();
      await controller.stopStream();
      await controller.probeDualVision();

      var state = container.read(thermalControllerProvider);
      expect(state.dualVision.capability, DualVisionCapability.supported);
      expect(state.dualVision.params?.tx, 12.5);
      expect(state.dualVision.params?.sy, 1.2);

      await controller.writeFusionAlpha(200);
      state = container.read(thermalControllerProvider);
      expect(state.dualVision.params?.fusionAlpha, 200);
      expect(state.dualVision.params?.tx, 12.5);
      expect(state.dualVision.params?.sy, 1.2);

      await controller.toggleCameraVflip();
      state = container.read(thermalControllerProvider);
      expect(state.dualVision.params?.vflip, isTrue);
      expect(state.dualVision.lastError, isNull);
    },
  );

  test('dual-vision probe switches an active stream to command mode', () async {
    final serial = _CommandModeDualVisionSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();

    expect(container.read(thermalControllerProvider).streaming, isTrue);
    await controller.probeDualVision();

    final state = container.read(thermalControllerProvider);
    expect(state.dualVision.capability, DualVisionCapability.supported);
    expect(state.dualVision.params?.tx, 12.5);
    expect(state.streaming, isFalse);
    expect(serial.connectCount, 2);
    expect(
      serial.writes.map((write) => write.trim()),
      containsAllInOrder(['stream', 'stop_stream', 'get_align']),
    );
  });

  test(
    'missing flip confirmation preserves unknown state and reports error',
    () async {
      final serial = _DualVisionSerialAdapter(respondToFlips: false);
      final container = ProviderContainer(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
      );
      addTearDown(container.dispose);

      final controller = container.read(thermalControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.connect();
      await controller.stopStream();
      await controller.probeDualVision();
      await controller.toggleCameraVflip();

      final state = container.read(thermalControllerProvider);
      expect(state.dualVision.params?.vflip, isNull);
      expect(state.dualVision.lastError, contains('timed out'));
    },
  );

  test('serial probe failure is retryable rather than unsupported', () async {
    final serial = _CommandFailingSerialAdapter(failCommand: 'get_align');
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    await controller.stopStream();
    await controller.probeDualVision();

    final state = container.read(thermalControllerProvider);
    expect(state.dualVision.capability, DualVisionCapability.error);
    expect(state.dualVision.lastError, contains('get_align'));
  });

  test(
    'disconnect cancels an in-flight probe without restoring stale state',
    () async {
      final serial = _DualVisionSerialAdapter(respondToAlign: false);
      final container = ProviderContainer(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
      );
      addTearDown(container.dispose);

      final controller = container.read(thermalControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.connect();
      await controller.stopStream();

      final probe = controller.probeDualVision();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.disconnect();
      await probe;

      final state = container.read(thermalControllerProvider);
      expect(state.connected, isFalse);
      expect(state.dualVision.capability, DualVisionCapability.unknown);
      expect(state.dualVision.params, isNull);
    },
  );

  test('stream stop and restart writes are serialized', () async {
    final serial = _GatedStopSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    serial.gateStop = true;

    final stop = controller.stopStream();
    await Future<void>.delayed(Duration.zero);
    final start = controller.startStream();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    var commands = serial.writes.map((write) => write.trim()).toList();
    expect(commands, ['stream', 'stop_stream']);

    serial.releaseStop();
    await Future.wait([stop, start]);

    commands = serial.writes.map((write) => write.trim()).toList();
    expect(commands, ['stream', 'stop_stream', 'stream']);
    expect(container.read(thermalControllerProvider).streaming, isTrue);
  });

  test(
    'stale stop failure does not pollute an intentional disconnect',
    () async {
      final serial = _DelayedFailingStopSerialAdapter();
      final container = ProviderContainer(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
      );
      addTearDown(container.dispose);

      final controller = container.read(thermalControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.connect();

      final stop = controller.stopStream();
      await Future<void>.delayed(Duration.zero);
      await controller.disconnect();
      serial.failStop();
      await stop;

      final state = container.read(thermalControllerProvider);
      expect(state.connected, isFalse);
      expect(state.streaming, isFalse);
      expect(state.error, isNull);
    },
  );

  test('disconnect failure still resets local connection state', () async {
    final serial = _FailOnceDisconnectSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    await controller.disconnect();

    final state = container.read(thermalControllerProvider);
    expect(state.connected, isFalse);
    expect(state.streaming, isFalse);
    expect(state.busy, isFalse);
    expect(state.error, contains('close failed'));
  });

  test('timed-out write releases queue for following commands', () async {
    final serial = _HangingAlphaSerialAdapter();
    final container = ProviderContainer(
      overrides: [serialAdapterProvider.overrideWithValue(serial)],
    );
    addTearDown(container.dispose);

    final controller = container.read(thermalControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.connect();
    await controller.stopStream();
    await controller.probeDualVision();

    await controller.writeFusionAlpha(200);
    var state = container.read(thermalControllerProvider);
    expect(state.dualVision.params?.fusionAlpha, 128);
    expect(state.dualVision.lastError, contains('timed out'));

    await controller.toggleCameraVflip();
    state = container.read(thermalControllerProvider);
    expect(state.dualVision.params?.vflip, isTrue);
    expect(state.dualVision.lastError, isNull);
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
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => [_port];

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    connected = true;
    connectCount += 1;
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
    disconnectCount += 1;
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

class _DualVisionSerialAdapter extends _FakeSerialAdapter {
  _DualVisionSerialAdapter({
    this.respondToAlign = true,
    this.respondToFlips = true,
  });

  final bool respondToAlign;
  final bool respondToFlips;

  @override
  Future<void> write(Uint8List data) async {
    await super.write(data);
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == 'get_align' && respondToAlign) {
      _emitText('ALIGN 12.50 -4.00 1.100 1.200 -15.00 128\n');
    } else if (command == 'toggle_vflip' && respondToFlips) {
      _emitText('VFLIP:1\n');
    } else if (command == 'toggle_hflip' && respondToFlips) {
      _emitText('HFLIP:1\n');
    }
  }
}

class _CommandModeDualVisionSerialAdapter extends _FakeSerialAdapter {
  bool _streaming = false;

  @override
  Future<void> write(Uint8List data) async {
    await super.write(data);
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == 'stream') {
      _streaming = true;
    } else if (command == 'stop_stream') {
      _streaming = false;
    } else if (command == 'get_align' && !_streaming) {
      _emitText('ALIGN 12.50 -4.00 1.100 1.200 -15.00 128\n');
    }
  }
}

class _GatedStopSerialAdapter extends _FakeSerialAdapter {
  bool gateStop = false;
  Completer<void>? _stopGate;

  @override
  Future<void> write(Uint8List data) async {
    await super.write(data);
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (gateStop && command == 'stop_stream') {
      _stopGate = Completer<void>();
      await _stopGate!.future;
    }
  }

  void releaseStop() {
    final gate = _stopGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

class _DelayedFailingStopSerialAdapter extends _FakeSerialAdapter {
  final _stopWrite = Completer<void>();

  @override
  Future<void> write(Uint8List data) async {
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == 'stop_stream') {
      writes.add(utf8.decode(data, allowMalformed: true));
      await _stopWrite.future;
      return;
    }
    await super.write(data);
  }

  void failStop() {
    if (!_stopWrite.isCompleted) {
      _stopWrite.completeError(StateError('stale stop failed'));
    }
  }
}

class _FailOnceDisconnectSerialAdapter extends _FakeSerialAdapter {
  bool _shouldFail = true;

  @override
  Future<void> disconnect() async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('close failed');
    }
    await super.disconnect();
  }
}

class _HangingAlphaSerialAdapter extends _DualVisionSerialAdapter {
  final _alphaWrite = Completer<void>();

  @override
  Future<void> write(Uint8List data) async {
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command.startsWith('set_alpha ')) {
      writes.add(utf8.decode(data, allowMalformed: true));
      await _alphaWrite.future;
      return;
    }
    await super.write(data);
  }
}
