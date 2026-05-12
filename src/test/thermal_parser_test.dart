import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/core/thermal_parser.dart';

void main() {
  test('parses MLX90640 frames across chunks', () {
    final packet = mlxPacket('MLX40BEGIN', 'MLX40END', 32, 24, 33.5, 18.25);
    final parser = ThermalParser();

    expect(parser.feed(Uint8List.sublistView(packet, 0, 57)), isEmpty);
    final frames = parser.feed(Uint8List.sublistView(packet, 57));

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.mlx90640);
    expect(frames.single.width, 32);
    expect(frames.single.height, 24);
    expect(frames.single.tMax, closeTo(33.5, 0.001));
    expect(frames.single.tMin, closeTo(18.25, 0.001));
    expect(frames.single.temperatures.first, closeTo(20, 0.001));
    expect(parser.stats.packetsFound, 1);
  });

  test('parses MLX90641 frames with garbage before marker', () {
    final packet = mlxPacket('MLX41BEGIN', 'MLX41END', 16, 12, 40, 10);
    final parser = ThermalParser();
    final frames = parser.feed(
      Uint8List.fromList([...ascii.encode('noise'), ...packet]),
    );

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.mlx90641);
    expect(frames.single.width, 16);
    expect(frames.single.height, 12);
  });

  test('parses Heimann uint16 BEGIN frames', () {
    final packet = heimannPacket(32, 32, 40, 20);
    final parser = ThermalParser();
    final frames = parser.feed(packet);

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.heimann);
    expect(frames.single.width, 32);
    expect(frames.single.height, 32);
    expect(frames.single.tMax, closeTo(40, 0.11));
    expect(frames.single.tMin, closeTo(20, 0.11));
  });

  test('parses Heimann frames across chunks', () {
    final packet = heimannPacket(32, 32, 40, 20);
    final parser = ThermalParser();

    expect(parser.feed(Uint8List.sublistView(packet, 0, 128)), isEmpty);
    final frames = parser.feed(Uint8List.sublistView(packet, 128));

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.heimann);
  });

  test('parses legacy BEGIN float frames', () {
    final packet = legacyPacket(32, 24, 34, 21, 27);
    final parser = ThermalParser();
    final frames = parser.feed(packet);

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.legacy);
    expect(frames.single.tAvg, closeTo(27, 0.001));
  });

  test('counts sync errors and resynchronizes', () {
    final good = mlxPacket('MLX40BEGIN', 'MLX40END', 32, 24, 35, 15);
    final bad = Uint8List.fromList(good)..[good.length - 1] = 0x58;
    final parser = ThermalParser();
    final frames = parser.feed(Uint8List.fromList([...bad, ...good]));

    expect(frames, hasLength(1));
    expect(parser.stats.syncErrors, greaterThan(0));
  });

  test('bounds buffer under malformed streams', () {
    final parser = ThermalParser();
    // 3 MB of noise with no markers. Without the cap the parser would keep
    // the whole thing around. The cap should trim to ~128KB and mark a
    // sync error.
    final noise = Uint8List(3 * 1024 * 1024);
    parser.feed(noise);

    expect(parser.stats.bufferLength, lessThanOrEqualTo(256 * 1024));
    expect(parser.stats.syncErrors, greaterThan(0));
  });

  test('recovers a real packet after a buffer-cap trim', () {
    final parser = ThermalParser();
    // Flood with garbage, then feed a real packet. The cap should preserve
    // enough tail for the subsequent marker to sync.
    parser.feed(Uint8List(3 * 1024 * 1024));
    final packet = mlxPacket('MLX40BEGIN', 'MLX40END', 32, 24, 30, 10);
    final frames = parser.feed(packet);

    expect(frames, hasLength(1));
    expect(frames.single.sensorType, ThermalSensorType.mlx90640);
  });
}

Uint8List mlxPacket(
  String begin,
  String end,
  int width,
  int height,
  double tMax,
  double tMin,
) {
  final payload = Uint8List(8 + width * height * 4);
  final view = ByteData.sublistView(payload);
  view.setFloat32(0, tMax, Endian.little);
  view.setFloat32(4, tMin, Endian.little);
  for (var i = 0; i < width * height; i++) {
    view.setFloat32(8 + i * 4, 20 + i / 100, Endian.little);
  }
  return Uint8List.fromList([
    ...ascii.encode(begin),
    ...payload,
    ...ascii.encode(end),
  ]);
}

Uint8List legacyPacket(
  int width,
  int height,
  double tMax,
  double tMin,
  double tAvg,
) {
  final payload = Uint8List(12 + width * height * 4);
  final view = ByteData.sublistView(payload);
  view.setFloat32(0, tMax, Endian.little);
  view.setFloat32(4, tMin, Endian.little);
  view.setFloat32(8, tAvg, Endian.little);
  for (var i = 0; i < width * height; i++) {
    view.setFloat32(12 + i * 4, 20 + i / 100, Endian.little);
  }
  return Uint8List.fromList([
    ...ascii.encode('BEGIN'),
    ...payload,
    ...ascii.encode('END'),
  ]);
}

Uint8List heimannPacket(int width, int height, double tMax, double tMin) {
  final payload = Uint8List(4 + width * height * 2);
  final view = ByteData.sublistView(payload);
  view.setUint16(0, ((tMax + 273.15) / 0.1).round(), Endian.little);
  view.setUint16(2, ((tMin + 273.15) / 0.1).round(), Endian.little);
  for (var i = 0; i < width * height; i++) {
    view.setUint16(
      4 + i * 2,
      ((20 + i / 100 + 273.15) / 0.1).round(),
      Endian.little,
    );
  }
  return Uint8List.fromList([
    ...ascii.encode('BEGIN'),
    ...payload,
    ...ascii.encode('END'),
  ]);
}
