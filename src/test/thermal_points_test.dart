import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/core/thermal_points.dart';
import 'package:umeko_ir_flutter/src/core/thermal_rendering.dart';

void main() {
  test('samples point temperatures with bilinear interpolation', () {
    final frame = ThermalFrame(
      id: 'f',
      timestamp: DateTime.utc(2026),
      temperatures: Float32List.fromList([10, 20, 30, 40]),
      width: 2,
      height: 2,
      sensorType: ThermalSensorType.mlx90640,
      tMin: 10,
      tMax: 40,
      tAvg: 25,
    );
    const point = ThermalPoint(
      id: 'p',
      xNorm: 0.5,
      yNorm: 0.5,
      label: 'P1',
      colorArgb: 0xffffffff,
    );

    expect(sampleThermalPoint(frame, point), closeTo(25, 0.001));
  });

  test('maps display coordinates back to source coordinates', () {
    const point = ThermalPoint(
      id: 'p',
      xNorm: 0.2,
      yNorm: 0.7,
      label: 'P1',
      colorArgb: 0xffffffff,
    );
    const settings = RenderSettings(rotation: 90, hflip: true);

    final display = thermalPointToDisplay(point, 32, 24, settings);
    final source = displayToThermalPoint(display, 32, 24, settings);

    expect(source.dx, closeTo(point.xNorm, 0.0001));
    expect(source.dy, closeTo(point.yNorm, 0.0001));
  });
}
