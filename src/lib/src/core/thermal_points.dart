import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'thermal_frame.dart';
import 'thermal_rendering.dart';

class ThermalPoint {
  const ThermalPoint({
    required this.id,
    required this.xNorm,
    required this.yNorm,
    required this.label,
    required this.colorArgb,
  });

  final String id;
  final double xNorm;
  final double yNorm;
  final String label;
  final int colorArgb;

  Color get color => Color(colorArgb);

  ThermalPoint copyWith({
    double? xNorm,
    double? yNorm,
    String? label,
    int? colorArgb,
  }) {
    return ThermalPoint(
      id: id,
      xNorm: xNorm ?? this.xNorm,
      yNorm: yNorm ?? this.yNorm,
      label: label ?? this.label,
      colorArgb: colorArgb ?? this.colorArgb,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'xNorm': xNorm,
      'yNorm': yNorm,
      'label': label,
      'colorArgb': colorArgb,
    };
  }
}

double sampleThermalPoint(
  ThermalFrame frame,
  ThermalPoint point, {
  bool bilinear = true,
}) {
  final x = (point.xNorm.clamp(0.0, 1.0)) * (frame.width - 1);
  final y = (point.yNorm.clamp(0.0, 1.0)) * (frame.height - 1);
  if (!bilinear) {
    final px = x.round().clamp(0, frame.width - 1);
    final py = y.round().clamp(0, frame.height - 1);
    return frame.temperatures[py * frame.width + px];
  }
  final x0 = x.floor().clamp(0, frame.width - 1);
  final y0 = y.floor().clamp(0, frame.height - 1);
  final x1 = math.min(frame.width - 1, x0 + 1);
  final y1 = math.min(frame.height - 1, y0 + 1);
  final fx = x - x0;
  final fy = y - y0;
  final v00 = frame.temperatures[y0 * frame.width + x0];
  final v10 = frame.temperatures[y0 * frame.width + x1];
  final v01 = frame.temperatures[y1 * frame.width + x0];
  final v11 = frame.temperatures[y1 * frame.width + x1];
  return v00 * (1 - fx) * (1 - fy) +
      v10 * fx * (1 - fy) +
      v01 * (1 - fx) * fy +
      v11 * fx * fy;
}

Offset thermalPointToDisplay(
  ThermalPoint point,
  int width,
  int height,
  RenderSettings settings,
) {
  var x = point.xNorm.clamp(0.0, 1.0);
  var y = point.yNorm.clamp(0.0, 1.0);
  var w = width;
  var h = height;
  (x, y, w, h) = _applyTransform(x, y, w, h, rotation: 180, hflip: true);
  (x, y, w, h) = _applyTransform(
    x,
    y,
    w,
    h,
    rotation: settings.rotation,
    hflip: settings.hflip,
    vflip: settings.vflip,
  );
  return Offset(x, y);
}

Offset displayToThermalPoint(
  Offset displayNorm,
  int width,
  int height,
  RenderSettings settings,
) {
  var x = displayNorm.dx.clamp(0.0, 1.0);
  var y = displayNorm.dy.clamp(0.0, 1.0);
  var w = displayOrientedSize(width, height, settings.rotation).width;
  var h = displayOrientedSize(width, height, settings.rotation).height;
  (x, y, w, h) = _invertTransform(
    x,
    y,
    w,
    h,
    rotation: settings.rotation,
    hflip: settings.hflip,
    vflip: settings.vflip,
  );
  (x, y, w, h) = _invertTransform(x, y, w, h, rotation: 180, hflip: true);
  return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
}

(double, double, int, int) _applyTransform(
  double x,
  double y,
  int width,
  int height, {
  required int rotation,
  bool hflip = false,
  bool vflip = false,
}) {
  if (hflip) x = 1 - x;
  if (vflip) y = 1 - y;
  return switch (rotation) {
    90 => (1 - y, x, height, width),
    180 => (1 - x, 1 - y, width, height),
    270 => (y, 1 - x, height, width),
    _ => (x, y, width, height),
  };
}

(double, double, int, int) _invertTransform(
  double x,
  double y,
  int width,
  int height, {
  required int rotation,
  bool hflip = false,
  bool vflip = false,
}) {
  final beforeRotation = switch (rotation) {
    90 => (y, 1 - x, height, width),
    180 => (1 - x, 1 - y, width, height),
    270 => (1 - y, x, height, width),
    _ => (x, y, width, height),
  };
  x = beforeRotation.$1;
  y = beforeRotation.$2;
  if (hflip) x = 1 - x;
  if (vflip) y = 1 - y;
  return (x, y, beforeRotation.$3, beforeRotation.$4);
}
