import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../storage/gallery_entry.dart';
import '../storage/uir_repository_base.dart';

class ThermalExporter {
  const ThermalExporter({required this.repository});

  final UirRepository repository;

  Future<void> shareUir(GalleryEntry entry) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> shareCsv(GalleryEntry entry, List<ThermalPoint> points) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> sharePng(
    GalleryEntry entry,
    List<ThermalPoint> points,
    RenderSettings settings, {
    bool includePoints = true,
  }) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }
}

class ThermalExportException implements Exception {
  const ThermalExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
