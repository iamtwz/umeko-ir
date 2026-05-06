import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/thermal_frame.dart';
import '../core/thermal_rendering.dart';

class ThermalRasterView extends StatefulWidget {
  const ThermalRasterView({
    super.key,
    required this.temperatures,
    required this.width,
    required this.height,
    required this.tMin,
    required this.tMax,
    required this.settings,
    this.scale = 12,
    this.showOverlay = true,
  });

  factory ThermalRasterView.frame(
    ThermalFrame frame, {
    Key? key,
    required RenderSettings settings,
    int scale = 12,
    bool showOverlay = true,
  }) {
    return ThermalRasterView(
      key: key,
      temperatures: frame.temperatures,
      width: frame.width,
      height: frame.height,
      tMin: frame.tMin,
      tMax: frame.tMax,
      settings: settings,
      scale: scale,
      showOverlay: showOverlay,
    );
  }

  final Float32List temperatures;
  final int width;
  final int height;
  final double tMin;
  final double tMax;
  final RenderSettings settings;
  final int scale;
  final bool showOverlay;

  @override
  State<ThermalRasterView> createState() => _ThermalRasterViewState();
}

class _ThermalRasterViewState extends State<ThermalRasterView> {
  ui.Image? _image;
  RasterImage? _raster;
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

  void _render() {
    final generation = ++_generation;
    final raster = renderThermalRaster(
      temperatures: widget.temperatures,
      width: widget.width,
      height: widget.height,
      tMin: widget.tMin,
      tMax: widget.tMax,
      scale: widget.scale,
      settings: widget.settings,
    );
    _raster = raster;
    ui.decodeImageFromPixels(
      raster.rgba,
      raster.width,
      raster.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (mounted && generation == _generation) {
          setState(() => _image = image);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final raster = _raster;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? Colors.black : colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: image == null || raster == null
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
                      temperatures: widget.temperatures,
                      sourceWidth: widget.width,
                      sourceHeight: widget.height,
                      settings: widget.settings,
                      tMin: widget.tMin,
                      tMax: widget.tMax,
                      showOverlay: widget.showOverlay,
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
    required this.temperatures,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.settings,
    required this.tMin,
    required this.tMax,
    required this.showOverlay,
  });

  final ui.Image image;
  final Float32List temperatures;
  final int sourceWidth;
  final int sourceHeight;
  final RenderSettings settings;
  final double tMin;
  final double tMax;
  final bool showOverlay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );

    if (!showOverlay) return;

    final extrema = _findExtrema();
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
      '${extrema.max.toStringAsFixed(1)} C',
      const Color(0xffff5252),
      size,
    );
    _drawAnchor(
      canvas,
      extrema.minX * scaleX + scaleX / 2,
      extrema.minY * scaleY + scaleY / 2,
      '${extrema.min.toStringAsFixed(1)} C',
      const Color(0xff60a5fa),
      size,
    );
    _drawStats(canvas, size, extrema);
  }

  _Extrema _findExtrema() {
    final oriented = orientForDisplay(
      temperatures,
      sourceWidth,
      sourceHeight,
      rotation: settings.rotation,
      hflip: settings.hflip,
      vflip: settings.vflip,
    );
    final size = orientedSize(sourceWidth, sourceHeight, settings.rotation);
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
      'MAX ${extrema.max.toStringAsFixed(1)} C',
      'MIN ${extrema.min.toStringAsFixed(1)} C',
      'AVG ${extrema.avg.toStringAsFixed(1)} C',
    ];
    var y = 8.0;
    for (final line in lines) {
      final textPainter = _textPainter(line, Colors.white, 12);
      final rect = Rect.fromLTWH(
        size.width - textPainter.width - 18,
        y - 3,
        textPainter.width + 10,
        textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = Colors.black.withValues(alpha: 0.62),
      );
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 13, y));
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

  @override
  bool shouldRepaint(covariant _ThermalImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.temperatures != temperatures ||
        oldDelegate.settings != settings ||
        oldDelegate.tMin != tMin ||
        oldDelegate.tMax != tMax ||
        oldDelegate.showOverlay != showOverlay;
  }
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
