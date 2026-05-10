import 'dart:typed_data';

class DeviceFileInfo {
  const DeviceFileInfo({required this.filename, required this.size});

  final String filename;
  final int size;
}

enum DevicePhotoFormat { uint16_32x32, float32_32x24, float32_16x12 }

class DevicePhoto {
  const DevicePhoto({
    required this.filename,
    required this.size,
    required this.format,
    required this.width,
    required this.height,
    required this.temperatures,
    required this.tMin,
    required this.tMax,
    required this.tAvg,
  });

  final String filename;
  final int size;
  final DevicePhotoFormat format;
  final int width;
  final int height;
  final Float32List temperatures;
  final double tMin;
  final double tMax;
  final double tAvg;
}

List<DeviceFileInfo> parseDeviceFileList(String text) {
  final result = <DeviceFileInfo>[];
  final regex = RegExp(
    r'File:\s*/?([^,\s]+).*?Size:\s*(\d+)',
    caseSensitive: false,
  );
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final match = regex.firstMatch(line);
    if (match == null) continue;
    final filename = match.group(1)!;
    if (!filename.toLowerCase().endsWith('.bin')) continue;
    result.add(
      DeviceFileInfo(filename: filename, size: int.parse(match.group(2)!)),
    );
  }
  return result;
}

int findPhotoPayloadStart(DeviceFileInfo file, Uint8List data) {
  final starts = <int>[0];
  for (var i = 0; i < data.length; i++) {
    if (data[i] == 0x0a) starts.add(i + 1);
  }

  for (final start in starts) {
    if (start + file.size <= data.length &&
        _looksLikePhotoPayload(
          file,
          Uint8List.sublistView(data, start, start + file.size),
        )) {
      return start;
    }
  }
  return -1;
}

DevicePhoto parseDevicePhoto(DeviceFileInfo file, Uint8List data) {
  if (data.length < file.size) {
    throw FormatException(
      'Expected ${file.size} bytes for ${file.filename}, got ${data.length}',
    );
  }

  final payload = Uint8List.sublistView(data, 0, file.size);
  final view = ByteData.sublistView(payload);
  late final int width;
  late final int height;
  late final DevicePhotoFormat format;
  late final Float32List temperatures;

  if (file.size == 32 * 32 * 2) {
    width = 32;
    height = 32;
    format = DevicePhotoFormat.uint16_32x32;
    temperatures = Float32List(width * height);
    for (var i = 0; i < temperatures.length; i++) {
      temperatures[i] = view.getUint16(i * 2, Endian.little) * 0.1 - 273.15;
    }
  } else if (file.size == 24 * 32 * 4) {
    width = 32;
    height = 24;
    format = DevicePhotoFormat.float32_32x24;
    temperatures = Float32List(width * height);
    for (var i = 0; i < temperatures.length; i++) {
      temperatures[i] = view.getFloat32(i * 4, Endian.little);
    }
  } else if (file.size == 12 * 16 * 4) {
    width = 16;
    height = 12;
    format = DevicePhotoFormat.float32_16x12;
    temperatures = Float32List(width * height);
    for (var i = 0; i < temperatures.length; i++) {
      temperatures[i] = view.getFloat32(i * 4, Endian.little);
    }
  } else {
    throw FormatException('Unsupported photo file size: ${file.size}');
  }

  var tMin = double.infinity;
  var tMax = double.negativeInfinity;
  var sum = 0.0;
  for (final value in temperatures) {
    if (value < tMin) tMin = value;
    if (value > tMax) tMax = value;
    sum += value;
  }

  return DevicePhoto(
    filename: file.filename,
    size: file.size,
    format: format,
    width: width,
    height: height,
    temperatures: temperatures,
    tMin: tMin,
    tMax: tMax,
    tAvg: sum / temperatures.length,
  );
}

bool _looksLikePhotoPayload(DeviceFileInfo file, Uint8List data) {
  if (file.size != 32 * 32 * 2 &&
      file.size != 24 * 32 * 4 &&
      file.size != 12 * 16 * 4) {
    return false;
  }

  final view = ByteData.sublistView(data);
  const samples = 16;
  for (var i = 0; i < samples; i++) {
    final value = file.size == 32 * 32 * 2
        ? view.getUint16(i * 2, Endian.little) * 0.1 - 273.15
        : view.getFloat32(i * 4, Endian.little);
    if (!value.isFinite || value < -100 || value > 300) return false;
  }
  return true;
}
