import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/temperature_series.dart';
import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../playback/uir_reader.dart';
import '../storage/gallery_entry.dart';
import '../storage/uir_repository_base.dart';
import 'thermal_export_stub.dart' show ThermalExportException;

class ThermalExporter {
  const ThermalExporter({required this.repository});

  final UirRepository repository;

  Future<void> shareUir(GalleryEntry entry) async {
    final bytes = await repository.readBytes(entry.id);
    final file = await _writeTempFile('${_safeName(entry.name)}.uir', bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: entry.name),
    );
  }

  Future<void> shareCsv(GalleryEntry entry) async {
    final bytes = await repository.readBytes(entry.id);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (points.isEmpty) {
      throw const ThermalExportException('No measurement points to export.');
    }
    final csv = temperatureSeriesCsv(frames: document.frames, points: points);
    final file = await _writeTempFile(
      '${_safeName(entry.name)}.csv',
      Uint8List.fromList(csv.codeUnits),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: entry.name),
    );
  }

  Future<void> sharePng(
    GalleryEntry entry,
    RenderSettings settings, {
    bool includePoints = true,
  }) async {
    final bytes = await repository.readBytes(entry.id);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (document.frames.isEmpty) {
      throw const ThermalExportException('No readable frames to export.');
    }
    final frame = document.frames.first.frame;
    final raster = renderThermalRaster(
      temperatures: frame.temperatures,
      width: frame.width,
      height: frame.height,
      tMin: frame.tMin,
      tMax: frame.tMax,
      scale: 12,
      settings: settings,
    );
    final png = _encodePng(
      raster,
      includePoints: includePoints,
      points: points,
      frameWidth: frame.width,
      frameHeight: frame.height,
      settings: settings,
    );
    final file = await _writeTempFile('${_safeName(entry.name)}.png', png);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: entry.name),
    );
  }

  Uint8List _encodePng(
    RasterImage raster, {
    required bool includePoints,
    required List<ThermalPoint> points,
    required int frameWidth,
    required int frameHeight,
    required RenderSettings settings,
  }) {
    final image = img.Image.fromBytes(
      width: raster.width,
      height: raster.height,
      bytes: raster.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    if (includePoints) {
      for (final point in points) {
        final display = thermalPointToDisplay(
          point,
          frameWidth,
          frameHeight,
          settings,
        );
        final x = (display.dx * raster.width).round();
        final y = (display.dy * raster.height).round();
        final color = img.ColorRgba8(
          (point.color.r * 255).round().clamp(0, 255),
          (point.color.g * 255).round().clamp(0, 255),
          (point.color.b * 255).round().clamp(0, 255),
          255,
        );
        img.drawCircle(image, x: x, y: y, radius: 8, color: color);
        img.drawLine(image, x1: x - 12, y1: y, x2: x + 12, y2: y, color: color);
        img.drawLine(image, x1: x, y1: y - 12, x2: x, y2: y + 12, color: color);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<File> _writeTempFile(String filename, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^\w .-]+'), '_');
    return cleaned.isEmpty ? 'umeko-ir-export' : cleaned;
  }
}
