import 'dart:convert';
import 'dart:typed_data';

import 'thermal_frame.dart';

const heimannWidth = 32;
const heimannHeight = 32;
const mlx90640Width = 32;
const mlx90640Height = 24;
const mlx90641Width = 16;
const mlx90641Height = 12;
const legacyWidth = 32;
const legacyHeight = 24;

final legacyBeginMarker = Uint8List.fromList(ascii.encode('BEGIN'));
final legacyEndMarker = Uint8List.fromList(ascii.encode('END'));
final mlx90640BeginMarker = Uint8List.fromList(ascii.encode('MLX40BEGIN'));
final mlx90640EndMarker = Uint8List.fromList(ascii.encode('MLX40END'));
final mlx90641BeginMarker = Uint8List.fromList(ascii.encode('MLX41BEGIN'));
final mlx90641EndMarker = Uint8List.fromList(ascii.encode('MLX41END'));

enum ThermalPayloadEncoding { uint16KelvinDeciCelsius, float32Celsius }

enum DevicePhotoFormat {
  uint16_32x32(
    width: heimannWidth,
    height: heimannHeight,
    encoding: ThermalPayloadEncoding.uint16KelvinDeciCelsius,
    sensorType: ThermalSensorType.heimann,
  ),
  float32_32x24(
    width: mlx90640Width,
    height: mlx90640Height,
    encoding: ThermalPayloadEncoding.float32Celsius,
    sensorType: ThermalSensorType.mlx90640,
  ),
  float32_16x12(
    width: mlx90641Width,
    height: mlx90641Height,
    encoding: ThermalPayloadEncoding.float32Celsius,
    sensorType: ThermalSensorType.mlx90641,
  );

  const DevicePhotoFormat({
    required this.width,
    required this.height,
    required this.encoding,
    required this.sensorType,
  });

  final int width;
  final int height;
  final ThermalPayloadEncoding encoding;
  final ThermalSensorType sensorType;

  int get pixelCount => width * height;
  int get payloadSize {
    return switch (encoding) {
      ThermalPayloadEncoding.uint16KelvinDeciCelsius => pixelCount * 2,
      ThermalPayloadEncoding.float32Celsius => pixelCount * 4,
    };
  }

  static DevicePhotoFormat? fromPayloadSize(int size) {
    for (final format in DevicePhotoFormat.values) {
      if (format.payloadSize == size) return format;
    }
    return null;
  }
}

Float32List decodeTemperaturePayload(
  ByteData view,
  DevicePhotoFormat format, {
  int offset = 0,
}) {
  final temperatures = Float32List(format.pixelCount);
  for (var i = 0; i < temperatures.length; i++) {
    temperatures[i] = switch (format.encoding) {
      ThermalPayloadEncoding.uint16KelvinDeciCelsius =>
        view.getUint16(offset + i * 2, Endian.little) * 0.1 - 273.15,
      ThermalPayloadEncoding.float32Celsius => view.getFloat32(
        offset + i * 4,
        Endian.little,
      ),
    };
  }
  return temperatures;
}
