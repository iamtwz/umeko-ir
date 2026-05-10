import '../core/temperature_unit.dart';
import '../core/thermal_frame.dart';
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

  Future<void> shareCsv(
    GalleryEntry entry, [
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
  ]) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> shareCsvText({required String name, required String csv}) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> sharePng(
    GalleryEntry entry,
    RenderSettings settings, {
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    bool includePoints = true,
    bool includeLegend = true,
  }) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> shareFramePng({
    required String name,
    required ThermalFrame frame,
    required RenderSettings settings,
    required List<ThermalPoint> points,
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    bool includePoints = true,
    bool includeLegend = true,
  }) async {
    throw const ThermalExportException(
      'Export sharing is not implemented on this platform yet.',
    );
  }

  Future<void> shareApng(
    GalleryEntry entry,
    RenderSettings settings, {
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    bool includePoints = true,
    bool includeLegend = true,
    void Function(int completed, int total)? onProgress,
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
