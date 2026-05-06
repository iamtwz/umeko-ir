import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/device_gallery.dart';

void main() {
  test('parses device ls output', () {
    const text = '''
File: /thermal_001.bin, Size: 3072 bytes
File: note.txt, Size: 12 bytes
File: thermal_002.bin, Size: 768 bytes
Total: 2 files
''';

    final files = parseDeviceFileList(text);

    expect(files, hasLength(2));
    expect(files.first.filename, 'thermal_001.bin');
    expect(files.first.size, 3072);
    expect(files.last.filename, 'thermal_002.bin');
  });

  test('finds payload after echoed cat line and prefix text', () {
    final file = const DeviceFileInfo(
      filename: 'thermal.bin',
      size: 24 * 32 * 4,
    );
    final payload = floatPayload(32, 24);
    final response = Uint8List.fromList([
      ...utf8.encode('cat /thermal.bin\r\n'),
      ...utf8.encode('DATA:\r\n'),
      ...payload,
    ]);

    final start = findPhotoPayloadStart(file, response);

    expect(start, greaterThan(0));
    final photo = parseDevicePhoto(
      file,
      Uint8List.sublistView(response, start, start + file.size),
    );
    expect(photo.width, 32);
    expect(photo.height, 24);
    expect(photo.format, DevicePhotoFormat.float32_32x24);
    expect(photo.tMin, closeTo(20, 0.001));
  });

  test('parses 32x32 uint16 payload', () {
    final file = const DeviceFileInfo(
      filename: 'heimann.bin',
      size: 32 * 32 * 2,
    );
    final data = Uint8List(file.size);
    final view = ByteData.sublistView(data);
    for (var i = 0; i < 32 * 32; i++) {
      view.setUint16(i * 2, ((30 + 273.15) / 0.1).round(), Endian.little);
    }

    final photo = parseDevicePhoto(file, data);

    expect(photo.format, DevicePhotoFormat.uint16_32x32);
    expect(photo.tAvg, closeTo(30, 0.11));
  });

  test('rejects unsupported file sizes', () {
    expect(
      () => parseDevicePhoto(
        const DeviceFileInfo(filename: 'bad.bin', size: 17),
        Uint8List(17),
      ),
      throwsFormatException,
    );
  });
}

Uint8List floatPayload(int width, int height) {
  final data = Uint8List(width * height * 4);
  final view = ByteData.sublistView(data);
  for (var i = 0; i < width * height; i++) {
    view.setFloat32(i * 4, 20 + i / 100, Endian.little);
  }
  return data;
}
