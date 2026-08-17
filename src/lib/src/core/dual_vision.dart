/// Dual-vision (visible-light + thermal fusion) calibration model.
///
/// This capability only exists on ESP32 dual-vision hardware (with OV2640/OV3660
/// camera). Devices without a camera (RP2040 Pico single-thermal) silently
/// ignore the related commands.
///
/// **Angle unit convention**: this class stores `ang` in **radians** because
/// every Flutter rendering primitive (`Transform.rotate`, `math.cos/sin`) wants
/// radians. The firmware exchanges the angle in **degrees** on the wire.
/// Conversion happens at the serial boundary only.
library;

import 'dart:math' as math;

class AlignParams {
  const AlignParams({
    required this.tx,
    required this.ty,
    required this.sx,
    required this.sy,
    required this.ang,
    required this.fusionAlpha,
    this.vflip,
    this.hflip,
  });

  /// Affine translation X (pixels relative to the camera frame).
  final double tx;

  /// Affine translation Y.
  final double ty;

  /// Affine scale X (~1.0 means thermal image matches camera 1:1).
  final double sx;

  /// Affine scale Y.
  final double sy;

  /// Affine rotation in radians.
  final double ang;

  /// Fusion alpha 0-255 (128 = half-transparent blend).
  final int fusionAlpha;

  /// Camera vertical flip — `null` if unknown.
  final bool? vflip;

  /// Camera horizontal mirror — `null` if unknown.
  final bool? hflip;

  /// Firmware alignment defaults.
  static const AlignParams defaults = AlignParams(
    tx: 0,
    ty: 0,
    sx: 1.0,
    sy: 1.0,
    ang: 0,
    fusionAlpha: 128,
  );

  AlignParams copyWith({
    double? tx,
    double? ty,
    double? sx,
    double? sy,
    double? ang,
    int? fusionAlpha,
    bool? vflip,
    bool? hflip,
  }) {
    return AlignParams(
      tx: tx ?? this.tx,
      ty: ty ?? this.ty,
      sx: sx ?? this.sx,
      sy: sy ?? this.sy,
      ang: ang ?? this.ang,
      fusionAlpha: fusionAlpha ?? this.fusionAlpha,
      vflip: vflip ?? this.vflip,
      hflip: hflip ?? this.hflip,
    );
  }

  /// Format for the firmware's `set_align` command.
  ///
  /// **Angle**: `ang` is converted from radians to degrees AND its sign is
  /// inverted on the wire. Internally `ang` follows screen-CW-positive (so
  /// dragging the rotation handle clockwise increases it, in line with
  /// `Transform.rotate`). The firmware's inverse-sampling matrix produces the
  /// opposite visual rotation for a positive wire value, so we negate at the
  /// boundary to keep the app canvas and device screen consistent.
  String formatSetAlign() {
    String f(double v, int digits) => v.toStringAsFixed(digits);
    final angDeg = -ang * 180 / math.pi;
    return 'set_align ${f(tx, 2)} ${f(ty, 2)} ${f(sx, 3)} ${f(sy, 3)} ${f(angDeg, 2)}';
  }

  @override
  bool operator ==(Object other) {
    return other is AlignParams &&
        other.tx == tx &&
        other.ty == ty &&
        other.sx == sx &&
        other.sy == sy &&
        other.ang == ang &&
        other.fusionAlpha == fusionAlpha &&
        other.vflip == vflip &&
        other.hflip == hflip;
  }

  @override
  int get hashCode =>
      Object.hash(tx, ty, sx, sy, ang, fusionAlpha, vflip, hflip);

  /// Parse the firmware response `ALIGN <tx> <ty> <sx> <sy> <ang> <alpha>`.
  ///
  /// The response may be embedded inside binary stream noise (when probing
  /// while the live stream is active), so we scan the full buffer for an
  /// `ALIGN ...` substring rather than relying on line splits — binary bytes
  /// rarely contain LF, so the `ALIGN` line can appear in the middle of a
  /// "line" after some garbage bytes when the firmware flushes mid-frame.
  ///
  /// Returns `null` when no recognisable `ALIGN` payload is found.
  static AlignParams? tryParseResponse(String text) {
    // 6 whitespace-separated numeric fields after the marker; the last one is
    // an integer alpha. We greedily capture each field independently.
    final pattern = RegExp(
      r'ALIGN\s+'
      r'(-?\d+(?:\.\d+)?)\s+'
      r'(-?\d+(?:\.\d+)?)\s+'
      r'(-?\d+(?:\.\d+)?)\s+'
      r'(-?\d+(?:\.\d+)?)\s+'
      r'(-?\d+(?:\.\d+)?)\s+'
      r'(\d+)',
    );
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    final tx = double.tryParse(match.group(1)!);
    final ty = double.tryParse(match.group(2)!);
    final sx = double.tryParse(match.group(3)!);
    final sy = double.tryParse(match.group(4)!);
    final ang = double.tryParse(match.group(5)!);
    final alpha = int.tryParse(match.group(6)!);
    if (tx == null ||
        ty == null ||
        sx == null ||
        sy == null ||
        ang == null ||
        alpha == null) {
      return null;
    }
    return AlignParams(
      tx: tx,
      ty: ty,
      sx: sx,
      sy: sy,
      // Firmware reports `ang` in degrees with the same screen-CCW-positive
      // convention used by `set_align`; negate to bring it into the App's
      // screen-CW-positive radian convention. See `formatSetAlign` for the
      // matching outbound conversion.
      ang: -ang * math.pi / 180,
      fusionAlpha: alpha.clamp(0, 255),
    );
  }
}

/// Whether the connected device supports the dual-vision capability.
///
/// Determined by probing `get_align\n` and looking for an `ALIGN ...` response
/// within a short timeout.
enum DualVisionCapability {
  /// Not yet probed (device just connected, or probe not run yet).
  unknown,

  /// Probe in flight.
  probing,

  /// Device responded with `ALIGN ...` → ESP32 dual-vision hardware.
  supported,

  /// Probe timed out or device returned no recognized response → likely
  /// RP2040 Pico single-thermal or unsupported firmware variant.
  unsupported,

  /// The probe could not complete because serial transport failed.
  error,
}

/// Aggregate state for the dual-vision feature exposed via the Device menu.
class DualVisionState {
  const DualVisionState({
    this.capability = DualVisionCapability.unknown,
    this.params,
    this.lastError,
  });

  final DualVisionCapability capability;

  /// Last-known params; `null` until first successful read.
  final AlignParams? params;

  /// Last write/read error message (transient, cleared on success).
  final String? lastError;

  bool get isSupported => capability == DualVisionCapability.supported;
  bool get isProbing => capability == DualVisionCapability.probing;

  DualVisionState copyWith({
    DualVisionCapability? capability,
    AlignParams? params,
    String? lastError,
    bool clearError = false,
  }) {
    return DualVisionState(
      capability: capability ?? this.capability,
      params: params ?? this.params,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
