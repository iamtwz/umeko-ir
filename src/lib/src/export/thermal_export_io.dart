import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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

  String renderingTextOverlaysMessage(int count) {
    return _formatExportTemplate(renderingTextOverlays, count: count);
  }

  String renderedTextOverlayMessage(int index, int total) {
    return _formatExportTemplate(
      renderedTextOverlay,
      index: index,
      total: total,
    );
  }

  String renderingFrameMessage(int index, int total) {
    return _formatExportTemplate(renderingFrame, index: index, total: total);
  }

  String renderedFrameMessage(int index, int total) {
    return _formatExportTemplate(renderedFrame, index: index, total: total);
  }
}

String _formatExportTemplate(
  String template, {
  int? count,
  int? index,
  int? total,
}) {
  return template
      .replaceAll('{count}', count?.toString() ?? '')
      .replaceAll('{index}', index?.toString() ?? '')
      .replaceAll('{total}', total?.toString() ?? '');
}

class ThermalExportCancelled implements Exception {
  const ThermalExportCancelled();

  @override
  String toString() => 'Export cancelled.';
}

class ThermalExporter {
  const ThermalExporter({required this.repository});

  static const _defaultExportScale = 32;
  static const _previewScale = 12;
  static const _statsFontFamily = 'Menlo';
  static const _statsFontFallback = [
    'SF Mono',
    'Monaco',
    'Courier New',
    'Courier',
  ];

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
    int exportScale = _defaultExportScale,
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
      exportScale: exportScale,
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
    int exportScale = _defaultExportScale,
  }) async {
    final png = await _renderFramePng(
      frame,
      settings,
      points: points,
      includePoints: includePoints,
      includeLegend: includeLegend,
      temperatureUnit: temperatureUnit,
      exportScale: exportScale,
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
    int exportScale = _defaultExportScale,
    void Function(ThermalExportProgress progress)? onProgress,
    bool Function()? shouldCancel,
    ThermalApngExportLabels labels = const ThermalApngExportLabels(),
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Animated PNG',
          extensions: ['png'],
          mimeTypes: ['image/png'],
          uniformTypeIdentifiers: ['public.png'],
        ),
      ],
      suggestedName: '${_safeName(entry.name)}.png',
      canCreateDirectories: true,
    );
    if (location == null) return;
    _throwIfCancelled(shouldCancel);

    onProgress?.call(
      ThermalExportProgress(
        value: 0.01,
        phase: labels.preparing,
        message: labels.readingUirFile,
      ),
    );
    final bytes = await repository.readBytes(entry.id);
    _throwIfCancelled(shouldCancel);
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (document.frames.length < 2) {
      throw const ThermalExportException('No video frames to export.');
    }
    final textSprites = await _prepareApngTextSprites(
      frames: document.frames,
      points: points,
      settings: settings,
      temperatureUnit: temperatureUnit,
      includePoints: includePoints,
      includeLegend: includeLegend,
      exportScale: exportScale,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
      labels: labels,
    );
    _throwIfCancelled(shouldCancel);
    final apng = await _encodeApngInIsolate(
      bytes: bytes,
      settings: settings,
      temperatureUnit: temperatureUnit,
      includePoints: includePoints,
      includeLegend: includeLegend,
      exportScale: exportScale,
      textSprites: textSprites,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
      labels: labels,
    );
    _throwIfCancelled(shouldCancel);
    onProgress?.call(
      ThermalExportProgress(
        value: 0.95,
        phase: labels.saving,
        message: labels.writingApngFile,
      ),
    );
    await File(location.path).writeAsBytes(apng, flush: true);
    _throwIfCancelled(shouldCancel);
    onProgress?.call(
      ThermalExportProgress(
        value: 1,
        phase: labels.complete,
        message: labels.apngFileSaved,
      ),
    );
  }

  Future<Map<String, _ApngTextSprite>> _prepareApngTextSprites({
    required List<UirFrameRecord> frames,
    required List<ThermalPoint> points,
    required RenderSettings settings,
    required TemperatureUnit temperatureUnit,
    required bool includePoints,
    required bool includeLegend,
    required int exportScale,
    required void Function(ThermalExportProgress progress)? onProgress,
    required bool Function()? shouldCancel,
    required ThermalApngExportLabels labels,
  }) async {
    final labelRecords = <String, ({String text, bool mono})>{};
    void addLabel(String text, {bool mono = false}) {
      labelRecords[_textSpriteKey(text, mono: mono)] = (text: text, mono: mono);
    }

    for (final record in frames) {
      final frame = record.frame;
      final extrema = _findExtrema(
        frame.temperatures,
        frame.width,
        frame.height,
        settings,
      );
      if (includeLegend) {
        addLabel('MAX ${temperatureUnit.format(extrema.max)}', mono: true);
        addLabel('MIN ${temperatureUnit.format(extrema.min)}', mono: true);
        addLabel('AVG ${temperatureUnit.format(extrema.avg)}', mono: true);
        addLabel(temperatureUnit.format(extrema.max));
        addLabel(temperatureUnit.format(extrema.min));
      }
      if (includePoints) {
        for (final point in points) {
          addLabel(
            '${point.label} ${temperatureUnit.format(sampleThermalPoint(frame, point))}',
          );
        }
      }
    }

    if (labelRecords.isEmpty) return const {};
    onProgress?.call(
      ThermalExportProgress(
        value: 0.02,
        phase: labels.preparingText,
        message: labels.renderingTextOverlaysMessage(labelRecords.length),
      ),
    );

    final sprites = <String, _ApngTextSprite>{};
    var index = 0;
    final styleScale = exportScale / _previewScale;
    for (final entry in labelRecords.entries) {
      _throwIfCancelled(shouldCancel);
      sprites[entry.key] = await _renderTextSprite(
        entry.value.text,
        styleScale: styleScale,
        mono: entry.value.mono,
      );
      index += 1;
      if (index == labelRecords.length || index % 12 == 0) {
        onProgress?.call(
          ThermalExportProgress(
            value: 0.02 + 0.12 * (index / labelRecords.length),
            phase: labels.preparingText,
            message: labels.renderedTextOverlayMessage(
              index,
              labelRecords.length,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    _throwIfCancelled(shouldCancel);
    return sprites;
  }

  Future<_ApngTextSprite> _renderTextSprite(
    String text, {
    required double styleScale,
    required bool mono,
  }) async {
    final painter = _textPainter(
      text,
      Colors.white,
      12 * styleScale,
      mono: mono,
    );
    final width = painter.width.ceil().clamp(1, 4096);
    final height = painter.height.ceil().clamp(1, 1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw const ThermalExportException('Failed to render APNG text overlay.');
    }
    return _ApngTextSprite(
      width: width,
      height: height,
      rgba: byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
  }

  Future<Uint8List> _encodeApngInIsolate({
    required Uint8List bytes,
    required RenderSettings settings,
    required TemperatureUnit temperatureUnit,
    required bool includePoints,
    required bool includeLegend,
    required int exportScale,
    required Map<String, _ApngTextSprite> textSprites,
    required void Function(ThermalExportProgress progress)? onProgress,
    required bool Function()? shouldCancel,
    required ThermalApngExportLabels labels,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Uint8List>();
    late final Isolate isolate;
    StreamSubscription<Object?>? subscription;
    Timer? cancelTimer;

    subscription = receivePort.listen((message) {
      if (message == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            const ThermalExportException('APNG export stopped unexpectedly.'),
          );
        }
        return;
      }
      if (message is List && message.isNotEmpty) {
        switch (message.first) {
          case 'progress':
            if (message.length >= 4) {
              onProgress?.call(
                ThermalExportProgress(
                  value: message[1] as double,
                  phase: message[2] as String,
                  message: message[3] as String,
                ),
              );
            }
          case 'done':
            if (message.length >= 2 && !completer.isCompleted) {
              final data = message[1] as TransferableTypedData;
              completer.complete(data.materialize().asUint8List());
            }
          case 'error':
            if (!completer.isCompleted) {
              final details = message.length >= 2
                  ? message[1].toString()
                  : 'Failed to encode APNG.';
              completer.completeError(ThermalExportException(details));
            }
        }
      }
    });

    try {
      isolate = await Isolate.spawn<_ApngExportWork>(
        _encodeApngWorker,
        _ApngExportWork(
          bytes: TransferableTypedData.fromList([bytes]),
          settings: settings,
          temperatureUnit: temperatureUnit,
          includePoints: includePoints,
          includeLegend: includeLegend,
          exportScale: exportScale,
          textSprites: textSprites,
          labels: labels,
          sendPort: receivePort.sendPort,
        ),
        onExit: receivePort.sendPort,
        onError: receivePort.sendPort,
      );
      if (shouldCancel != null) {
        cancelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!shouldCancel()) return;
          if (!completer.isCompleted) {
            completer.completeError(const ThermalExportCancelled());
          }
        });
      }
    } catch (_) {
      await subscription.cancel();
      receivePort.close();
      rethrow;
    }

    try {
      return await completer.future;
    } finally {
      cancelTimer?.cancel();
      isolate.kill(priority: Isolate.immediate);
      await subscription.cancel();
      receivePort.close();
    }
  }

  static void _throwIfCancelled(bool Function()? shouldCancel) {
    if (shouldCancel?.call() ?? false) {
      throw const ThermalExportCancelled();
    }
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
    final lines = [
      'MAX ${temperatureUnit.format(extrema.max)}',
      'MIN ${temperatureUnit.format(extrema.min)}',
      'AVG ${temperatureUnit.format(extrema.avg)}',
    ];
    final painters = [
      for (final line in lines)
        _textPainter(line, Colors.white, 12 * styleScale, mono: true),
    ];
    final maxTextWidth = painters
        .map((painter) => painter.width)
        .reduce((a, b) => a > b ? a : b);
    var y = 8.0 * styleScale;
    for (final textPainter in painters) {
      final rect = Rect.fromLTWH(
        x,
        y - 3 * styleScale,
        maxTextWidth + 10 * styleScale,
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

  TextPainter _textPainter(
    String text,
    Color color,
    double size, {
    bool mono = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontFamily: mono ? _statsFontFamily : null,
          fontFamilyFallback: mono ? _statsFontFallback : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
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

class _ApngExportWork {
  const _ApngExportWork({
    required this.bytes,
    required this.settings,
    required this.temperatureUnit,
    required this.includePoints,
    required this.includeLegend,
    required this.exportScale,
    required this.textSprites,
    required this.labels,
    required this.sendPort,
  });

  final TransferableTypedData bytes;
  final RenderSettings settings;
  final TemperatureUnit temperatureUnit;
  final bool includePoints;
  final bool includeLegend;
  final int exportScale;
  final Map<String, _ApngTextSprite> textSprites;
  final ThermalApngExportLabels labels;
  final SendPort sendPort;
}

class _ApngTextSprite {
  const _ApngTextSprite({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;

  img.Image get image {
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }
}

String _textSpriteKey(String text, {bool mono = false}) {
  return '${mono ? 'mono' : 'regular'}\u0000$text';
}

void _encodeApngWorker(_ApngExportWork work) {
  try {
    final bytes = work.bytes.materialize().asUint8List();
    final document = const UirReader().read(bytes);
    final points = thermalPointsFromMetadata(document.metadata);
    if (document.frames.length < 2) {
      throw const ThermalExportException('No video frames to export.');
    }

    final textSprites = {
      for (final entry in work.textSprites.entries)
        entry.key: entry.value.image,
    };
    work.sendPort.send([
      'progress',
      0.15,
      work.labels.renderingFrames,
      work.labels.renderingFrameMessage(0, document.frames.length),
    ]);
    img.Image? animation;
    for (var i = 0; i < document.frames.length; i++) {
      final frameImage = _renderFrameImage(
        document.frames[i].frame,
        work.settings,
        points: points,
        includePoints: work.includePoints,
        includeLegend: work.includeLegend,
        temperatureUnit: work.temperatureUnit,
        exportScale: work.exportScale,
        textSprites: textSprites,
      )..frameDuration = _frameDurationMs(document.frames, i);
      if (animation == null) {
        animation = frameImage
          ..frameType = img.FrameType.animation
          ..loopCount = 0;
      } else {
        animation.addFrame(frameImage);
      }
      final frameNumber = i + 1;
      if (frameNumber == document.frames.length || frameNumber % 8 == 0) {
        work.sendPort.send([
          'progress',
          0.15 + 0.65 * (frameNumber / document.frames.length),
          work.labels.renderingFrames,
          work.labels.renderedFrameMessage(frameNumber, document.frames.length),
        ]);
      }
    }

    work.sendPort.send([
      'progress',
      0.82,
      work.labels.encodingApng,
      work.labels.compressingAnimatedPngFrames,
    ]);
    final apng = img.PngEncoder().encode(animation!);
    work.sendPort.send([
      'progress',
      0.93,
      work.labels.encodingApng,
      work.labels.apngEncodingComplete,
    ]);
    work.sendPort.send([
      'done',
      TransferableTypedData.fromList([apng]),
    ]);
  } catch (error, stackTrace) {
    work.sendPort.send(['error', '$error\n$stackTrace']);
  }
}

img.Image _renderFrameImage(
  ThermalFrame frame,
  RenderSettings settings, {
  required List<ThermalPoint> points,
  required bool includePoints,
  required bool includeLegend,
  required TemperatureUnit temperatureUnit,
  required int exportScale,
  required Map<String, img.Image> textSprites,
}) {
  final raster = renderThermalRaster(
    temperatures: frame.temperatures,
    width: frame.width,
    height: frame.height,
    tMin: frame.tMin,
    tMax: frame.tMax,
    scale: exportScale,
    settings: settings,
  );
  final frameImage = img.Image.fromBytes(
    width: raster.width,
    height: raster.height,
    bytes: raster.rgba.buffer,
    bytesOffset: raster.rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final styleScale = exportScale / ThermalExporter._previewScale;
  final extrema = _findExtrema(
    frame.temperatures,
    frame.width,
    frame.height,
    settings,
  );
  if (includeLegend) {
    _drawImageStats(
      frameImage,
      extrema,
      temperatureUnit,
      styleScale,
      textSprites,
    );
    _drawImageExtremaAnchors(
      frameImage,
      extrema,
      frameWidth: frame.width,
      frameHeight: frame.height,
      settings: settings,
      temperatureUnit: temperatureUnit,
      styleScale: styleScale,
      textSprites: textSprites,
    );
  }
  if (includePoints) {
    for (final point in points) {
      final display = thermalPointToDisplay(
        point,
        frame.width,
        frame.height,
        settings,
      );
      _drawImageAnchor(
        frameImage,
        display.dx * frameImage.width,
        display.dy * frameImage.height,
        '${point.label} ${temperatureUnit.format(sampleThermalPoint(frame, point))}',
        point.colorArgb,
        styleScale,
        textSprites: textSprites,
        radius: 8,
        arm: 12,
      );
    }
  }
  return frameImage;
}

void _drawImageStats(
  img.Image image,
  _ExportExtrema extrema,
  TemperatureUnit temperatureUnit,
  double styleScale,
  Map<String, img.Image> textSprites,
) {
  final x = (8 * styleScale).round();
  final lines = [
    'MAX ${temperatureUnit.format(extrema.max)}',
    'MIN ${temperatureUnit.format(extrema.min)}',
    'AVG ${temperatureUnit.format(extrema.avg)}',
  ];
  final maxTextWidth = lines
      .map((line) => textSprites[_textSpriteKey(line, mono: true)]?.width ?? 0)
      .reduce((a, b) => a > b ? a : b);
  final verticalPadding = (3 * styleScale).round().clamp(2, 12);
  final horizontalPadding = (5 * styleScale).round().clamp(4, 16);
  final gap = (8 * styleScale).round().clamp(6, 22);
  final radius = (5 * styleScale).round().clamp(4, 18);
  var y = (8 * styleScale).round();
  for (final line in lines) {
    final sprite = textSprites[_textSpriteKey(line, mono: true)];
    if (sprite == null) continue;
    img.fillRect(
      image,
      x1: x,
      y1: y - verticalPadding,
      x2: x + maxTextWidth + horizontalPadding * 2,
      y2: y + sprite.height + verticalPadding,
      radius: radius,
      color: img.ColorRgba8(0, 0, 0, 158),
    );
    img.compositeImage(image, sprite, dstX: x + horizontalPadding, dstY: y);
    y += sprite.height + gap;
  }
}

void _drawImageExtremaAnchors(
  img.Image image,
  _ExportExtrema extrema, {
  required int frameWidth,
  required int frameHeight,
  required RenderSettings settings,
  required TemperatureUnit temperatureUnit,
  required double styleScale,
  required Map<String, img.Image> textSprites,
}) {
  final oriented = displayOrientedSize(
    frameWidth,
    frameHeight,
    settings.rotation,
  );
  final scaleX = image.width / oriented.width;
  final scaleY = image.height / oriented.height;
  _drawImageAnchor(
    image,
    extrema.maxX * scaleX + scaleX / 2,
    extrema.maxY * scaleY + scaleY / 2,
    temperatureUnit.format(extrema.max),
    0xffff5252,
    styleScale,
    textSprites: textSprites,
    radius: 7,
    arm: 11,
  );
  _drawImageAnchor(
    image,
    extrema.minX * scaleX + scaleX / 2,
    extrema.minY * scaleY + scaleY / 2,
    temperatureUnit.format(extrema.min),
    0xff60a5fa,
    styleScale,
    textSprites: textSprites,
    radius: 7,
    arm: 11,
  );
}

void _drawImageAnchor(
  img.Image image,
  double centerX,
  double centerY,
  String label,
  int argb,
  double styleScale, {
  required Map<String, img.Image> textSprites,
  required double radius,
  required double arm,
}) {
  final color = _imageColor(argb);
  final x = centerX.round();
  final y = centerY.round();
  final scaledRadius = (radius * styleScale).round().clamp(3, 64);
  final scaledArm = (arm * styleScale).round().clamp(5, 96);
  final thickness = (2 * styleScale).round().clamp(1, 12);
  for (var offset = 0; offset < thickness; offset++) {
    img.drawCircle(
      image,
      x: x,
      y: y,
      radius: scaledRadius + offset,
      color: color,
    );
  }
  img.drawLine(
    image,
    x1: x - scaledArm,
    y1: y,
    x2: x + scaledArm,
    y2: y,
    thickness: thickness,
    color: color,
  );
  img.drawLine(
    image,
    x1: x,
    y1: y - scaledArm,
    x2: x,
    y2: y + scaledArm,
    thickness: thickness,
    color: color,
  );
  _drawImageLabel(
    image,
    label,
    centerX + 10 * styleScale,
    centerY - 26 * styleScale,
    argb,
    styleScale,
    textSprites,
  );
}

void _drawImageLabel(
  img.Image image,
  String label,
  double offsetX,
  double offsetY,
  int argb,
  double styleScale,
  Map<String, img.Image> textSprites,
) {
  final sprite = textSprites[_textSpriteKey(label)];
  if (sprite == null) return;
  final textWidth = sprite.width;
  final horizontalPadding = (5 * styleScale).round().clamp(4, 16);
  final verticalPadding = (3 * styleScale).round().clamp(2, 12);
  final minX = (4 * styleScale).round();
  final minY = (4 * styleScale).round();
  final maxX = image.width - textWidth - horizontalPadding * 2 - minX;
  final maxY = image.height - sprite.height - verticalPadding * 2 - minY;
  final x = offsetX.round().clamp(minX, maxX < minX ? minX : maxX);
  final y = offsetY.round().clamp(minY, maxY < minY ? minY : maxY);
  img.fillRect(
    image,
    x1: x - horizontalPadding,
    y1: y - verticalPadding,
    x2: x + textWidth + horizontalPadding,
    y2: y + sprite.height + verticalPadding,
    radius: (5 * styleScale).round().clamp(4, 18),
    color: _imageColor(argb, alpha: 209),
  );
  img.compositeImage(image, sprite, dstX: x, dstY: y);
}

img.ColorRgba8 _imageColor(int argb, {int? alpha}) {
  return img.ColorRgba8(
    (argb >> 16) & 0xff,
    (argb >> 8) & 0xff,
    argb & 0xff,
    alpha ?? ((argb >> 24) & 0xff),
  );
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
