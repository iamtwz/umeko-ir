import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'thermal_frame.dart';

const uirFormatMajorVersion = 1;
const uirFormatMinorVersion = 0;

const uirHeaderLength = 96;
const uirHeaderMagic = 0x31524955; // UIR1, little-endian.
const uirFrameMagic = 0x314d5246; // FRM1, little-endian.
const uirMetadataMagic = 0x3141544d; // MTA1, little-endian.
const uirFooterMagic = 0x31444e45; // END1, little-endian.

const uirFlagVideo = 1 << 0;
const uirFeatureMetadataRecords = 1 << 0;
const uirFeatureFrameCrc32 = 1 << 1;
const uirFeatureQuantizedCentiCelsius = 1 << 2;

enum UirFrameEncoding {
  zlibFloat32(1),
  zlibCentiCelsiusDeltas(2);

  const UirFrameEncoding(this.code);

  final int code;

  static UirFrameEncoding fromCode(int code) {
    return UirFrameEncoding.values.firstWhere(
      (encoding) => encoding.code == code,
      orElse: () =>
          throw FormatException('Unsupported UIR frame encoding $code'),
    );
  }
}

enum UirRecordIssue { badCrc, badLength, unsupportedEncoding, truncated }

class UirHeader {
  const UirHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.flags,
    required this.compatFlags,
    required this.featureFlags,
    required this.width,
    required this.height,
    required this.sensorType,
    required this.createdAt,
    required this.nominalFps,
  });

  final int majorVersion;
  final int minorVersion;
  final int flags;
  final int compatFlags;
  final int featureFlags;
  final int width;
  final int height;
  final ThermalSensorType sensorType;
  final DateTime createdAt;
  final double? nominalFps;

  bool get isVideo => flags & uirFlagVideo != 0;

  void validateSupported() {
    if (majorVersion != uirFormatMajorVersion) {
      throw FormatException(
        'Unsupported UIR major version $majorVersion.$minorVersion',
      );
    }
    const supportedFeatures =
        uirFeatureMetadataRecords |
        uirFeatureFrameCrc32 |
        uirFeatureQuantizedCentiCelsius;
    final unknownRequired = compatFlags & ~supportedFeatures;
    if (unknownRequired != 0) {
      throw FormatException(
        'Unsupported required UIR feature flags 0x${unknownRequired.toRadixString(16)}',
      );
    }
  }
}

class UirFrameRecord {
  const UirFrameRecord({
    required this.frame,
    required this.frameIndex,
    required this.elapsed,
    required this.encoding,
  });

  final ThermalFrame frame;
  final int frameIndex;
  final Duration elapsed;
  final UirFrameEncoding encoding;
}

class UirMetadataRecord {
  const UirMetadataRecord({required this.metadata, required this.recordIndex});

  final Map<String, Object?> metadata;
  final int recordIndex;
}

class UirReadIssue {
  const UirReadIssue({required this.offset, required this.issue, this.details});

  final int offset;
  final UirRecordIssue issue;
  final String? details;
}

class UirDocument {
  const UirDocument({
    required this.header,
    required this.frames,
    required this.metadataRecords,
    required this.issues,
    required this.footerFrameCount,
  });

  final UirHeader header;
  final List<UirFrameRecord> frames;
  final List<UirMetadataRecord> metadataRecords;
  final List<UirReadIssue> issues;
  final int? footerFrameCount;

  /// The effective metadata snapshot, taken from the latest metadata record.
  Map<String, Object?> get metadata => metadataRecords.isEmpty
      ? const {}
      : Map.unmodifiable(metadataRecords.last.metadata);
}

int uirSensorTypeCode(ThermalSensorType type) {
  return switch (type) {
    ThermalSensorType.heimann => 0,
    ThermalSensorType.mlx90640 => 1,
    ThermalSensorType.mlx90641 => 2,
    ThermalSensorType.legacy => 3,
  };
}

ThermalSensorType uirSensorTypeFromCode(int code) {
  return switch (code) {
    0 => ThermalSensorType.heimann,
    1 => ThermalSensorType.mlx90640,
    2 => ThermalSensorType.mlx90641,
    3 => ThermalSensorType.legacy,
    _ => throw FormatException('Unsupported UIR sensor type $code'),
  };
}

int uirTimestampMicros(DateTime timestamp) {
  return timestamp.toUtc().microsecondsSinceEpoch;
}

DateTime uirDateTimeFromMicros(int micros) {
  return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true).toLocal();
}

Uint8List uirEncodeJson(Map<String, Object?> metadata) {
  return Uint8List.fromList(utf8.encode(jsonEncode(metadata)));
}

Map<String, Object?> uirDecodeJson(List<int> bytes) {
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, Object?>) {
    throw const FormatException('UIR metadata must be a JSON object');
  }
  return value;
}

int uirCrc32(List<int> bytes, [int start = 0, int? end]) {
  final stop = end ?? bytes.length;
  if (start == 0 && stop == bytes.length) {
    return getCrc32(bytes);
  }
  return getCrc32(bytes.sublist(start, stop));
}
