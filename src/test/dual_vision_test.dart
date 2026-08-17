import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/core/dual_vision.dart';

void main() {
  group('AlignParams.tryParseResponse', () {
    test('parses canonical ALIGN line and converts degrees to radians', () {
      // Firmware ships angle in degrees on the wire. The App inverts the
      // sign at the boundary so a CCW value on the wire becomes a CW
      // (screen-positive) radian internally.
      const text = 'OK\nALIGN 1.50 -2.00 1.020 1.020 -45.00 128\nready';
      final p = AlignParams.tryParseResponse(text);
      expect(p, isNotNull);
      expect(p!.tx, 1.50);
      expect(p.ty, -2.00);
      expect(p.sx, 1.020);
      expect(p.sy, 1.020);
      expect(p.ang, closeTo(math.pi / 4, 1e-9));
      expect(p.fusionAlpha, 128);
    });

    test('clamps fusion alpha into 0..255', () {
      const text = 'ALIGN 0 0 1 1 0 999';
      final p = AlignParams.tryParseResponse(text)!;
      expect(p.fusionAlpha, 255);
    });

    test('returns null when no ALIGN prefix present', () {
      const text = 'Some other output\nNot an align line';
      expect(AlignParams.tryParseResponse(text), isNull);
    });

    test('returns null on malformed numeric field', () {
      const text = 'ALIGN nope 0 1 1 0 128';
      expect(AlignParams.tryParseResponse(text), isNull);
    });

    test('returns null when fewer than six fields', () {
      const text = 'ALIGN 1 2 3';
      expect(AlignParams.tryParseResponse(text), isNull);
    });

    test('handles CRLF line terminators (firmware ships them)', () {
      const text = 'noise\r\nALIGN 0.10 0.20 1.000 1.000 0.00 64\r\nmore';
      final p = AlignParams.tryParseResponse(text);
      expect(p?.fusionAlpha, 64);
    });

    test(
      'finds ALIGN substring embedded in binary noise (probe during stream)',
      () {
        final text =
            '\u{FFFD}\u{FFFD}\u{FFFD}MLX40\u{FFFD}\u{FFFD}ALIGN 1.50 -2.00 1.020 1.020 0.00 128\n\u{FFFD}';
        final p = AlignParams.tryParseResponse(text);
        expect(p, isNotNull);
        expect(p!.tx, 1.50);
        expect(p.ang, 0.0);
        expect(p.fusionAlpha, 128);
      },
    );
  });

  group('AlignParams.formatSetAlign', () {
    test('emits angle in degrees with sign inverted at wire boundary', () {
      // 45 degrees CW internally → -45 degrees on the wire (see
      // AlignParams.formatSetAlign for the rationale).
      final p = AlignParams(
        tx: 1.5,
        ty: -2.0,
        sx: 1.02,
        sy: 1.02,
        ang: math.pi / 4,
        fusionAlpha: 128,
      );
      expect(p.formatSetAlign(), 'set_align 1.50 -2.00 1.020 1.020 -45.00');
    });

    test('round-trips through parser back to original radian value', () {
      final original = AlignParams(
        tx: 0,
        ty: 0,
        sx: 1.0,
        sy: 1.0,
        ang: math.pi / 6,
        fusionAlpha: 100,
      );
      final wire = original.formatSetAlign();
      // Emulate firmware echo: same fields, sample alpha appended.
      final echoed = '${wire.replaceFirst('set_align', 'ALIGN')} 100';
      final parsed = AlignParams.tryParseResponse(echoed);
      expect(parsed, isNotNull);
      expect(parsed!.ang, closeTo(math.pi / 6, 1e-4));
    });
  });

  group('AlignParams.copyWith', () {
    test('preserves untouched fields', () {
      const base = AlignParams.defaults;
      final next = base.copyWith(tx: 5.0, fusionAlpha: 200);
      expect(next.tx, 5.0);
      expect(next.fusionAlpha, 200);
      expect(next.sy, base.sy);
      expect(next.ang, base.ang);
    });
  });

  group('DualVisionState', () {
    test('default is unknown capability', () {
      const s = DualVisionState();
      expect(s.capability, DualVisionCapability.unknown);
      expect(s.isSupported, isFalse);
      expect(s.isProbing, isFalse);
    });

    test('clearError true wipes lastError', () {
      const s = DualVisionState(
        lastError: 'oops',
        capability: DualVisionCapability.unsupported,
      );
      final cleared = s.copyWith(clearError: true);
      expect(cleared.lastError, isNull);
      expect(cleared.capability, DualVisionCapability.unsupported);
    });
  });
}
