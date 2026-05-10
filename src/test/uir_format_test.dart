import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/thermal_frame.dart';
import 'package:umeko_ir_flutter/src/core/uir_format.dart';
import 'package:umeko_ir_flutter/src/playback/uir_reader.dart';
import 'package:umeko_ir_flutter/src/recording/uir_writer.dart';

void main() {
  test('writes and reads UIR v1 metadata and quantized frames', () {
    final createdAt = DateTime.utc(2026, 5, 10, 12);
    final writer = UirByteWriter(
      width: 4,
      height: 3,
      sensorType: ThermalSensorType.mlx90640,
      createdAt: createdAt,
      isVideo: true,
      nominalFps: 8,
    );
    writer.writeMetadata({
      'title': 'bench capture',
      'points': [
        {'id': 'p1', 'x': 0.25, 'y': 0.5},
      ],
    });
    writer.writeFrame(_frame(0, createdAt), elapsed: Duration.zero);
    writer.writeFrame(
      _frame(1, createdAt.add(const Duration(milliseconds: 125))),
      elapsed: const Duration(milliseconds: 125),
    );

    final document = const UirReader().read(writer.finish());

    expect(document.header.majorVersion, uirFormatMajorVersion);
    expect(document.header.minorVersion, uirFormatMinorVersion);
    expect(document.header.isVideo, isTrue);
    expect(document.header.nominalFps, closeTo(8, 0.001));
    expect(document.metadata['title'], 'bench capture');
    expect(document.frames, hasLength(2));
    expect(document.frames.last.frameIndex, 1);
    expect(document.frames.last.elapsed, const Duration(milliseconds: 125));
    expect(
      document.frames.last.encoding,
      UirFrameEncoding.zlibCentiCelsiusDeltas,
    );
    expect(document.frames.last.frame.temperatures[5], closeTo(21.15, 0.005));
    expect(document.footerFrameCount, 2);
    expect(document.issues, isEmpty);
  });

  test('reads frames when footer is missing after interrupted recording', () {
    final bytes = _sampleVideo();
    final withoutFooter = Uint8List.sublistView(bytes, 0, bytes.length - 20);

    final document = const UirReader().read(withoutFooter);

    expect(document.frames, hasLength(2));
    expect(document.footerFrameCount, isNull);
    expect(document.issues, isEmpty);
  });

  test('validates footer CRC using the footer record length', () {
    final bytes = _sampleVideo();
    final footerOffset = bytes.length - 20;
    final footerLength = ByteData.sublistView(
      bytes,
      footerOffset + 4,
      footerOffset + 8,
    ).getUint32(0, Endian.little);
    final mutable = Uint8List.fromList(bytes);
    mutable[footerOffset + 8] ^= 0xff;

    final document = const UirReader().read(mutable);

    expect(footerLength, 20);
    expect(document.frames, hasLength(2));
    expect(document.footerFrameCount, isNull);
    expect(document.issues, hasLength(1));
    expect(document.issues.single.issue, UirRecordIssue.badCrc);
  });

  test('skips a corrupted frame and keeps later frames readable', () {
    final bytes = _sampleVideo();
    final firstFrameOffset = uirHeaderLength;
    final firstFrameLength = ByteData.sublistView(
      bytes,
      firstFrameOffset + 4,
      firstFrameOffset + 8,
    ).getUint32(0, Endian.little);
    final mutable = Uint8List.fromList(bytes);
    mutable[firstFrameOffset + 52] ^= 0xff;

    final document = const UirReader().read(mutable);

    expect(firstFrameLength, greaterThan(52));
    expect(document.frames, hasLength(1));
    expect(document.frames.single.frameIndex, 1);
    expect(document.issues, hasLength(1));
    expect(document.issues.single.issue, UirRecordIssue.badCrc);
  });

  test('rejects unsupported major versions explicitly', () {
    final bytes = _sampleVideo();
    final mutable = Uint8List.fromList(bytes);
    ByteData.sublistView(mutable).setUint16(4, 99, Endian.little);
    final crc = uirCrc32(mutable, 0, uirHeaderLength - 4);
    ByteData.sublistView(
      mutable,
      uirHeaderLength - 4,
      uirHeaderLength,
    ).setUint32(0, crc, Endian.little);

    expect(
      () => const UirReader().read(mutable),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported UIR major version'),
        ),
      ),
    );
  });

  test('falls back to zlib float32 when centi deltas overflow', () {
    final createdAt = DateTime.utc(2026, 5, 10, 12);
    final temperatures = Float32List.fromList([0, 700]);
    final writer = UirByteWriter(
      width: 2,
      height: 1,
      sensorType: ThermalSensorType.mlx90640,
      createdAt: createdAt,
    );
    writer.writeFrame(
      ThermalFrame(
        id: 'wide-range',
        timestamp: createdAt,
        temperatures: temperatures,
        width: 2,
        height: 1,
        sensorType: ThermalSensorType.mlx90640,
        tMin: 0,
        tMax: 700,
        tAvg: 350,
      ),
      elapsed: Duration.zero,
    );

    final document = const UirReader().read(writer.finish());

    expect(document.frames.single.encoding, UirFrameEncoding.zlibFloat32);
    expect(document.frames.single.frame.temperatures[1], closeTo(700, 0.001));
  });
}

Uint8List _sampleVideo() {
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
