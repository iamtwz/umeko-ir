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
}
