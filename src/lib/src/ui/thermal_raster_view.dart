import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/thermal_frame.dart';
import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../core/temperature_unit.dart';
import 'thermal_points_overlay.dart';

const _statsFontFamily = 'Menlo';
const _statsFontFallback = ['SF Mono', 'Monaco', 'Courier New', 'Courier'];

class ThermalRasterView extends StatefulWidget {
  const ThermalRasterView({
    super.key,
    required this.temperatures,
    required this.width,
    required this.height,
    required this.tMin,
    required this.tMax,
    required this.settings,
    this.sensorType = ThermalSensorType.legacy,
    this.scale = 12,
    this.showOverlay = true,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.points = const [],
    this.onPointAdded,
    this.onPointMoved,
    this.onPointRemoved,
  });

  factory ThermalRasterView.frame(
    ThermalFrame frame, {
    Key? key,
    required RenderSettings settings,
    int scale = 12,
    bool showOverlay = true,
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    List<ThermalPoint> points = const [],
    void Function(double xNorm, double yNorm)? onPointAdded,
    void Function(String id, double xNorm, double yNorm)? onPointMoved,
    void Function(String id)? onPointRemoved,
  }) {
    return ThermalRasterView(
      key: key,
      temperatures: frame.temperatures,
      width: frame.width,
      height: frame.height,
      tMin: frame.tMin,
      tMax: frame.tMax,
      sensorType: frame.sensorType,
      settings: settings,
      scale: scale,
      showOverlay: showOverlay,
      temperatureUnit: temperatureUnit,
      points: points,
      onPointAdded: onPointAdded,
      onPointMoved: onPointMoved,
      onPointRemoved: onPointRemoved,
    );
  }

  final Float32List temperatures;
  final int width;
  final int height;
  final double tMin;
  final double tMax;
  final ThermalSensorType sensorType;
  final RenderSettings settings;
  final int scale;
  final bool showOverlay;
  final TemperatureUnit temperatureUnit;
  final List<ThermalPoint> points;
  final void Function(double xNorm, double yNorm)? onPointAdded;
  final void Function(String id, double xNorm, double yNorm)? onPointMoved;
  final void Function(String id)? onPointRemoved;

  @override
  State<ThermalRasterView> createState() => _ThermalRasterViewState();
}

class _ThermalRasterViewState extends State<ThermalRasterView> {
  ui.Image? _image;
  RasterImage? _raster;
  _Extrema? _extrema;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant ThermalRasterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temperatures != widget.temperatures ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.tMin != widget.tMin ||
        oldWidget.tMax != widget.tMax ||
        oldWidget.settings != widget.settings ||
        oldWidget.scale != widget.scale) {
      _render();
    }
  }

  Future<void> _render() async {
    final generation = ++_generation;
    final request = _RenderRequest(
      temperatures: widget.temperatures,
      width: widget.width,
      height: widget.height,
      tMin: widget.tMin,
      tMax: widget.tMax,
      scale: widget.scale,
      settings: widget.settings,
    );
    late final _RenderResult result;
    try {
      result = await compute(_renderThermalRasterInIsolate, request);
    } catch (error, stackTrace) {
      debugPrint('Thermal raster render failed: $error\n$stackTrace');
      result = _renderThermalRasterInIsolate(request);
    }
    if (!mounted || generation != _generation) return;
    _raster = result.raster;
    _extrema = result.extrema;
    ui.decodeImageFromPixels(
      result.raster.rgba,
      result.raster.width,
      result.raster.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (mounted && generation == _generation) {
          final previous = _image;
          setState(() => _image = image);
          previous?.dispose();
        } else {
          image.dispose();
        }
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final raster = _raster;
    final extrema = _extrema;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? Colors.black : colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: image == null || raster == null || extrema == null
            ? const SizedBox.square(
                dimension: 48,
                child: CircularProgressIndicator(),
              )
            : FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: raster.width.toDouble(),
                  height: raster.height.toDouble(),
                  child: CustomPaint(
                    painter: _ThermalImagePainter(
                      image: image,
                      sourceWidth: widget.width,
                      sourceHeight: widget.height,
                      settings: widget.settings,
                      extrema: extrema,
                      showOverlay: widget.showOverlay,
                      temperatureUnit: widget.temperatureUnit,
                    ),
                    child: ThermalPointsOverlay(
                      frame: ThermalFrame(
                        id: 'overlay',
                        timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
                        temperatures: widget.temperatures,
                        width: widget.width,
                        height: widget.height,
                        sensorType: widget.sensorType,
                        tMin: widget.tMin,
                        tMax: widget.tMax,
                        tAvg: extrema.avg,
                      ),
                      settings: widget.settings,
                      temperatureUnit: widget.temperatureUnit,
                      points: widget.points,
                      onPointAdded: widget.onPointAdded,
                      onPointMoved: widget.onPointMoved,
                      onPointRemoved: widget.onPointRemoved,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ThermalImagePainter extends CustomPainter {
  const _ThermalImagePainter({
    required this.image,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.settings,
    required this.extrema,
    required this.showOverlay,
    required this.temperatureUnit,
  });

  final ui.Image image;
  final int sourceWidth;
  final int sourceHeight;
  final RenderSettings settings;
  final _Extrema extrema;
  final bool showOverlay;
  final TemperatureUnit temperatureUnit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );

    if (!showOverlay) return;

    final oriented = displayOrientedSize(
      sourceWidth,
      sourceHeight,
      settings.rotation,
    );
    final scaleX = size.width / oriented.width;
    final scaleY = size.height / oriented.height;
    _drawAnchor(
      canvas,
      extrema.maxX * scaleX + scaleX / 2,
      extrema.maxY * scaleY + scaleY / 2,
      temperatureUnit.format(extrema.max),
      const Color(0xffff5252),
      size,
    );
    _drawAnchor(
      canvas,
      extrema.minX * scaleX + scaleX / 2,
      extrema.minY * scaleY + scaleY / 2,
      temperatureUnit.format(extrema.min),
      const Color(0xff60a5fa),
      size,
    );
    _drawStats(canvas, size, extrema);
  }

  void _drawAnchor(
    Canvas canvas,
    double x,
    double y,
    String label,
    Color color,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), 7, paint);
    canvas.drawLine(Offset(x - 11, y), Offset(x + 11, y), paint);
    canvas.drawLine(Offset(x, y - 11), Offset(x, y + 11), paint);
    _drawLabel(canvas, label, Offset(x + 10, y - 26), color, size);
  }

  void _drawStats(Canvas canvas, Size size, _Extrema extrema) {
    final lines = [
      'MAX ${temperatureUnit.format(extrema.max)}',
      'MIN ${temperatureUnit.format(extrema.min)}',
      'AVG ${temperatureUnit.format(extrema.avg)}',
    ];
    final painters = [
      for (final line in lines)
        _textPainter(line, Colors.white, 12, mono: true),
    ];
    final maxTextWidth = painters
        .map((painter) => painter.width)
        .reduce((a, b) => a > b ? a : b);
    var y = 8.0;
    for (final textPainter in painters) {
      final rect = Rect.fromLTWH(
        8,
        y - 3,
        maxTextWidth + 10,
        textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = Colors.black.withValues(alpha: 0.62),
      );
      textPainter.paint(canvas, Offset(13, y));
      y += textPainter.height + 8;
    }
  }

  void _drawLabel(
    Canvas canvas,
    String label,
    Offset offset,
    Color color,
    Size size,
  ) {
    final textPainter = _textPainter(label, Colors.white, 12);
    final dx = offset.dx.clamp(4.0, size.width - textPainter.width - 14);
    final dy = offset.dy.clamp(4.0, size.height - textPainter.height - 10);
    final rect = Rect.fromLTWH(
      dx - 5,
      dy - 3,
      textPainter.width + 10,
      textPainter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
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

  @override
  bool shouldRepaint(covariant _ThermalImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.settings != settings ||
        oldDelegate.extrema != extrema ||
        oldDelegate.showOverlay != showOverlay ||
        oldDelegate.temperatureUnit != temperatureUnit;
  }
}

class _RenderRequest {
  const _RenderRequest({
    required this.temperatures,
    required this.width,
    required this.height,
    required this.tMin,
    required this.tMax,
    required this.scale,
    required this.settings,
  });

  final Float32List temperatures;
  final int width;
  final int height;
  final double tMin;
  final double tMax;
  final int scale;
  final RenderSettings settings;
}

class _RenderResult {
  const _RenderResult({required this.raster, required this.extrema});

  final RasterImage raster;
  final _Extrema extrema;
}

_RenderResult _renderThermalRasterInIsolate(_RenderRequest request) {
  return _RenderResult(
    raster: renderThermalRaster(
      temperatures: request.temperatures,
      width: request.width,
      height: request.height,
      tMin: request.tMin,
      tMax: request.tMax,
      scale: request.scale,
      settings: request.settings,
    ),
    extrema: _findExtrema(
      request.temperatures,
      request.width,
      request.height,
      request.settings,
    ),
  );
}

_Extrema _findExtrema(
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
  return _Extrema(
    min: min,
    max: max,
    avg: sum / oriented.length,
    minX: minIndex % size.width,
    minY: minIndex ~/ size.width,
    maxX: maxIndex % size.width,
    maxY: maxIndex ~/ size.width,
  );
}

class _Extrema {
  const _Extrema({
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
