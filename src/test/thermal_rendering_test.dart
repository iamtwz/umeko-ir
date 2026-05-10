import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_rendering.dart';

void main() {
  test('normalizes temperatures to byte range', () {
    final values = Float32List.fromList([10, 15, 20]);
    final normalized = normalizeTemperatures(values, 10, 20);

    expect(normalized, [0, 128, 255]);
  });

  test('orients temperatures with rotation and flips', () {
    final source = Float32List.fromList([1, 2, 3, 4, 5, 6]);
    final rotated = orientTemperatures(source, 3, 2, rotation: 90);
    final flipped = orientTemperatures(source, 3, 2, hflip: true);

    expect(rotated, [4, 1, 5, 2, 6, 3]);
    expect(flipped, [3, 2, 1, 6, 5, 4]);
  });

  test('applies device display baseline before user orientation', () {
    final source = Float32List.fromList([1, 2, 3, 4, 5, 6]);
    final baseline = orientForDisplay(source, 3, 2);
    final rotated = orientForDisplay(source, 3, 2, rotation: 90);

    expect(baseline, [4, 5, 6, 1, 2, 3]);
    expect(rotated, [1, 4, 2, 5, 3, 6]);
  });

  test('nearest upsample repeats source pixels', () {
    final source = Float32List.fromList([1, 2, 3, 4]);
    final up = nearestUpsample(source, 2, 2, 4, 4, 2);

    expect(up.take(4), [1, 1, 2, 2]);
    expect(up.skip(8).take(4), [3, 3, 4, 4]);
  });

  test('renders a valid RGBA raster', () {
    final raster = renderThermalRaster(
      temperatures: Float32List.fromList([20, 21, 22, 23]),
      width: 2,
      height: 2,
      tMin: 20,
      tMax: 23,
      scale: 2,
      settings: const RenderSettings(colorMap: ThermalColorMap.hot),
    );

    expect(raster.width, 4);
    expect(raster.height, 4);
    expect(raster.rgba.length, 4 * 4 * 4);
    expect(raster.rgba[3], 255);
  });

  test('render settings compare by value', () {
    expect(
      const RenderSettings(
        colorMap: ThermalColorMap.rainbow,
        filter: ThermalFilter.sobel,
        rotation: 90,
      ),
      const RenderSettings(
        colorMap: ThermalColorMap.rainbow,
        filter: ThermalFilter.sobel,
        rotation: 90,
      ),
    );
  });

  test('sobel filter uses luminance instead of red channel only', () {
    final rgba = Uint8List(3 * 3 * 4);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        final idx = (y * 3 + x) * 4;
        rgba[idx] = 0;
        rgba[idx + 1] = x * 100;
        rgba[idx + 2] = 0;
        rgba[idx + 3] = 255;
      }
    }

    applyFilter(rgba, 3, 3, ThermalFilter.sobel);

    expect(rgba[(1 * 3 + 1) * 4], greaterThan(0));
  });
}
