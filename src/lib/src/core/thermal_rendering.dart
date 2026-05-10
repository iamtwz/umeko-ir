import 'dart:math' as math;
import 'dart:typed_data';

enum ThermalColorMap {
  ironbow,
  rainbow,
  grayscale,
  blackHot,
  hot,
  inferno,
  plasma,
  jet,
  cool,
}

enum ThermalFilter { none, gaussian, sharpen, sobel, emboss }

class RenderSettings {
  const RenderSettings({
    this.colorMap = ThermalColorMap.rainbow,
    this.filter = ThermalFilter.none,
    this.upscaleEnabled = true,
    this.rotation = 0,
    this.hflip = false,
    this.vflip = false,
    this.rangeMin,
    this.rangeMax,
  });

  final ThermalColorMap colorMap;
  final ThermalFilter filter;
  final bool upscaleEnabled;
  final int rotation;
  final bool hflip;
  final bool vflip;
  final double? rangeMin;
  final double? rangeMax;

  RenderSettings copyWith({
    ThermalColorMap? colorMap,
    ThermalFilter? filter,
    bool? upscaleEnabled,
    int? rotation,
    bool? hflip,
    bool? vflip,
    double? rangeMin,
    double? rangeMax,
  }) {
    return RenderSettings(
      colorMap: colorMap ?? this.colorMap,
      filter: filter ?? this.filter,
      upscaleEnabled: upscaleEnabled ?? this.upscaleEnabled,
      rotation: rotation ?? this.rotation,
      hflip: hflip ?? this.hflip,
      vflip: vflip ?? this.vflip,
      rangeMin: rangeMin ?? this.rangeMin,
      rangeMax: rangeMax ?? this.rangeMax,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RenderSettings &&
        other.colorMap == colorMap &&
        other.filter == filter &&
        other.upscaleEnabled == upscaleEnabled &&
        other.rotation == rotation &&
        other.hflip == hflip &&
        other.vflip == vflip &&
        other.rangeMin == rangeMin &&
        other.rangeMax == rangeMax;
  }

  @override
  int get hashCode {
    return Object.hash(
      colorMap,
      filter,
      upscaleEnabled,
      rotation,
      hflip,
      vflip,
      rangeMin,
      rangeMax,
    );
  }
}

class RasterImage {
  const RasterImage({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

const _deviceBaseRotation = 180;
const _deviceBaseHFlip = true;

({int width, int height}) orientedSize(int width, int height, int rotation) {
  return rotation == 90 || rotation == 270
      ? (width: height, height: width)
      : (width: width, height: height);
}

({int width, int height}) displayOrientedSize(
  int width,
  int height,
  int userRotation,
) {
  final baseSize = orientedSize(width, height, _deviceBaseRotation);
  return orientedSize(baseSize.width, baseSize.height, userRotation);
}

Float32List orientForDisplay(
  Float32List source,
  int width,
  int height, {
  int rotation = 0,
  bool hflip = false,
  bool vflip = false,
}) {
  final baseSize = orientedSize(width, height, _deviceBaseRotation);
  final base = orientTemperatures(
    source,
    width,
    height,
    rotation: _deviceBaseRotation,
    hflip: _deviceBaseHFlip,
  );
  return orientTemperatures(
    base,
    baseSize.width,
    baseSize.height,
    rotation: rotation,
    hflip: hflip,
    vflip: vflip,
  );
}

Float32List orientTemperatures(
  Float32List source,
  int width,
  int height, {
  int rotation = 0,
  bool hflip = false,
  bool vflip = false,
}) {
  final size = orientedSize(width, height, rotation);
  final out = Float32List(size.width * size.height);

  for (var y = 0; y < size.height; y++) {
    for (var x = 0; x < size.width; x++) {
      var sx = x;
      var sy = y;
      if (rotation == 90) {
        sx = y;
        sy = height - 1 - x;
      } else if (rotation == 180) {
        sx = width - 1 - x;
        sy = height - 1 - y;
      } else if (rotation == 270) {
        sx = width - 1 - y;
        sy = x;
      }
      if (hflip) sx = width - 1 - sx;
      if (vflip) sy = height - 1 - sy;
      out[y * size.width + x] = source[sy * width + sx];
    }
  }

  return out;
}

RasterImage renderThermalRaster({
  required Float32List temperatures,
  required int width,
  required int height,
  required double tMin,
  required double tMax,
  required int scale,
  required RenderSettings settings,
}) {
  final oriented = displayOrientedSize(width, height, settings.rotation);
  final orientedTemps = orientForDisplay(
    temperatures,
    width,
    height,
    rotation: settings.rotation,
    hflip: settings.hflip,
    vflip: settings.vflip,
  );
  final dstW = oriented.width * scale;
  final dstH = oriented.height * scale;
  final expanded = settings.upscaleEnabled
      ? bilinearUpsample(
          orientedTemps,
          oriented.width,
          oriented.height,
          dstW,
          dstH,
        )
      : nearestUpsample(
          orientedTemps,
          oriented.width,
          oriented.height,
          dstW,
          dstH,
          scale,
        );

  final normalized = normalizeTemperatures(
    expanded,
    settings.rangeMin ?? tMin,
    settings.rangeMax ?? tMax,
  );
  final rgba = applyColorMap(normalized, settings.colorMap);
  if (settings.filter != ThermalFilter.none) {
    applyFilter(rgba, dstW, dstH, settings.filter);
  }
  return RasterImage(width: dstW, height: dstH, rgba: rgba);
}

Float32List bilinearUpsample(
  Float32List source,
  int srcW,
  int srcH,
  int dstW,
  int dstH,
) {
  final out = Float32List(dstW * dstH);
  final scaleX = (srcW - 1) / math.max(1, dstW - 1);
  final scaleY = (srcH - 1) / math.max(1, dstH - 1);

  for (var dy = 0; dy < dstH; dy++) {
    final sy = dy * scaleY;
    final y0 = sy.floor();
    final y1 = math.min(y0 + 1, srcH - 1);
    final fy = sy - y0;
    for (var dx = 0; dx < dstW; dx++) {
      final sx = dx * scaleX;
      final x0 = sx.floor();
      final x1 = math.min(x0 + 1, srcW - 1);
      final fx = sx - x0;
      final v00 = source[y0 * srcW + x0];
      final v10 = source[y0 * srcW + x1];
      final v01 = source[y1 * srcW + x0];
      final v11 = source[y1 * srcW + x1];
      out[dy * dstW + dx] =
          v00 * (1 - fx) * (1 - fy) +
          v10 * fx * (1 - fy) +
          v01 * (1 - fx) * fy +
          v11 * fx * fy;
    }
  }
  return out;
}

Float32List nearestUpsample(
  Float32List source,
  int srcW,
  int srcH,
  int dstW,
  int dstH,
  int scale,
) {
  final out = Float32List(dstW * dstH);
  for (var dy = 0; dy < dstH; dy++) {
    for (var dx = 0; dx < dstW; dx++) {
      final sx = math.min(srcW - 1, dx ~/ scale);
      final sy = math.min(srcH - 1, dy ~/ scale);
      out[dy * dstW + dx] = source[sy * srcW + sx];
    }
  }
  return out;
}

Uint8List normalizeTemperatures(Float32List values, double tMin, double tMax) {
  final out = Uint8List(values.length);
  final range = tMax > tMin ? tMax - tMin : 1.0;
  for (var i = 0; i < values.length; i++) {
    out[i] = (((values[i] - tMin) / range) * 255).clamp(0, 255).round();
  }
  return out;
}

Uint8List applyColorMap(Uint8List normalized, ThermalColorMap map) {
  final out = Uint8List(normalized.length * 4);
  for (var i = 0; i < normalized.length; i++) {
    final color = colorAt(normalized[i], map);
    out[i * 4] = color.$1;
    out[i * 4 + 1] = color.$2;
    out[i * 4 + 2] = color.$3;
    out[i * 4 + 3] = 255;
  }
  return out;
}

(int, int, int) colorAt(int value, ThermalColorMap map) {
  final t = value / 255.0;
  return switch (map) {
    ThermalColorMap.grayscale => (value, value, value),
    ThermalColorMap.blackHot => (255 - value, 255 - value, 255 - value),
    ThermalColorMap.rainbow => _hsvToRgb((240 - t * 240) / 360, 1, 1),
    ThermalColorMap.hot => _lerpStops(t, const [
      (0, 0, 0),
      (255, 0, 0),
      (255, 255, 0),
      (255, 255, 255),
    ]),
    ThermalColorMap.inferno => _lerpStops(t, const [
      (0, 0, 4),
      (58, 9, 99),
      (138, 34, 96),
      (215, 91, 16),
      (252, 255, 164),
    ]),
    ThermalColorMap.plasma => _lerpStops(t, const [
      (13, 8, 135),
      (125, 1, 168),
      (205, 72, 115),
      (249, 153, 30),
      (240, 249, 33),
    ]),
    ThermalColorMap.jet => _lerpStops(t, const [
      (0, 0, 143),
      (0, 0, 255),
      (0, 255, 255),
      (255, 255, 0),
      (255, 0, 0),
      (128, 0, 0),
    ]),
    ThermalColorMap.cool => _lerpStops(t, const [
      (0, 255, 255),
      (128, 0, 255),
      (255, 0, 128),
    ]),
    ThermalColorMap.ironbow => _lerpStops(t, const [
      (0, 0, 0),
      (45, 0, 55),
      (145, 5, 88),
      (205, 60, 15),
      (242, 165, 20),
      (255, 255, 255),
    ]),
  };
}

void applyFilter(Uint8List rgba, int width, int height, ThermalFilter filter) {
  final src = Uint8List.fromList(rgba);
  switch (filter) {
    case ThermalFilter.gaussian:
      _convolve(
        src,
        rgba,
        width,
        height,
        const [1, 2, 1, 2, 4, 2, 1, 2, 1],
        16,
        0,
      );
      break;
    case ThermalFilter.sharpen:
      _convolve(
        src,
        rgba,
        width,
        height,
        const [0, -1, 0, -1, 5, -1, 0, -1, 0],
        1,
        0,
      );
      break;
    case ThermalFilter.emboss:
      _convolve(
        src,
        rgba,
        width,
        height,
        const [-2, -1, 0, -1, 1, 1, 0, 1, 2],
        1,
        128,
      );
      break;
    case ThermalFilter.sobel:
      _sobel(src, rgba, width, height);
      break;
    case ThermalFilter.none:
      break;
  }
}

void _convolve(
  Uint8List src,
  Uint8List dst,
  int w,
  int h,
  List<int> k,
  int divisor,
  int bias,
) {
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var r = 0;
      var g = 0;
      var b = 0;
      for (var ky = 0; ky < 3; ky++) {
        for (var kx = 0; kx < 3; kx++) {
          final sx = (x + kx - 1).clamp(0, w - 1);
          final sy = (y + ky - 1).clamp(0, h - 1);
          final idx = (sy * w + sx) * 4;
          final weight = k[ky * 3 + kx];
          r += src[idx] * weight;
          g += src[idx + 1] * weight;
          b += src[idx + 2] * weight;
        }
      }
      final idx = (y * w + x) * 4;
      dst[idx] = (r / divisor + bias).round().clamp(0, 255);
      dst[idx + 1] = (g / divisor + bias).round().clamp(0, 255);
      dst[idx + 2] = (b / divisor + bias).round().clamp(0, 255);
      dst[idx + 3] = 255;
    }
  }
}

void _sobel(Uint8List src, Uint8List dst, int w, int h) {
  const gx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
  const gy = [-1, -2, -1, 0, 0, 0, 1, 2, 1];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var xr = 0;
      var yr = 0;
      for (var ky = 0; ky < 3; ky++) {
        for (var kx = 0; kx < 3; kx++) {
          final sx = (x + kx - 1).clamp(0, w - 1);
          final sy = (y + ky - 1).clamp(0, h - 1);
          final idx = (sy * w + sx) * 4;
          final gray =
              (0.299 * src[idx] + 0.587 * src[idx + 1] + 0.114 * src[idx + 2])
                  .round();
          xr += gray * gx[ky * 3 + kx];
          yr += gray * gy[ky * 3 + kx];
        }
      }
      final v = math.sqrt(xr * xr + yr * yr).round().clamp(0, 255);
      final idx = (y * w + x) * 4;
      dst[idx] = v;
      dst[idx + 1] = v;
      dst[idx + 2] = v;
      dst[idx + 3] = 255;
    }
  }
}

(int, int, int) _lerpStops(double t, List<(int, int, int)> stops) {
  final scaled = t * (stops.length - 1);
  final i = scaled.floor().clamp(0, stops.length - 2);
  final f = scaled - i;
  final a = stops[i];
  final b = stops[i + 1];
  return (
    (a.$1 + (b.$1 - a.$1) * f).round(),
    (a.$2 + (b.$2 - a.$2) * f).round(),
    (a.$3 + (b.$3 - a.$3) * f).round(),
  );
}

(int, int, int) _hsvToRgb(double h, double s, double v) {
  final i = (h * 6).floor();
  final f = h * 6 - i;
  final p = v * (1 - s);
  final q = v * (1 - f * s);
  final t = v * (1 - (1 - f) * s);
  final rgb = switch (i % 6) {
    0 => (v, t, p),
    1 => (q, v, p),
    2 => (p, v, t),
    3 => (p, q, v),
    4 => (t, p, v),
    _ => (v, p, q),
  };
  return (
    (rgb.$1 * 255).round(),
    (rgb.$2 * 255).round(),
    (rgb.$3 * 255).round(),
  );
}
