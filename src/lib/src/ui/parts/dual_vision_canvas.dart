part of '../../../main.dart';

// ============================ Interactive canvas ============================

/// Schematic calibration stage where the fixed camera frame and movable
/// thermal projection use clearly different visual languages.
///
/// The device does not send visible-light frames to the host, so this remains
/// an honest guide rather than pretending to be a live fusion preview.
class _AlignmentCanvas extends StatelessWidget {
  const _AlignmentCanvas({
    required this.cameraWidth,
    required this.cameraHeight,
    required this.thermalWidth,
    required this.thermalHeight,
    required this.params,
    required this.scaleLocked,
    required this.onChanged,
  });

  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final AlignParams params;
  final bool scaleLocked;
  final ValueChanged<AlignParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stage = FittedBox(
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
          colorScheme: colorScheme,
          scaleLocked: scaleLocked,
          onChanged: onChanged,
        ),
      ),
    );

    return AspectRatio(
      key: const ValueKey('dual-vision-canvas'),
      aspectRatio: cameraWidth / cameraHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: stage,
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _ParamReadout(params: params),
              ),
            ],
          ),
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
    required this.colorScheme,
    required this.scaleLocked,
    required this.onChanged,
  });

  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final AlignParams params;
  final ColorScheme colorScheme;
  final bool scaleLocked;
  final ValueChanged<AlignParams> onChanged;

  Offset get _stageCentre => Offset(cameraWidth / 2, cameraHeight / 2);

  Offset get _overlayCentre => _stageCentre + Offset(params.tx, params.ty);

  Size get _overlayHalfSize =>
      Size(thermalWidth * params.sx / 2, thermalHeight * params.sy / 2);

  Offset _stageToLocal(Offset stageVector) {
    final cosine = math.cos(-params.ang);
    final sine = math.sin(-params.ang);
    return Offset(
      stageVector.dx * cosine - stageVector.dy * sine,
      stageVector.dx * sine + stageVector.dy * cosine,
    );
  }

  Offset _localToStage(Offset localVector) {
    final cosine = math.cos(params.ang);
    final sine = math.sin(params.ang);
    return Offset(
      localVector.dx * cosine - localVector.dy * sine,
      localVector.dx * sine + localVector.dy * cosine,
    );
  }

  void _onTranslate(DragUpdateDetails details) {
    onChanged(
      params.copyWith(
        tx: (params.tx + details.delta.dx)
            .clamp(-cameraWidth / 2, cameraWidth / 2)
            .toDouble(),
        ty: (params.ty + details.delta.dy)
            .clamp(-cameraHeight / 2, cameraHeight / 2)
            .toDouble(),
      ),
    );
  }

  void _onScaleCorner(Offset _, Offset stageDelta, _Corner corner) {
    final localDelta = _stageToLocal(stageDelta);
    final newHalfWidth =
        (thermalWidth * params.sx / 2) + corner.signX * localDelta.dx;
    final newHalfHeight =
        (thermalHeight * params.sy / 2) + corner.signY * localDelta.dy;
    final nextSx = (2 * newHalfWidth / thermalWidth)
        .clamp(_dualVisionMinScale, _dualVisionMaxScale)
        .toDouble();
    final nextSy = (2 * newHalfHeight / thermalHeight)
        .clamp(_dualVisionMinScale, _dualVisionMaxScale)
        .toDouble();

    if (!scaleLocked) {
      onChanged(params.copyWith(sx: nextSx, sy: nextSy));
      return;
    }

    final factorX = nextSx / params.sx;
    final factorY = nextSy / params.sy;
    final factor = ((factorX + factorY) / 2).clamp(0.5, 1.5);
    onChanged(
      params.copyWith(
        sx: (params.sx * factor)
            .clamp(_dualVisionMinScale, _dualVisionMaxScale)
            .toDouble(),
        sy: (params.sy * factor)
            .clamp(_dualVisionMinScale, _dualVisionMaxScale)
            .toDouble(),
      ),
    );
  }

  void _onRotate(Offset stagePosition, Offset stageDelta) {
    final centre = _overlayCentre;
    final previous = stagePosition - stageDelta;
    final previousAngle = math.atan2(
      previous.dy - centre.dy,
      previous.dx - centre.dx,
    );
    final nextAngle = math.atan2(
      stagePosition.dy - centre.dy,
      stagePosition.dx - centre.dx,
    );
    var delta = nextAngle - previousAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    onChanged(
      params.copyWith(
        ang: (params.ang + delta)
            .clamp(_dualVisionMinAngle, _dualVisionMaxAngle)
            .toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayCentre = _overlayCentre;
    final halfSize = _overlayHalfSize;
    final localCorners = [
      (_Corner.topLeft, Offset(-halfSize.width, -halfSize.height)),
      (_Corner.topRight, Offset(halfSize.width, -halfSize.height)),
      (_Corner.bottomRight, Offset(halfSize.width, halfSize.height)),
      (_Corner.bottomLeft, Offset(-halfSize.width, halfSize.height)),
    ];
    final rotationHandleLocal = Offset(0, -halfSize.height - 24);
    final rotationHandleStage =
        overlayCentre + _localToStage(rotationHandleLocal);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CameraPainter(colorScheme: colorScheme),
            ),
          ),
        ),
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
            ),
          ),
        ),
        Positioned(
          left: overlayCentre.dx - halfSize.width,
          top: overlayCentre.dy - halfSize.height,
          width: halfSize.width * 2,
          height: halfSize.height * 2,
          child: Transform.rotate(
            angle: params.ang,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: _onTranslate,
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colorScheme.tertiary, width: 1.5),
                  ),
                  child: CustomPaint(
                    painter: _ThermalOverlayPainter(
                      alpha: params.fusionAlpha / 255,
                      color: colorScheme.tertiary,
                      gridColor: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        for (final (corner, localOffset) in localCorners)
          _Handle(
            position: overlayCentre + _localToStage(localOffset),
            cursor: corner.cursor,
            onDrag: (stagePosition, stageDelta) =>
                _onScaleCorner(stagePosition, stageDelta, corner),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RotationSpokePainter(
                overlayCentre: overlayCentre,
                halfHeight: halfSize.height,
                angle: params.ang,
                color: colorScheme.tertiary,
              ),
            ),
          ),
        ),
        _Handle(
          position: rotationHandleStage,
          cursor: SystemMouseCursors.grab,
          icon: Icons.rotate_right_rounded,
          circular: true,
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

typedef _HandleDragCallback =
    void Function(Offset stagePosition, Offset stageDelta);

class _Handle extends StatelessWidget {
  const _Handle({
    required this.position,
    required this.cursor,
    required this.onDrag,
    this.icon,
    this.circular = false,
  });

  final Offset position;
  final MouseCursor cursor;
  final _HandleDragCallback onDrag;
  final IconData? icon;
  final bool circular;

  static const double _hitSize = 28;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      left: position.dx - _hitSize / 2,
      top: position.dy - _hitSize / 2,
      width: _hitSize,
      height: _hitSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final stagePosition = Offset(
              position.dx + details.localPosition.dx - _hitSize / 2,
              position.dy + details.localPosition.dy - _hitSize / 2,
            );
            onDrag(stagePosition, details.delta);
          },
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.tertiary, width: 2),
                borderRadius: BorderRadius.circular(circular ? 999 : 4),
              ),
              child: SizedBox.square(
                dimension: circular ? 20 : 12,
                child: icon == null
                    ? null
                    : Icon(icon, size: 13, color: colorScheme.tertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotationSpokePainter extends CustomPainter {
  const _RotationSpokePainter({
    required this.overlayCentre,
    required this.halfHeight,
    required this.angle,
    required this.color,
  });

  final Offset overlayCentre;
  final double halfHeight;
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    Offset rotated(Offset local) =>
        overlayCentre +
        Offset(
          local.dx * cosine - local.dy * sine,
          local.dx * sine + local.dy * cosine,
        );
    final top = rotated(Offset(0, -halfHeight));
    final handle = rotated(Offset(0, -halfHeight - 24));
    canvas.drawLine(
      top,
      handle,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RotationSpokePainter oldDelegate) =>
      oldDelegate.overlayCentre != overlayCentre ||
      oldDelegate.halfHeight != halfHeight ||
      oldDelegate.angle != angle ||
      oldDelegate.color != color;
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

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
      final delta = end - start;
      final length = delta.distance;
      if (length == 0) return;
      final unit = delta / length;
      var travelled = 0.0;
      while (travelled < length) {
        final segment = math.min(dashOn, length - travelled);
        canvas.drawLine(
          start + unit * travelled,
          start + unit * (travelled + segment),
          paint,
        );
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
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CameraPainter extends CustomPainter {
  const _CameraPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..color = colorScheme.surfaceContainerHighest,
    );

    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    const cell = 40.0;
    for (var x = cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final centre = size.center(Offset.zero);
    final crosshairPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;
    canvas.drawCircle(centre, 8, crosshairPaint..style = PaintingStyle.stroke);
    canvas.drawLine(
      Offset(centre.dx - 16, centre.dy),
      Offset(centre.dx + 16, centre.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(centre.dx, centre.dy - 16),
      Offset(centre.dx, centre.dy + 16),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}

class _ThermalOverlayPainter extends CustomPainter {
  const _ThermalOverlayPainter({
    required this.alpha,
    required this.color,
    required this.gridColor,
  });

  final double alpha;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final opacity = 0.16 + alpha.clamp(0.0, 1.0) * 0.28;
    final rounded = RRect.fromRectAndRadius(bounds, const Radius.circular(3));
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRect(bounds, Paint()..color = color.withValues(alpha: opacity));

    final meshPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (var x = size.width / 8; x < size.width; x += size.width / 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), meshPaint);
    }
    for (var y = size.height / 6; y < size.height; y += size.height / 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), meshPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThermalOverlayPainter oldDelegate) =>
      oldDelegate.alpha != alpha ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
