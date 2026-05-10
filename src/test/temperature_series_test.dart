import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/temperature_series.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/core/thermal_points.dart';
import 'package:umeko_ir_flutter/src/core/uir_format.dart';
import 'package:umeko_ir_flutter/src/playback/uir_reader.dart';
import 'package:umeko_ir_flutter/src/recording/uir_writer.dart';

void main() {
  test('builds point temperature series from UIR frames', () {
    final document = _document();
    const point = ThermalPoint(
      id: 'p1',
      xNorm: 0,
      yNorm: 0,
      label: 'P1',
      colorArgb: 0xffffffff,
    );

    final series = buildTemperatureSeries(
      frames: document.frames,
      points: const [point],
    );

    expect(series['p1'], hasLength(2));
    expect(series['p1']!.last.temperature, closeTo(21, 0.005));
  });

  test('exports point temperature series as CSV', () {
    final document = _document();
    const point = ThermalPoint(
      id: 'p1',
      xNorm: 0,
      yNorm: 0,
      label: 'P1',
      colorArgb: 0xffffffff,
    );

    final csv = temperatureSeriesCsv(
      frames: document.frames,
      points: const [point],
    );

    expect(csv, contains('timestamp_iso8601,elapsed_ms'));
    expect(csv, contains(',1,p1,P1,'));
    expect(csv, contains(',21.00'));
  });
}

UirDocument _document() {
  final createdAt = DateTime.utc(2026, 5, 10, 12);
  final writer = UirByteWriter(
    width: 2,
    height: 2,
    sensorType: ThermalSensorType.mlx90640,
    createdAt: createdAt,
    isVideo: true,
  );
  writer.writeFrame(_frame(0, createdAt), elapsed: Duration.zero);
  writer.writeFrame(
    _frame(1, createdAt.add(const Duration(milliseconds: 100))),
    elapsed: const Duration(milliseconds: 100),
  );
  return const UirReader().read(writer.finish());
}

ThermalFrame _frame(int id, DateTime timestamp) {
  final temperatures = Float32List.fromList([
    20.0 + id,
    21.0 + id,
    22.0 + id,
    23.0 + id,
  ]);
  return ThermalFrame(
    id: 'test-$id',
    timestamp: timestamp,
    temperatures: temperatures,
    width: 2,
    height: 2,
    sensorType: ThermalSensorType.mlx90640,
    tMin: temperatures.first,
    tMax: temperatures.last,
    tAvg: temperatures.reduce((a, b) => a + b) / temperatures.length,
  );
}
