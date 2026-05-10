import '../core/temperature_unit.dart';
import '../core/thermal_frame.dart';
import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../storage/gallery_entry.dart';
import '../storage/uir_repository_base.dart';

class ThermalExportProgress {
  const ThermalExportProgress({
    required this.value,
    required this.phase,
    required this.message,
  });

  final double value;
  final String phase;
  final String message;
}

class ThermalApngExportLabels {
  const ThermalApngExportLabels({
    this.preparing = 'Preparing',
    this.preparingText = 'Preparing text',
    this.renderingFrames = 'Rendering frames',
    this.encodingApng = 'Encoding APNG',
    this.saving = 'Saving',
    this.complete = 'Complete',
    this.readingUirFile = 'Reading UIR file',
    this.renderingTextOverlays = 'Rendering {count} text overlays',
    this.renderedTextOverlay = 'Rendered text overlay {index}/{total}',
    this.renderingFrame = 'Rendering frame {index}/{total}',
    this.renderedFrame = 'Rendered frame {index}/{total}',
    this.compressingAnimatedPngFrames = 'Compressing animated PNG frames',
    this.apngEncodingComplete = 'APNG encoding complete',
    this.writingApngFile = 'Writing APNG file',
    this.apngFileSaved = 'APNG file saved',
  });

  final String preparing;
  final String preparingText;
  final String renderingFrames;
  final String encodingApng;
  final String saving;
  final String complete;
  final String readingUirFile;
  final String renderingTextOverlays;
  final String renderedTextOverlay;
  final String renderingFrame;
  final String renderedFrame;
  final String compressingAnimatedPngFrames;
  final String apngEncodingComplete;
  final String writingApngFile;
  final String apngFileSaved;
}

class ThermalExportCancelled implements Exception {
  const ThermalExportCancelled();

  @override
  String toString() => 'Export cancelled.';
}

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
    int exportScale = 32,
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
    int exportScale = 32,
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
    int exportScale = 32,
    void Function(ThermalExportProgress progress)? onProgress,
    bool Function()? shouldCancel,
    required ThermalApngExportLabels labels,
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
