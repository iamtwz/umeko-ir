import '../core/thermal_frame.dart';
import '../core/uir_format.dart';
import 'gallery_entry.dart';

class UirManifest {
  const UirManifest({
    required this.id,
    required this.filename,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.sensorType,
    required this.frameCount,
    this.duration,
  });

  factory UirManifest.fromDocument({
    required String id,
    required String filename,
    required String name,
    required int sizeBytes,
    required UirDocument document,
  }) {
    final frames = document.frames;
    final kind = document.header.isVideo || frames.length > 1
        ? GalleryKind.video
        : GalleryKind.photo;
    final duration = frames.isEmpty ? null : frames.last.elapsed;
    return UirManifest(
      id: id,
      filename: filename,
      name: name,
      kind: kind,
      createdAt: document.header.createdAt,
      sizeBytes: sizeBytes,
      width: document.header.width,
      height: document.header.height,
      sensorType: document.header.sensorType,
      frameCount: frames.length,
      duration: duration,
    );
  }

  factory UirManifest.fromJson(Map<String, Object?> json) {
    return UirManifest(
      id: json['id'] as String,
      filename: json['filename'] as String,
      name: json['name'] as String,
      kind: GalleryKind.values.byName(json['kind'] as String),
      createdAt: DateTime.fromMicrosecondsSinceEpoch(
        json['createdAtMicros'] as int,
        isUtc: true,
      ).toLocal(),
      sizeBytes: json['sizeBytes'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      sensorType: ThermalSensorType.values.byName(json['sensorType'] as String),
      frameCount: json['frameCount'] as int,
      duration: json['durationMicros'] == null
          ? null
          : Duration(microseconds: json['durationMicros'] as int),
    );
  }

  final String id;
  final String filename;
  final String name;
  final GalleryKind kind;
  final DateTime createdAt;
  final int sizeBytes;
  final int width;
  final int height;
  final ThermalSensorType sensorType;
  final int frameCount;
  final Duration? duration;

  GalleryEntry toGalleryEntry() {
    return GalleryEntry(
      id: id,
      source: GallerySource.local,
      kind: kind,
      name: name,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      sensorType: sensorType,
      duration: duration,
      frameCount: frameCount,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'filename': filename,
      'name': name,
      'kind': kind.name,
      'createdAtMicros': createdAt.toUtc().microsecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'width': width,
      'height': height,
      'sensorType': sensorType.name,
      'frameCount': frameCount,
      'durationMicros': duration?.inMicroseconds,
    };
  }
}
