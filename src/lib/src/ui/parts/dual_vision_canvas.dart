part of '../../../main.dart';

// ============================ Interactive canvas ============================

/// Schematic 2D canvas where the user drags / scales / rotates the thermal
/// overlay on top of a fixed camera FOV placeholder. 1 logical pixel of the
/// stage equals 1 firmware `tx` / `ty` unit; the stage is laid out at its
/// natural pixel size and centred inside the available width using
/// `FittedBox(fit: BoxFit.contain)` so the math stays simple.
class _AlignmentCanvas extends StatelessWidget {
  const _AlignmentCanvas({
    required this.cameraWidth,
    required this.cameraHeight,
    required this.thermalWidth,
    required this.thermalHeight,
    required this.params,
    required this.onChanged,
  });

  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final AlignParams params;
  final ValueChanged<AlignParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Camera FOV centred in stage; thermal overlay centred at (tx, ty)
    // offset from camera centre. Logical stage origin = top-left.
    final stage = LayoutBuilder(
      builder: (context, constraints) {
        // FittedBox handles downscaling on narrow screens; we report the
        // physical stage size in firmware pixels and let Flutter map gestures
        // back through the same transform.
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: cameraWidth,
            height: cameraHeight,
            child: _CanvasInner(
              cameraWidth: cameraWidth,
              cameraHeight: cameraHeight,
              thermalWidth: thermalWidth,
              thermalHeight: thermalHeight,
              params: params,
              onChanged: onChanged,
              colorScheme: colorScheme,
            ),
          ),
        );
      },
    );

    return AspectRatio(
      aspectRatio: cameraWidth / cameraHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: colorScheme.surfaceContainerHighest,
          child: stage,
        ),
      ),
    );
  }
}

class _CanvasInner extends StatelessWidget {
  const _CanvasInner({
    required this.cameraWidth,
    required this.cameraHeight,
    required this.thermalWidth,
    required this.thermalHeight,
    required this.params,
    required this.onChanged,
    required this.colorScheme,
  });

  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final AlignParams params;
  final ValueChanged<AlignParams> onChanged;
  final ColorScheme colorScheme;

  Offset get _stageCentre => Offset(cameraWidth / 2, cameraHeight / 2);

  /// Centre of the thermal overlay in stage coordinates.
  Offset get _overlayCentre => _stageCentre + Offset(params.tx, params.ty);

  /// Current half-extents of the overlay in stage pixels.
  Size get _overlayHalfSize =>
      Size(thermalWidth * params.sx / 2, thermalHeight * params.sy / 2);

  /// Convert a vector expressed in stage frame into the overlay's local
  /// (un-rotated) frame so we can decompose drags into sx/sy / rotation.
  Offset _stageToLocal(Offset stageVec) {
    final c = math.cos(-params.ang);
    final s = math.sin(-params.ang);
    return Offset(
      stageVec.dx * c - stageVec.dy * s,
      stageVec.dx * s + stageVec.dy * c,
    );
  }

  Offset _localToStage(Offset localVec) {
    final c = math.cos(params.ang);
    final s = math.sin(params.ang);
    return Offset(
      localVec.dx * c - localVec.dy * s,
      localVec.dx * s + localVec.dy * c,
    );
  }

  void _onTranslate(DragUpdateDetails d) {
    onChanged(
      params.copyWith(
        tx: (params.tx + d.delta.dx)
            .clamp(-cameraWidth / 2, cameraWidth / 2)
            .toDouble(),
        ty: (params.ty + d.delta.dy)
            .clamp(-cameraHeight / 2, cameraHeight / 2)
            .toDouble(),
      ),
    );
  }

  void _onScaleCorner(Offset _, Offset stageDelta, _Corner corner) {
    // Convert drag delta into the overlay's local frame, then read off how
    // the half-extent of the dragged corner changed.
    final localDelta = _stageToLocal(stageDelta);
    final signX = corner.signX;
    final signY = corner.signY;
    final newHalfWidth = (thermalWidth * params.sx / 2) + signX * localDelta.dx;
    final newHalfHeight =
        (thermalHeight * params.sy / 2) + signY * localDelta.dy;
    final newSx = (2 * newHalfWidth / thermalWidth).clamp(
      _dualVisionMinScale,
      _dualVisionMaxScale,
    );
    final newSy = (2 * newHalfHeight / thermalHeight).clamp(
      _dualVisionMinScale,
      _dualVisionMaxScale,
    );
    onChanged(params.copyWith(sx: newSx, sy: newSy));
  }

  void _onRotate(Offset stagePos, Offset stageDelta) {
    // Compute the angular change between the previous pointer position and
    // the current one, both measured around the overlay centre. Because
    // `_Handle` has already converted these into stage coordinates we share
    // an origin with `_overlayCentre` — the rotation finally moves at a
    // rate the user actually feels (the old version mixed handle-local and
    // stage coords, which made the computed delta collapse toward zero).
    final centre = _overlayCentre;
    final prev = stagePos - stageDelta;
    final a1 = math.atan2(prev.dy - centre.dy, prev.dx - centre.dx);
    final a2 = math.atan2(stagePos.dy - centre.dy, stagePos.dx - centre.dx);
    var delta = a2 - a1;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    onChanged(
      params.copyWith(
        ang: (params.ang + delta).clamp(
          _dualVisionMinAngle,
          _dualVisionMaxAngle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayCentre = _overlayCentre;
    final half = _overlayHalfSize;

    // Local-frame corner offsets (before rotation).
    final localCorners = [
      (_Corner.topLeft, Offset(-half.width, -half.height)),
      (_Corner.topRight, Offset(half.width, -half.height)),
      (_Corner.bottomRight, Offset(half.width, half.height)),
      (_Corner.bottomLeft, Offset(-half.width, half.height)),
    ];

    final rotationHandleLocal = Offset(0, -half.height - 24);
    final rotationHandleStage =
        overlayCentre + _localToStage(rotationHandleLocal);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Camera-FOV background painter (grid + crosshair).
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CameraBackgroundPainter(colorScheme: colorScheme),
            ),
          ),
        ),

        // Dashed reference frame at identity (tx=0, ty=0, sx=sy=1, ang=0).
        // Lets the user see how far the current overlay has shifted / scaled /
        // rotated away from the default position.
        Positioned(
          left: _stageCentre.dx - thermalWidth / 2,
          top: _stageCentre.dy - thermalHeight / 2,
          width: thermalWidth,
          height: thermalHeight,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DashedRectPainter(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  child: Text(
                    '100%',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.outline,
                      fontFamily: _monoFontFamily,
                      fontFamilyFallback: _monoFontFallback,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Thermal overlay rectangle: rotated, draggable to translate.
        Positioned(
          left: overlayCentre.dx - half.width,
          top: overlayCentre.dy - half.height,
          width: half.width * 2,
          height: half.height * 2,
          child: Transform.rotate(
            angle: params.ang,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: _onTranslate,
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.30),
                    border: Border.all(color: colorScheme.tertiary, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'THERMAL',
                      style: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                        fontSize: 11,
                        fontFamily: _monoFontFamily,
                        fontFamilyFallback: _monoFontFallback,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Corner handles (scale).
        for (final (corner, localOff) in localCorners)
          _Handle(
            position: overlayCentre + _localToStage(localOff),
            color: colorScheme.tertiary,
            cursor: corner.cursor,
            onDrag: (stagePos, stageDelta) =>
                _onScaleCorner(stagePos, stageDelta, corner),
          ),

        // Rotation spoke: a single line from the rectangle's top-edge midpoint
        // out to the rotation handle. Both endpoints share the same
        // `_localToStage` rotation around `overlayCentre`, so they always
        // remain visually attached as the angle changes. Previously this was
        // drawn via a Positioned+Transform.rotate Container, which used a
        // different pivot (the stick's bottom edge rather than the overlay
        // centre) and ended up painted *inside* the rectangle pointing the
        // wrong direction — making the real rotation handle hard to locate.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RotationSpokePainter(
                overlayCentre: overlayCentre,
                halfHeight: half.height,
                ang: params.ang,
                color: colorScheme.tertiary,
              ),
            ),
          ),
        ),
        _Handle(
          position: rotationHandleStage,
          color: colorScheme.tertiary,
          cursor: SystemMouseCursors.grab,
          icon: Icons.rotate_right,
          size: 26,
          onDrag: _onRotate,
        ),
      ],
    );
  }
}

enum _Corner {
  topLeft(-1, -1, SystemMouseCursors.resizeUpLeftDownRight),
  topRight(1, -1, SystemMouseCursors.resizeUpRightDownLeft),
  bottomRight(1, 1, SystemMouseCursors.resizeUpLeftDownRight),
  bottomLeft(-1, 1, SystemMouseCursors.resizeUpRightDownLeft);

  const _Corner(this.signX, this.signY, this.cursor);
  final double signX;
  final double signY;
  final MouseCursor cursor;
}

/// Signature used by [_Handle.onDrag]. The handle converts the raw gesture
/// into stage-frame coordinates before invoking the callback so callers do
/// not need to know about the handle's own local frame or size.
typedef _HandleDragCallback =
    void Function(Offset stagePosition, Offset stageDelta);

class _Handle extends StatelessWidget {
  const _Handle({
    required this.position,
    required this.color,
    required this.cursor,
    required this.onDrag,
    this.icon,
    this.size = 18,
  });

  final Offset position;
  final Color color;
  final MouseCursor cursor;
  final _HandleDragCallback onDrag;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            // Promote handle-local coords into stage coords so the callback
            // can do its math in the same frame as `_overlayCentre`.
            final stagePos = Offset(
              position.dx + d.localPosition.dx - size / 2,
              position.dy + d.localPosition.dy - size / 2,
            );
            onDrag(stagePos, d.delta);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            child: icon == null
                ? null
                : Icon(icon, size: size * 0.6, color: color),
          ),
        ),
      ),
    );
  }
}

/// Painter for the slim line that connects the thermal rectangle's top edge
/// to the rotation handle. Crucially, both endpoints are derived from the
/// same `_overlayCentre`-based rotation so the spoke and the rotation handle
/// (also positioned via the same rotation) never drift apart visually.
class _RotationSpokePainter extends CustomPainter {
  const _RotationSpokePainter({
    required this.overlayCentre,
    required this.halfHeight,
    required this.ang,
    required this.color,
  });

  final Offset overlayCentre;
  final double halfHeight;
  final double ang;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = math.cos(ang);
    final s = math.sin(ang);
    Offset rotated(Offset local) =>
        overlayCentre +
        Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
    final rectTop = rotated(Offset(0, -halfHeight));
    final handleEnd = rotated(Offset(0, -halfHeight - 24));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(rectTop, handleEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _RotationSpokePainter old) =>
      old.overlayCentre != overlayCentre ||
      old.halfHeight != halfHeight ||
      old.ang != ang ||
      old.color != color;
}

/// Paints a dashed rectangular outline that fills its bounds. Used as the
/// "100%" reference frame so the user has a constant anchor to compare the
/// dragged thermal overlay against.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashOn = 4.0;
    const dashOff = 3.0;

    void dashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length == 0) return;
      final ux = dx / length;
      final uy = dy / length;
      var travelled = 0.0;
      while (travelled < length) {
        final segLen = math.min(dashOn, length - travelled);
        final a = Offset(start.dx + ux * travelled, start.dy + uy * travelled);
        final b = Offset(
          start.dx + ux * (travelled + segLen),
          start.dy + uy * (travelled + segLen),
        );
        canvas.drawLine(a, b, paint);
        travelled += dashOn + dashOff;
      }
    }

    final topLeft = Offset.zero;
    final topRight = Offset(size.width, 0);
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);
    dashedLine(topLeft, topRight);
    dashedLine(topRight, bottomRight);
    dashedLine(bottomRight, bottomLeft);
    dashedLine(bottomLeft, topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

class _CameraBackgroundPainter extends CustomPainter {
  _CameraBackgroundPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 0.6;
    const cell = 40.0;
    for (var x = cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Crosshair
    final crossPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - 12), Offset(cx, cy + 12), crossPaint);

    // Camera frame border
    final borderPaint = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CameraBackgroundPainter old) =>
      old.colorScheme != colorScheme;
}
