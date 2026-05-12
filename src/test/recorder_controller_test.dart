import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/application/thermal_points_controller.dart';
import 'package:umeko_ir_flutter/src/application/thermal_controller.dart';
import 'package:umeko_ir_flutter/src/playback/uir_reader.dart';
import 'package:umeko_ir_flutter/src/recording/recorder_controller.dart';
import 'package:umeko_ir_flutter/src/serial/serial_adapter.dart';
import 'package:umeko_ir_flutter/src/storage/gallery_entry.dart';
import 'package:umeko_ir_flutter/src/storage/uir_repository_base.dart';

void main() {
  test('captures current frame as a local UIR photo', () async {
    final serial = _FrameSerialAdapter();
    final repository = _MemoryUirRepository();
    final container = ProviderContainer(
      overrides: [
        serialAdapterProvider.overrideWithValue(serial),
        uirRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await _connectAndEmitFrame(container, serial, 0);
    container.read(thermalPointsProvider.notifier).add(0.25, 0.5);

    final recorder = container.read(recorderControllerProvider.notifier);
    final entry = await recorder.captureSnapshot(name: 'Still');

    expect(entry, isNotNull);
    expect(entry!.kind, GalleryKind.photo);
    expect(entry.name, 'Still');
    expect(repository.savedBytes, hasLength(1));
    final document = const UirReader().read(repository.savedBytes.single);
    expect(document.header.isVideo, isFalse);
    expect(document.metadata['name'], 'Still');
    expect(document.metadata['points'], isA<List<Object?>>());
    expect(document.frames, hasLength(1));
    expect(document.frames.single.frame.temperatures.first, closeTo(20, 0.005));
  });

  test('records frame stream as a local UIR video', () async {
    final serial = _FrameSerialAdapter();
    final repository = _MemoryUirRepository();
    final container = ProviderContainer(
      overrides: [
        serialAdapterProvider.overrideWithValue(serial),
        uirRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await _connectAndEmitFrame(container, serial, 0);

    final recorder = container.read(recorderControllerProvider.notifier);
    await recorder.startRecording(name: 'Clip');
    serial.emitFrame(1);
    await Future<void>.delayed(Duration.zero);
    final entry = await recorder.stopRecording(name: 'Clip');

    expect(entry, isNotNull);
    expect(entry!.kind, GalleryKind.video);
    expect(entry.frameCount, 2);
    final document = const UirReader().read(repository.savedBytes.single);
    expect(document.header.isVideo, isTrue);
    expect(document.metadata['name'], 'Clip');
    expect(document.frames, hasLength(2));
    expect(document.frames.last.frame.temperatures.first, closeTo(21, 0.005));
  });

  test('stops recording when byteLimit is reached', () async {
    final serial = _FrameSerialAdapter();
    final repository = _MemoryUirRepository();
    final container = ProviderContainer(
      overrides: [
        serialAdapterProvider.overrideWithValue(serial),
        uirRepositoryProvider.overrideWithValue(repository),
        recorderControllerProvider.overrideWith(
          // 8 KB: two 3KB MLX40 frames will exceed it even after compression.
          () => RecorderController(byteLimit: 8 * 1024),
        ),
      ],
    );
    addTearDown(container.dispose);
    await _connectAndEmitFrame(container, serial, 0);

    final recorder = container.read(recorderControllerProvider.notifier);
    await recorder.startRecording(name: 'Capped');
    // Emit enough frames to blow past the cap. The controller polls byteLength
    // after each write and should stop+save on the offending frame.
    for (var i = 1; i < 20; i++) {
      serial.emitFrame(i);
      await Future<void>.delayed(Duration.zero);
    }
    // Drain the async `_finalizeAtLimit()` completion.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    final state = container.read(recorderControllerProvider);
    expect(state.status, RecorderStatus.stoppedAtLimit);
    expect(state.lastSavedEntry, isNotNull);
    expect(state.error, contains('size limit'));
    expect(repository.savedBytes, hasLength(1));
  });
}

Future<void> _connectAndEmitFrame(
  ProviderContainer container,
  _FrameSerialAdapter serial,
  int frameId,
) async {
  final controller = container.read(thermalControllerProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  await controller.connect();
  await controller.startStream();
  serial.emitFrame(frameId);
  await Future<void>.delayed(Duration.zero);
}

class _MemoryUirRepository implements UirRepository {
  final savedBytes = <Uint8List>[];
  final entries = <GalleryEntry>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> delete(String id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<List<GalleryEntry>> listEntries() async => List.unmodifiable(entries);

  @override
  Future<Uint8List> readBytes(String id) async {
    return savedBytes[entries.indexWhere((entry) => entry.id == id)];
  }

  @override
  Future<GalleryEntry> saveBytes({
    required Uint8List bytes,
    required String name,
  }) async {
    final document = const UirReader().read(bytes);
    final entry = GalleryEntry(
      id: 'entry-${entries.length}',
      source: GallerySource.local,
      kind: document.header.isVideo || document.frames.length > 1
          ? GalleryKind.video
          : GalleryKind.photo,
      name: name,
      createdAt: document.header.createdAt,
      sizeBytes: bytes.length,
      width: document.header.width,
      height: document.header.height,
      sensorType: document.header.sensorType,
      tMin: document.frames.isEmpty ? 0 : document.frames.first.frame.tMin,
      tMax: document.frames.isEmpty ? 0 : document.frames.first.frame.tMax,
      tAvg: document.frames.isEmpty ? 0 : document.frames.first.frame.tAvg,
      duration: document.frames.isEmpty ? null : document.frames.last.elapsed,
      frameCount: document.frames.length,
    );
    savedBytes.add(bytes);
    entries.add(entry);
    return entry;
  }
}

class _FrameSerialAdapter implements SerialAdapter {
  final _controller = StreamController<Uint8List>.broadcast();
  final _port = const SerialPortDescriptor(
    id: '/dev/cu.usbmodem-test',
    label: '/dev/cu.usbmodem-test',
    description: 'Pico',
    vendorId: 0x2e8a,
  );

  @override
  Stream<Uint8List> get input => _controller.stream;

  @override
  Future<void> connect(
    SerialPortDescriptor port,
    SerialOptions options,
  ) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => [_port];

  @override
  Future<void> write(Uint8List data) async {}

  void emitFrame(int id) {
    _controller.add(_mlx40Packet(id));
  }
}

Uint8List _mlx40Packet(int id) {
  final payload = Uint8List(8 + 32 * 24 * 4);
  final view = ByteData.sublistView(payload);
  final temperatures = Float32List(32 * 24);
  for (var i = 0; i < temperatures.length; i++) {
    temperatures[i] = 20 + id + i / 100;
  }
  view.setFloat32(0, temperatures.last, Endian.little);
  view.setFloat32(4, temperatures.first, Endian.little);
  for (var i = 0; i < temperatures.length; i++) {
    view.setFloat32(8 + i * 4, temperatures[i], Endian.little);
  }
  return Uint8List.fromList([
    ...ascii.encode('MLX40BEGIN'),
    ...payload,
    ...ascii.encode('MLX40END'),
  ]);
}
