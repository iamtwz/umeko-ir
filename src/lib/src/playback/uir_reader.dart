import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../core/thermal_frame.dart';
import '../core/uir_format.dart';

/// How the reader reacts when it encounters a malformed or CRC-failing record.
enum UirReadPolicy {
  /// Skip the record, collect it in [UirDocument.issues] and keep reading.
  /// This is the default and preserves partial playback when a file is
  /// truncated or contains a single corrupted frame.
  skipBadRecords,

  /// Throw [UirCorruptedException] on the first bad record.
  abortOnError,
}

class UirCorruptedException implements Exception {
  const UirCorruptedException(this.issue);

  final UirReadIssue issue;

  @override
  String toString() =>
      'UIR record corrupted at offset ${issue.offset}: '
      '${issue.issue.name}${issue.details != null ? " (${issue.details})" : ""}';
}

class UirReader {
  const UirReader({this.policy = UirReadPolicy.skipBadRecords});

  final UirReadPolicy policy;

  UirDocument read(Uint8List bytes) {
    if (bytes.length < uirHeaderLength) {
      throw const FormatException('UIR file is too short');
    }
    final header = _readHeader(bytes);
    header.validateSupported();

    final frames = <UirFrameRecord>[];
    final metadataRecords = <UirMetadataRecord>[];
    final issues = <UirReadIssue>[];
    int? footerFrameCount;
    var offset = uirHeaderLength;

    while (offset + 8 <= bytes.length) {
      final view = ByteData.sublistView(bytes, offset);
      final magic = view.getUint32(0, Endian.little);
      final length = view.getUint32(4, Endian.little);
      if (magic == uirFooterMagic) {
        if (_recordCrcOk(bytes, offset, length)) {
          footerFrameCount = view.getUint32(8, Endian.little);
        } else {
          _recordIssue(
            issues,
            UirReadIssue(offset: offset, issue: UirRecordIssue.badCrc),
          );
        }
        break;
      }
      if (magic != uirFrameMagic && magic != uirMetadataMagic) {
        final next = _findNextMagic(bytes, offset + 1);
        if (next == -1) break;
        _recordIssue(
          issues,
          UirReadIssue(offset: offset, issue: UirRecordIssue.badLength),
        );
        offset = next;
        continue;
      }
      if (length < 12 || offset + length > bytes.length) {
        _recordIssue(
          issues,
          UirReadIssue(offset: offset, issue: UirRecordIssue.truncated),
        );
        break;
      }
      if (!_recordCrcOk(bytes, offset, length)) {
        _recordIssue(
          issues,
          UirReadIssue(offset: offset, issue: UirRecordIssue.badCrc),
        );
        offset += length;
        continue;
      }
      try {
        if (magic == uirFrameMagic) {
          frames.add(_readFrame(bytes, offset, length, header));
        } else {
          metadataRecords.add(_readMetadata(bytes, offset, length));
        }
      } on FormatException catch (error) {
        _recordIssue(
          issues,
          UirReadIssue(
            offset: offset,
            issue: UirRecordIssue.unsupportedEncoding,
            details: error.message,
          ),
        );
      }
      offset += length;
    }

    return UirDocument(
      header: header,
      frames: List.unmodifiable(frames),
      metadataRecords: List.unmodifiable(metadataRecords),
      issues: List.unmodifiable(issues),
      footerFrameCount: footerFrameCount,
    );
  }

  void _recordIssue(List<UirReadIssue> issues, UirReadIssue issue) {
    if (policy == UirReadPolicy.abortOnError) {
      throw UirCorruptedException(issue);
    }
    issues.add(issue);
    assert(() {
      debugPrint(
        'UirReader: issue ${issue.issue.name} at offset ${issue.offset}'
        '${issue.details != null ? " (${issue.details})" : ""}',
      );
      return true;
    }());
  }

  UirHeader _readHeader(Uint8List bytes) {
    final headerCrc = ByteData.sublistView(
      bytes,
      uirHeaderLength - 4,
      uirHeaderLength,
    ).getUint32(0, Endian.little);
    final actualCrc = uirCrc32(bytes, 0, uirHeaderLength - 4);
    if (headerCrc != actualCrc) {
      throw const FormatException('UIR header CRC mismatch');
    }
    final view = ByteData.sublistView(bytes, 0, uirHeaderLength);
    final magic = view.getUint32(0, Endian.little);
    if (magic != uirHeaderMagic) {
      throw const FormatException('Invalid UIR magic');
    }
    final fpsQ16 = view.getUint32(36, Endian.little);
    return UirHeader(
      majorVersion: view.getUint16(4, Endian.little),
      minorVersion: view.getUint16(6, Endian.little),
      flags: view.getUint32(8, Endian.little),
      compatFlags: view.getUint32(12, Endian.little),
      featureFlags: view.getUint32(16, Endian.little),
      width: view.getUint16(20, Endian.little),
      height: view.getUint16(22, Endian.little),
      sensorType: uirSensorTypeFromCode(view.getUint8(24)),
      createdAt: uirDateTimeFromMicros(view.getInt64(28, Endian.little)),
      nominalFps: fpsQ16 == 0 ? null : fpsQ16 / 65536,
    );
  }

  UirFrameRecord _readFrame(
    Uint8List bytes,
    int offset,
    int recordLength,
    UirHeader header,
  ) {
    if (recordLength < 52) {
      throw const FormatException('UIR frame record is too short');
    }
    final view = ByteData.sublistView(bytes, offset);
    final frameIndex = view.getUint32(8, Endian.little);
    final timestamp = uirDateTimeFromMicros(view.getInt64(12, Endian.little));
    final elapsed = Duration(microseconds: view.getInt64(20, Endian.little));
    final tMin = view.getFloat32(28, Endian.little);
    final tMax = view.getFloat32(32, Endian.little);
    final tAvg = view.getFloat32(36, Endian.little);
    final encoding = UirFrameEncoding.fromCode(view.getUint8(40));
    final payloadLength = view.getUint32(44, Endian.little);
    final count = header.width * header.height;
    final maxPayloadLength = _maxInt(64, count * 8);
    if (payloadLength > recordLength - 52 || payloadLength > maxPayloadLength) {
      throw const FormatException('UIR frame payload length is out of range');
    }
    final payloadStart = offset + 48;
    final compressed = Uint8List.sublistView(
      bytes,
      payloadStart,
      payloadStart + payloadLength,
    );
    final temperatures = switch (encoding) {
      UirFrameEncoding.zlibFloat32 => _decodeFloat32(compressed, count),
      UirFrameEncoding.zlibCentiCelsiusDeltas => _decodeCentiDeltas(
        compressed,
        count,
      ),
    };
    return UirFrameRecord(
      frameIndex: frameIndex,
      elapsed: elapsed,
      encoding: encoding,
      frame: ThermalFrame(
        id: 'uir-$frameIndex',
        timestamp: timestamp,
        temperatures: temperatures,
        width: header.width,
        height: header.height,
        sensorType: header.sensorType,
        tMin: tMin,
        tMax: tMax,
        tAvg: tAvg,
      ),
    );
  }

  UirMetadataRecord _readMetadata(
    Uint8List bytes,
    int offset,
    int recordLength,
  ) {
    if (recordLength < 24) {
      throw const FormatException('UIR metadata record is too short');
    }
    final view = ByteData.sublistView(bytes, offset);
    final recordIndex = view.getUint32(8, Endian.little);
    final uncompressedLength = view.getUint32(12, Endian.little);
    final compressedLength = view.getUint32(16, Endian.little);
    if (compressedLength > recordLength - 24 ||
        uncompressedLength > _maxMetadataBytes) {
      throw const FormatException('UIR metadata length is out of range');
    }
    final compressed = Uint8List.sublistView(
      bytes,
      offset + 20,
      offset + 20 + compressedLength,
    );
    final jsonBytes = _inflate(compressed);
    if (jsonBytes.length != uncompressedLength) {
      throw const FormatException('UIR metadata length mismatch');
    }
    return UirMetadataRecord(
      recordIndex: recordIndex,
      metadata: uirDecodeJson(jsonBytes),
    );
  }

  Float32List _decodeFloat32(Uint8List compressed, int count) {
    final raw = _inflate(compressed);
    if (raw.length != count * 4) {
      throw const FormatException('UIR float32 payload length mismatch');
    }
    final view = ByteData.sublistView(raw);
    final temperatures = Float32List(count);
    for (var i = 0; i < count; i++) {
      temperatures[i] = view.getFloat32(i * 4, Endian.little);
    }
    return temperatures;
  }

  Float32List _decodeCentiDeltas(Uint8List compressed, int count) {
    final raw = _inflate(compressed);
    if (raw.length != 4 + count * 2) {
      throw const FormatException('UIR centi payload length mismatch');
    }
    final view = ByteData.sublistView(raw);
    final base = view.getInt32(0, Endian.little);
    final temperatures = Float32List(count);
    for (var i = 0; i < count; i++) {
      temperatures[i] = (base + view.getUint16(4 + i * 2, Endian.little)) / 100;
    }
    return temperatures;
  }

  bool _recordCrcOk(Uint8List bytes, int offset, int length) {
    if (length < 12 || offset + length > bytes.length) return false;
    final expected = ByteData.sublistView(
      bytes,
      offset + length - 4,
      offset + length,
    ).getUint32(0, Endian.little);
    return expected == uirCrc32(bytes, offset, offset + length - 4);
  }

  int _findNextMagic(Uint8List bytes, int start) {
    for (var i = start; i + 4 <= bytes.length; i++) {
      final value = ByteData.sublistView(
        bytes,
        i,
        i + 4,
      ).getUint32(0, Endian.little);
      if (value == uirFrameMagic ||
          value == uirMetadataMagic ||
          value == uirFooterMagic) {
        return i;
      }
    }
    return -1;
  }

  Uint8List _inflate(Uint8List compressed) {
    return ZLibDecoder().decodeBytes(compressed);
  }
}

const _maxMetadataBytes = 1024 * 1024;

int _maxInt(int a, int b) => a > b ? a : b;
