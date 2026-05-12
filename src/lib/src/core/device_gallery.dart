import 'dart:typed_data';

import 'thermal_format.dart';

export 'thermal_format.dart' show DevicePhotoFormat;

class DeviceFileInfo {
  const DeviceFileInfo({required this.filename, required this.size});

  final String filename;
  final int size;
}

final _fileDumpPrefix = Uint8List.fromList(
  '[FS] Dumping File Contents:\r\n'.codeUnits,
);

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
  final prefixStart = _indexOfBytes(data, _fileDumpPrefix);
  if (prefixStart != -1) {
    final start = prefixStart + _fileDumpPrefix.length;
    if (start + file.size <= data.length) return start;
  }

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
  for (final start in starts) {
    if (start + file.size == data.length) return start;
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
  final format = DevicePhotoFormat.fromPayloadSize(file.size);
  if (format == null) {
    throw FormatException('Unsupported photo file size: ${file.size}');
  }
  final temperatures = decodeTemperaturePayload(view, format);

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
    width: format.width,
    height: format.height,
    temperatures: temperatures,
    tMin: tMin,
    tMax: tMax,
    tAvg: sum / temperatures.length,
  );
}

bool _looksLikePhotoPayload(DeviceFileInfo file, Uint8List data) {
  final format = DevicePhotoFormat.fromPayloadSize(file.size);
  if (format == null) return false;

  final view = ByteData.sublistView(data);
  const samples = 16;
  for (var i = 0; i < samples; i++) {
    final value = _decodeTemperatureSample(view, format, i);
    if (!value.isFinite || value < -100 || value > 300) return false;
  }
  return true;
}

double _decodeTemperatureSample(
  ByteData view,
  DevicePhotoFormat format,
  int index,
) {
  return switch (format.encoding) {
    ThermalPayloadEncoding.uint16KelvinDeciCelsius =>
      view.getUint16(index * 2, Endian.little) * 0.1 - 273.15,
    ThermalPayloadEncoding.float32Celsius => view.getFloat32(
      index * 4,
      Endian.little,
    ),
  };
}

int _indexOfBytes(Uint8List haystack, Uint8List needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
