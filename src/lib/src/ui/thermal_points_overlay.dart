import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/thermal_frame.dart';
import '../core/thermal_points.dart';
import '../core/thermal_rendering.dart';
import '../core/temperature_unit.dart';

class ThermalPointsOverlay extends StatefulWidget {
  const ThermalPointsOverlay({
    super.key,
    required this.frame,
    required this.settings,
    required this.temperatureUnit,
    required this.points,
    this.onPointAdded,
    this.onPointMoved,
    this.onPointRemoved,
  });

  final ThermalFrame frame;
  final RenderSettings settings;
  final TemperatureUnit temperatureUnit;
  final List<ThermalPoint> points;
  final void Function(double xNorm, double yNorm)? onPointAdded;
  final void Function(String id, double xNorm, double yNorm)? onPointMoved;
  final void Function(String id)? onPointRemoved;

  @override
  State<ThermalPointsOverlay> createState() => _ThermalPointsOverlayState();
}

class _ThermalPointsOverlayState extends State<ThermalPointsOverlay> {
  String? _draggingPointId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: _handleDoubleTap,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: (_) => _draggingPointId = null,
      onLongPressStart: _handleLongPress,
      child: CustomPaint(
        painter: _ThermalPointsPainter(
          frame: widget.frame,
          settings: widget.settings,
          temperatureUnit: widget.temperatureUnit,
          points: widget.points,
        ),
      ),
    );
  }

  void _handleDoubleTap(TapDownDetails details) {
    final existing = _nearestPoint(details.localPosition);
    if (existing != null) {
      widget.onPointRemoved?.call(existing.id);
      return;
    }
    final norm = _displayNorm(details.localPosition);
    final source = displayToThermalPoint(
      norm,
      widget.frame.width,
      widget.frame.height,
      widget.settings,
    );
    widget.onPointAdded?.call(source.dx, source.dy);
  }

  void _handlePanStart(DragStartDetails details) {
    _draggingPointId = _nearestPoint(details.localPosition)?.id;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final id = _draggingPointId;
    if (id == null) return;
    final norm = _displayNorm(details.localPosition);
    final source = displayToThermalPoint(
      norm,
      widget.frame.width,
      widget.frame.height,
      widget.settings,
    );
    widget.onPointMoved?.call(id, source.dx, source.dy);
  }

  void _handleLongPress(LongPressStartDetails details) {
    final existing = _nearestPoint(details.localPosition);
    if (existing != null) widget.onPointRemoved?.call(existing.id);
  }

  ThermalPoint? _nearestPoint(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    ThermalPoint? nearest;
    var best = double.infinity;
    for (final point in widget.points) {
      final display = thermalPointToDisplay(
        point,
        widget.frame.width,
        widget.frame.height,
        widget.settings,
      );
      final offset = Offset(
        display.dx * box.size.width,
        display.dy * box.size.height,
      );
      final distance = (offset - localPosition).distance;
      if (distance < best) {
        best = distance;
        nearest = point;
      }
    }
    return best <= 28 ? nearest : null;
  }

  Offset _displayNorm(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
  }
}

class _ThermalPointsPainter extends CustomPainter {
  const _ThermalPointsPainter({
    required this.frame,
    required this.settings,
    required this.temperatureUnit,
    required this.points,
  });

  final ThermalFrame frame;
  final RenderSettings settings;
  final TemperatureUnit temperatureUnit;
  final List<ThermalPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final display = thermalPointToDisplay(
        point,
        frame.width,
        frame.height,
        settings,
      );
      final center = Offset(display.dx * size.width, display.dy * size.height);
      final temperature = sampleThermalPoint(frame, point);
      _drawPoint(canvas, size, center, point, temperature);
    }
  }

  void _drawPoint(
    Canvas canvas,
    Size size,
    Offset center,
    ThermalPoint point,
    double temperature,
  ) {
    final paint = Paint()
      ..color = point.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, paint);
    canvas.drawLine(center.translate(-12, 0), center.translate(12, 0), paint);
    canvas.drawLine(center.translate(0, -12), center.translate(0, 12), paint);

    final label = '${point.label} ${temperatureUnit.format(temperature)}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = math.min(
      math.max(4.0, center.dx + 10),
      math.max(4.0, size.width - textPainter.width - 10),
    );
    final dy = math.min(
      math.max(4.0, center.dy - 28),
      math.max(4.0, size.height - textPainter.height - 8),
    );
    final rect = Rect.fromLTWH(
      dx - 5,
      dy - 3,
      textPainter.width + 10,
      textPainter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = point.color.withValues(alpha: 0.82),
    );
    textPainter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ThermalPointsPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.settings != settings ||
        oldDelegate.temperatureUnit != temperatureUnit ||
        oldDelegate.points != points;
  }
}
