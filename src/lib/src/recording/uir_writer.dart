import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/thermal_frame.dart';
import '../core/uir_format.dart';

class UirByteWriter {
  UirByteWriter({
    required this.width,
    required this.height,
    required this.sensorType,
    required this.createdAt,
    this.isVideo = false,
    this.nominalFps,
  });

  final int width;
  final int height;
  final ThermalSensorType sensorType;
  final DateTime createdAt;
  final bool isVideo;
  final double? nominalFps;

  final BytesBuilder _bytes = BytesBuilder(copy: false);
  var _headerWritten = false;
  var _frameCount = 0;
  var _recordCount = 0;

  int get frameCount => _frameCount;

  Uint8List finish() {
    _ensureHeader();
    _writeFooter();
    return _bytes.takeBytes();
  }

  void writeMetadata(Map<String, Object?> metadata) {
    _ensureHeader();
    final json = uirEncodeJson(metadata);
    final compressed = Uint8List.fromList(ZLibEncoder().encode(json));
    final payload = _RecordBytes();
    payload
      ..u32(uirMetadataMagic)
      ..u32(0)
      ..u32(_recordCount)
      ..u32(json.length)
      ..u32(compressed.length)
      ..bytes(compressed);
    _finishRecord(payload);
    _recordCount += 1;
  }

  void writeFrame(
    ThermalFrame frame, {
    required Duration elapsed,
    UirFrameEncoding encoding = UirFrameEncoding.zlibCentiCelsiusDeltas,
  }) {
    _ensureHeader();
    if (frame.width != width || frame.height != height) {
      throw ArgumentError(
        'Frame dimensions ${frame.width}x${frame.height} do not match UIR '
        'header ${width}x$height',
      );
    }
    if (frame.sensorType != sensorType) {
      throw ArgumentError(
        'Frame sensor ${frame.sensorType.name} does not match UIR header '
        '${sensorType.name}',
      );
    }

    final encoded = _encodeFrame(frame.temperatures, encoding);
    final record = _RecordBytes();
    record
      ..u32(uirFrameMagic)
      ..u32(0)
      ..u32(_frameCount)
      ..i64(uirTimestampMicros(frame.timestamp))
      ..i64(elapsed.inMicroseconds)
      ..f32(frame.tMin)
      ..f32(frame.tMax)
      ..f32(frame.tAvg)
      ..u8(encoded.encoding.code)
      ..u8(0)
      ..u16(0)
      ..u32(encoded.payload.length)
      ..bytes(encoded.payload);
    _finishRecord(record);
    _frameCount += 1;
    _recordCount += 1;
  }

  void _ensureHeader() {
    if (_headerWritten) return;
    final header = _RecordBytes();
    final fpsQ16 = nominalFps == null ? 0 : (nominalFps! * 65536).round();
    header
      ..u32(uirHeaderMagic)
      ..u16(uirFormatMajorVersion)
      ..u16(uirFormatMinorVersion)
      ..u32(isVideo ? uirFlagVideo : 0)
      ..u32(0)
      ..u32(
        uirFeatureMetadataRecords |
            uirFeatureFrameCrc32 |
            uirFeatureQuantizedCentiCelsius,
      )
      ..u16(width)
      ..u16(height)
      ..u8(uirSensorTypeCode(sensorType))
      ..u8(0)
      ..u16(0)
      ..i64(uirTimestampMicros(createdAt))
      ..u32(fpsQ16);
    while (header.length < uirHeaderLength - 4) {
      header.u8(0);
    }
    final headerBytes = header.toBytes();
    header.u32(uirCrc32(headerBytes));
    _bytes.add(header.toBytes());
    _headerWritten = true;
  }

  _EncodedFrame _encodeFrame(
    Float32List temperatures,
    UirFrameEncoding preferredEncoding,
  ) {
    if (preferredEncoding == UirFrameEncoding.zlibCentiCelsiusDeltas) {
      final deltas = _tryEncodeCentiDeltas(temperatures);
      if (deltas != null) {
        return _EncodedFrame(
          encoding: UirFrameEncoding.zlibCentiCelsiusDeltas,
          payload: deltas,
        );
      }
    }
    return _EncodedFrame(
      encoding: UirFrameEncoding.zlibFloat32,
      payload: _encodeFloat32(temperatures),
    );
  }

  Uint8List _encodeFloat32(Float32List temperatures) {
    final raw = Uint8List(temperatures.length * 4);
    final view = ByteData.sublistView(raw);
    for (var i = 0; i < temperatures.length; i++) {
      view.setFloat32(i * 4, temperatures[i], Endian.little);
    }
    return Uint8List.fromList(ZLibEncoder().encode(raw));
  }

  Uint8List? _tryEncodeCentiDeltas(Float32List temperatures) {
    var minCenti = 2147483647;
    final centi = Int32List(temperatures.length);
    for (var i = 0; i < temperatures.length; i++) {
      final value = (temperatures[i] * 100).round();
      centi[i] = value;
      if (value < minCenti) minCenti = value;
    }

    final raw = Uint8List(4 + temperatures.length * 2);
    final view = ByteData.sublistView(raw);
    view.setInt32(0, minCenti, Endian.little);
    for (var i = 0; i < centi.length; i++) {
      final delta = centi[i] - minCenti;
      if (delta < 0 || delta > 65535) {
        return null;
      }
      view.setUint16(4 + i * 2, delta, Endian.little);
    }
    return Uint8List.fromList(ZLibEncoder().encode(raw));
  }

  void _finishRecord(_RecordBytes record) {
    final bytes = record.toBytes();
    final view = ByteData.sublistView(bytes);
    view.setUint32(4, bytes.length + 4, Endian.little);
    final crc = uirCrc32(bytes);
    _bytes
      ..add(bytes)
      ..add(_uint32Bytes(crc));
  }

  void _writeFooter() {
    final footer = _RecordBytes()
      ..u32(uirFooterMagic)
      ..u32(20)
      ..u32(_frameCount)
      ..u32(_recordCount);
    final bytes = footer.toBytes();
    _bytes
      ..add(bytes)
      ..add(_uint32Bytes(uirCrc32(bytes)));
  }
}

class _EncodedFrame {
  const _EncodedFrame({required this.encoding, required this.payload});

  final UirFrameEncoding encoding;
  final Uint8List payload;
}

Uint8List _uint32Bytes(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
  return bytes;
}

class _RecordBytes {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  int get length => _builder.length;

  void u8(int value) => _builder.add([value & 0xff]);

  void u16(int value) {
    final bytes = Uint8List(2);
    ByteData.sublistView(bytes).setUint16(0, value, Endian.little);
    _builder.add(bytes);
  }

  void u32(int value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
    _builder.add(bytes);
  }

  void i64(int value) {
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setInt64(0, value, Endian.little);
    _builder.add(bytes);
  }

  void f32(double value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setFloat32(0, value, Endian.little);
    _builder.add(bytes);
  }

  void bytes(Uint8List bytes) => _builder.add(bytes);

  Uint8List toBytes() => _builder.toBytes();
}
