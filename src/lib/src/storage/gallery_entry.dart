import '../core/thermal_frame.dart';

enum GallerySource { device, local }

enum GalleryKind { photo, video }

class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.source,
    required this.kind,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.sensorType,
    this.duration,
    this.frameCount,
  });

  final String id;
  final GallerySource source;
  final GalleryKind kind;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
  final int width;
  final int height;
  final ThermalSensorType sensorType;
  final Duration? duration;
  final int? frameCount;
}
