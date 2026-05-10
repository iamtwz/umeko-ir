import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/recording/uir_writer.dart';
import 'package:umeko_ir_flutter/src/storage/gallery_entry.dart';
import 'package:umeko_ir_flutter/src/storage/uir_repository_io.dart';

void main() {
  test('saves, lists, reads, and deletes local UIR recordings', () async {
    final temp = await Directory.systemTemp.createTemp('umeko_uir_repo_test_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final repository = IoUirRepository(recordingsDirectory: temp);
    final bytes = _sampleRecording();

    final saved = await repository.saveBytes(bytes: bytes, name: 'Lab run');

    expect(saved.source, GallerySource.local);
    expect(saved.kind, GalleryKind.video);
    expect(saved.name, 'Lab run');
    expect(saved.frameCount, 2);
    expect(saved.duration, const Duration(milliseconds: 100));

    final entries = await repository.listEntries();
    expect(entries, hasLength(1));
    expect(entries.single.id, saved.id);

    final readBack = await repository.readBytes(saved.id);
    expect(readBack, bytes);

    expect(
      temp.listSync().map(
        (entity) => entity.path.split(Platform.pathSeparator).last,
      ),
      allOf(contains('${saved.id}.uir'), isNot(contains('${saved.id}.json'))),
    );

    await repository.delete(saved.id);
    expect(await repository.listEntries(), isEmpty);
  });

  test('ignores malformed UIR files while listing', () async {
    final temp = await Directory.systemTemp.createTemp('umeko_uir_repo_test_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    await File(
      '${temp.path}${Platform.pathSeparator}bad.uir',
    ).writeAsString('{not json');

    final repository = IoUirRepository(recordingsDirectory: temp);

    expect(await repository.listEntries(), isEmpty);
  });
}

Uint8List _sampleRecording() {
  final createdAt = DateTime.utc(2026, 5, 10, 12);
  final writer = UirByteWriter(
    width: 4,
    height: 3,
    sensorType: ThermalSensorType.mlx90640,
    createdAt: createdAt,
    isVideo: true,
  );
  writer.writeFrame(_frame(0, createdAt), elapsed: Duration.zero);
  writer.writeFrame(
    _frame(1, createdAt.add(const Duration(milliseconds: 100))),
    elapsed: const Duration(milliseconds: 100),
  );
  writer.writeMetadata({'name': 'Lab run'});
  return writer.finish();
}

ThermalFrame _frame(int id, DateTime timestamp) {
  final temperatures = Float32List.fromList([
    for (var i = 0; i < 12; i++) 20 + id + i * 0.03,
  ]);
  return ThermalFrame(
    id: 'test-$id',
    timestamp: timestamp,
    temperatures: temperatures,
    width: 4,
    height: 3,
    sensorType: ThermalSensorType.mlx90640,
    tMin: temperatures.first,
    tMax: temperatures.last,
    tAvg: temperatures.reduce((a, b) => a + b) / temperatures.length,
  );
}
