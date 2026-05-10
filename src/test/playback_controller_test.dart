import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/core/uir_format.dart';
import 'package:umeko_ir_flutter/src/playback/playback_controller.dart';
import 'package:umeko_ir_flutter/src/playback/uir_reader.dart';
import 'package:umeko_ir_flutter/src/recording/uir_writer.dart';

void main() {
  test('seeks and steps through UIR frames', () {
    final controller = UirPlaybackController(_document());
    addTearDown(controller.dispose);

    expect(controller.frameCount, 3);
    expect(controller.currentIndex, 0);
    expect(controller.position, Duration.zero);

    controller.seekToFrame(2);
    expect(controller.currentIndex, 2);
    expect(controller.position, const Duration(milliseconds: 200));

    controller.stepBackward();
    expect(controller.currentIndex, 1);

    controller.stepForward();
    expect(controller.currentIndex, 2);
  });

  test('clamps speed to supported playback range', () {
    final controller = UirPlaybackController(_document());
    addTearDown(controller.dispose);

    controller.setSpeed(9);
    expect(controller.speed, 4);

    controller.setSpeed(0.1);
    expect(controller.speed, 0.25);
  });

  test('restores measurement points from UIR metadata', () {
    final createdAt = DateTime.utc(2026, 5, 10, 12);
    final writer = UirByteWriter(
      width: 4,
      height: 3,
      sensorType: ThermalSensorType.mlx90640,
      createdAt: createdAt,
    );
    writer.writeMetadata({
      'points': [
        {
          'id': 'p1',
          'xNorm': 0.25,
          'yNorm': 0.5,
          'label': 'P1',
          'colorArgb': 0xffffd166,
        },
      ],
    });
    writer.writeFrame(_frame(0, createdAt), elapsed: Duration.zero);

    final controller = UirPlaybackController(
      const UirReader().read(writer.finish()),
    );
    addTearDown(controller.dispose);

    expect(controller.points, hasLength(1));
    expect(controller.points.single.id, 'p1');
    expect(controller.points.single.xNorm, 0.25);
  });
}

UirDocument _document() {
  final createdAt = DateTime.utc(2026, 5, 10, 12);
  final writer = UirByteWriter(
    width: 4,
    height: 3,
    sensorType: ThermalSensorType.mlx90640,
    createdAt: createdAt,
    isVideo: true,
  );
  for (var i = 0; i < 3; i++) {
    writer.writeFrame(
      _frame(i, createdAt.add(Duration(milliseconds: i * 100))),
      elapsed: Duration(milliseconds: i * 100),
    );
  }
  return const UirReader().read(writer.finish());
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
