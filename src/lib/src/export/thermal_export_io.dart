import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/temperature_series.dart';
import '../core/temperature_unit.dart';
import '../core/thermal_frame.dart';
import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../core/uir_format.dart';
import '../playback/uir_reader.dart';
import '../storage/gallery_entry.dart';
import '../storage/uir_repository_base.dart';
import 'thermal_export_stub.dart' show ThermalExportException;

class ThermalExporter {
  const ThermalExporter({required this.repository});

  static const _pngExportScale = 32;
  static const _apngExportScale = 16;
  static const _previewScale = 12;

  final UirRepository repository;

  Future<void> shareUir(GalleryEntry entry) async {
    final bytes = await repository.readBytes(entry.id);
    await _saveFile(
      suggestedName: '${_safeName(entry.name)}.uir',
      bytes: bytes,
      typeGroup: const XTypeGroup(
        label: 'UIR',
        extensions: ['uir'],
        mimeTypes: ['application/octet-stream'],
      ),
    );
  }

  Future<void> shareCsv(
    GalleryEntry entry, [
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
  ]) async {
    final bytes = await repository.readBytes(entry.id);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (points.isEmpty) {
      throw const ThermalExportException('No measurement points to export.');
    }
    final csv = temperatureSeriesCsv(
      frames: document.frames,
      points: points,
      temperatureUnit: temperatureUnit,
    );
    await _saveFile(
      suggestedName: '${_safeName(entry.name)}.csv',
      bytes: Uint8List.fromList(csv.codeUnits),
      typeGroup: const XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
        mimeTypes: ['text/csv'],
      ),
    );
  }

  Future<void> shareCsvText({required String name, required String csv}) async {
    await _saveFile(
      suggestedName: '${_safeName(name)}.csv',
      bytes: Uint8List.fromList(csv.codeUnits),
      typeGroup: const XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
        mimeTypes: ['text/csv'],
      ),
    );
  }

  Future<void> sharePng(
    GalleryEntry entry,
    RenderSettings settings, {
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    bool includePoints = true,
    bool includeLegend = true,
  }) async {
    final bytes = await repository.readBytes(entry.id);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (document.frames.isEmpty) {
      throw const ThermalExportException('No readable frames to export.');
    }
    final frame = document.frames.first.frame;
    final png = await _renderFramePng(
      frame,
      settings,
      points: points,
      includePoints: includePoints,
      includeLegend: includeLegend,
      temperatureUnit: temperatureUnit,
      exportScale: _pngExportScale,
    );
    await _saveFile(
      suggestedName: '${_safeName(entry.name)}.png',
      bytes: png,
      typeGroup: const XTypeGroup(
        label: 'PNG',
        extensions: ['png'],
        mimeTypes: ['image/png'],
        uniformTypeIdentifiers: ['public.png'],
      ),
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
    final png = await _renderFramePng(
      frame,
      settings,
      points: points,
      includePoints: includePoints,
      includeLegend: includeLegend,
      temperatureUnit: temperatureUnit,
      exportScale: _pngExportScale,
    );
    await _saveFile(
      suggestedName: '${_safeName(name)}.png',
      bytes: png,
      typeGroup: const XTypeGroup(
        label: 'PNG',
        extensions: ['png'],
        mimeTypes: ['image/png'],
        uniformTypeIdentifiers: ['public.png'],
      ),
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
    final bytes = await repository.readBytes(entry.id);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (document.frames.length < 2) {
      throw const ThermalExportException('No video frames to export.');
    }
    img.Image? animation;
    onProgress?.call(0, document.frames.length);
    for (var i = 0; i < document.frames.length; i++) {
      final record = document.frames[i];
      final png = await _renderFramePng(
        record.frame,
        settings,
        points: points,
        includePoints: includePoints,
        includeLegend: includeLegend,
        temperatureUnit: temperatureUnit,
        exportScale: _apngExportScale,
      );
      final frameImage = img.decodePng(png);
      if (frameImage == null) {
        throw const ThermalExportException('Failed to encode APNG frame.');
      }
      frameImage.frameDuration = _frameDurationMs(document.frames, i);
      if (animation == null) {
        animation = frameImage
          ..frameType = img.FrameType.animation
          ..loopCount = 0;
      } else {
        animation.addFrame(frameImage);
      }
      onProgress?.call(i + 1, document.frames.length);
    }
    final apng = img.PngEncoder().encode(animation!);
    await _saveFile(
      suggestedName: '${_safeName(entry.name)}.png',
      bytes: apng,
      typeGroup: const XTypeGroup(
        label: 'Animated PNG',
        extensions: ['png'],
        mimeTypes: ['image/png'],
        uniformTypeIdentifiers: ['public.png'],
      ),
    );
  }

  Future<Uint8List> _renderFramePng(
    ThermalFrame frame,
    RenderSettings settings, {
    required List<ThermalPoint> points,
    required bool includePoints,
    required bool includeLegend,
    required TemperatureUnit temperatureUnit,
    required int exportScale,
  }) async {
    final raster = renderThermalRaster(
      temperatures: frame.temperatures,
      width: frame.width,
      height: frame.height,
      tMin: frame.tMin,
      tMax: frame.tMax,
      scale: exportScale,
      settings: settings,
    );
    return _encodePng(
      raster,
      includePoints: includePoints,
      includeLegend: includeLegend,
      points: points,
      frame: frame,
      frameWidth: frame.width,
      frameHeight: frame.height,
      settings: settings,
      temperatureUnit: temperatureUnit,
      exportScale: exportScale,
    );
  }

  Future<Uint8List> _encodePng(
    RasterImage raster, {
    required bool includePoints,
    required bool includeLegend,
    required List<ThermalPoint> points,
    required ThermalFrame frame,
    required int frameWidth,
    required int frameHeight,
    required RenderSettings settings,
    required TemperatureUnit temperatureUnit,
    required int exportScale,
  }) async {
    final image = await _decodeRasterImage(raster);
    final size = Size(raster.width.toDouble(), raster.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final styleScale = exportScale / _previewScale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
    final extrema = _findExtrema(
      frame.temperatures,
      frameWidth,
      frameHeight,
      settings,
    );
    if (includeLegend) {
      _drawStats(canvas, size, extrema, temperatureUnit, styleScale);
      _drawExtremaAnchors(
        canvas,
        size,
        extrema,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        settings: settings,
        temperatureUnit: temperatureUnit,
        styleScale: styleScale,
      );
    }
    if (includePoints) {
      for (final point in points) {
        final display = thermalPointToDisplay(
          point,
          frameWidth,
          frameHeight,
          settings,
        );
        final center = Offset(
          display.dx * size.width,
          display.dy * size.height,
        );
        _drawAnchor(
          canvas,
          size,
          center,
          '${point.label} ${temperatureUnit.format(sampleThermalPoint(frame, point))}',
          point.color,
          styleScale,
          radius: 8,
          arm: 12,
        );
      }
    }
    final picture = recorder.endRecording();
    final output = await picture.toImage(raster.width, raster.height);
    final byteData = await output.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    output.dispose();
    picture.dispose();
    if (byteData == null) {
      throw const ThermalExportException('Failed to encode PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<ui.Image> _decodeRasterImage(RasterImage raster) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      raster.rgba,
      raster.width,
      raster.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _drawStats(
    Canvas canvas,
    Size size,
    _ExportExtrema extrema,
    TemperatureUnit temperatureUnit,
    double styleScale,
  ) {
    final x = 8.0 * styleScale;
    var y = 8.0 * styleScale;
    for (final line in [
      'MAX ${temperatureUnit.format(extrema.max)}',
      'MIN ${temperatureUnit.format(extrema.min)}',
      'AVG ${temperatureUnit.format(extrema.avg)}',
    ]) {
      final textPainter = _textPainter(line, Colors.white, 12 * styleScale);
      final rect = Rect.fromLTWH(
        x,
        y - 3 * styleScale,
        textPainter.width + 10 * styleScale,
        textPainter.height + 6 * styleScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(5 * styleScale)),
        Paint()..color = Colors.black.withValues(alpha: 0.62),
      );
      textPainter.paint(canvas, Offset(x + 5 * styleScale, y));
      y += textPainter.height + 8 * styleScale;
    }
  }

  void _drawExtremaAnchors(
    Canvas canvas,
    Size size,
    _ExportExtrema extrema, {
    required int frameWidth,
    required int frameHeight,
    required RenderSettings settings,
    required TemperatureUnit temperatureUnit,
    required double styleScale,
  }) {
    final oriented = displayOrientedSize(
      frameWidth,
      frameHeight,
      settings.rotation,
    );
    final scaleX = size.width / oriented.width;
    final scaleY = size.height / oriented.height;
    _drawAnchor(
      canvas,
      size,
      Offset(
        extrema.maxX * scaleX + scaleX / 2,
        extrema.maxY * scaleY + scaleY / 2,
      ),
      temperatureUnit.format(extrema.max),
      const Color(0xffff5252),
      styleScale,
      radius: 7,
      arm: 11,
    );
    _drawAnchor(
      canvas,
      size,
      Offset(
        extrema.minX * scaleX + scaleX / 2,
        extrema.minY * scaleY + scaleY / 2,
      ),
      temperatureUnit.format(extrema.min),
      const Color(0xff60a5fa),
      styleScale,
      radius: 7,
      arm: 11,
    );
  }

  void _drawAnchor(
    Canvas canvas,
    Size size,
    Offset center,
    String label,
    Color color,
    double styleScale, {
    required double radius,
    required double arm,
  }) {
    final scaledRadius = radius * styleScale;
    final scaledArm = arm * styleScale;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * styleScale;
    canvas.drawCircle(center, scaledRadius, paint);
    canvas.drawLine(
      center.translate(-scaledArm, 0),
      center.translate(scaledArm, 0),
      paint,
    );
    canvas.drawLine(
      center.translate(0, -scaledArm),
      center.translate(0, scaledArm),
      paint,
    );
    _drawLabel(
      canvas,
      label,
      center.translate(10 * styleScale, -26 * styleScale),
      color,
      size,
      styleScale,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String label,
    Offset offset,
    Color color,
    Size size,
    double styleScale,
  ) {
    final textPainter = _textPainter(label, Colors.white, 12 * styleScale);
    final minX = 4.0 * styleScale;
    final maxX = size.width - textPainter.width - 14 * styleScale;
    final minY = 4.0 * styleScale;
    final maxY = size.height - textPainter.height - 10 * styleScale;
    final dx = offset.dx.clamp(minX, maxX < minX ? minX : maxX);
    final dy = offset.dy.clamp(minY, maxY < minY ? minY : maxY);
    final rect = Rect.fromLTWH(
      dx - 5 * styleScale,
      dy - 3 * styleScale,
      textPainter.width + 10 * styleScale,
      textPainter.height + 6 * styleScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(5 * styleScale)),
      Paint()..color = color.withValues(alpha: 0.82),
    );
    textPainter.paint(canvas, Offset(dx, dy));
  }

  TextPainter _textPainter(String text, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  }

  int _frameDurationMs(List<UirFrameRecord> frames, int index) {
    Duration? duration;
    if (index + 1 < frames.length) {
      duration = frames[index + 1].elapsed - frames[index].elapsed;
    } else if (index > 0) {
      duration = frames[index].elapsed - frames[index - 1].elapsed;
    }
    final milliseconds = duration?.inMilliseconds ?? 100;
    return milliseconds.clamp(10, 1000);
  }

  Future<void> _saveFile({
    required String suggestedName,
    required Uint8List bytes,
    required XTypeGroup typeGroup,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: [typeGroup],
      suggestedName: suggestedName,
      canCreateDirectories: true,
    );
    if (location == null) return;
    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
  }

  String _safeName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^\w .-]+'), '_');
    return cleaned.isEmpty ? 'umeko-ir-export' : cleaned;
  }
}

_ExportExtrema _findExtrema(
  Float32List temperatures,
  int sourceWidth,
  int sourceHeight,
  RenderSettings settings,
) {
  final oriented = orientForDisplay(
    temperatures,
    sourceWidth,
    sourceHeight,
    rotation: settings.rotation,
    hflip: settings.hflip,
    vflip: settings.vflip,
  );
  final size = displayOrientedSize(
    sourceWidth,
    sourceHeight,
    settings.rotation,
  );
  var min = double.infinity;
  var max = double.negativeInfinity;
  var minIndex = 0;
  var maxIndex = 0;
  var sum = 0.0;
  for (var i = 0; i < oriented.length; i++) {
    final value = oriented[i];
    if (value < min) {
      min = value;
      minIndex = i;
    }
    if (value > max) {
      max = value;
      maxIndex = i;
    }
    sum += value;
  }
  return _ExportExtrema(
    min: min,
    max: max,
    avg: sum / oriented.length,
    minX: minIndex % size.width,
    minY: minIndex ~/ size.width,
    maxX: maxIndex % size.width,
    maxY: maxIndex ~/ size.width,
  );
}

class _ExportExtrema {
  const _ExportExtrema({
    required this.min,
    required this.max,
    required this.avg,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double min;
  final double max;
  final double avg;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
}
