part of '../../../main.dart';

/// Product-facing controls for dual-vision calibration.
///
/// The canvas remains the fastest way to make broad adjustments. These
/// controls provide deterministic one-pixel / one-degree steps and keep the
/// firmware's raw parameter values out of the primary interaction path.
class _ControlsSection extends StatelessWidget {
  const _ControlsSection({
    required this.params,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.showAdvanced,
    required this.scaleLocked,
    required this.onAdvancedToggled,
    required this.onScaleLockChanged,
    required this.onAlphaChanged,
    required this.onAffineChanged,
    required this.onToggleVflip,
    required this.onToggleHflip,
  });

  final AlignParams params;
  final double cameraWidth;
  final double cameraHeight;
  final bool showAdvanced;
  final bool scaleLocked;
  final ValueChanged<bool> onAdvancedToggled;
  final ValueChanged<bool> onScaleLockChanged;
  final ValueChanged<int> onAlphaChanged;
  final ValueChanged<AlignParams> onAffineChanged;
  final VoidCallback? onToggleVflip;
  final VoidCallback? onToggleHflip;

  void _nudge(double dx, double dy) {
    onAffineChanged(
      params.copyWith(
        tx: (params.tx + dx)
            .clamp(-cameraWidth / 2, cameraWidth / 2)
            .toDouble(),
        ty: (params.ty + dy)
            .clamp(-cameraHeight / 2, cameraHeight / 2)
            .toDouble(),
      ),
    );
  }

  void _stepUniformScale(double factor) {
    onAffineChanged(
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

  void _stepAxisScale({required bool horizontal, required double delta}) {
    onAffineChanged(
      params.copyWith(
        sx: horizontal
            ? (params.sx + delta)
                  .clamp(_dualVisionMinScale, _dualVisionMaxScale)
                  .toDouble()
            : params.sx,
        sy: horizontal
            ? params.sy
            : (params.sy + delta)
                  .clamp(_dualVisionMinScale, _dualVisionMaxScale)
                  .toDouble(),
      ),
    );
  }

  void _stepAngle(double degrees) {
    onAffineChanged(
      params.copyWith(
        ang: (params.ang + degrees * math.pi / 180)
            .clamp(_dualVisionMinAngle, _dualVisionMaxAngle)
            .toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alphaPercent = (params.fusionAlpha * 100 / 255).round();
    final averageScale = (params.sx + params.sy) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          icon: Icons.layers_rounded,
          title: l10n.dualVisionFusionAlpha,
          trailing: _ValueBadge('$alphaPercent%'),
          child: Column(
            children: [
              Slider(
                value: alphaPercent.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$alphaPercent%',
                onChanged: (value) =>
                    onAlphaChanged((value * 255 / 100).round()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0%'),
                    Text(
                      'α ${params.fusionAlpha}/255',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: _monoFontFamily,
                        fontFamilyFallback: _monoFontFallback,
                        fontSize: 11,
                      ),
                    ),
                    const Text('100%'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.center_focus_strong_rounded,
          title: l10n.dualVisionAlignmentControls,
          child: Column(
            children: [
              _TranslationControl(
                tx: params.tx,
                ty: params.ty,
                onNudge: _nudge,
              ),
              const SizedBox(height: 16),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.dualVisionScale,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Tooltip(
                    message: scaleLocked
                        ? l10n.dualVisionScaleLinked
                        : l10n.dualVisionScaleUnlinked,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onScaleLockChanged(!scaleLocked),
                      icon: Icon(scaleLocked ? Icons.link : Icons.link_off),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (scaleLocked)
                _ParameterStepper(
                  label: l10n.dualVisionUniformScale,
                  value: '${(averageScale * 100).toStringAsFixed(1)}%',
                  onDecrease: () => _stepUniformScale(0.99),
                  onIncrease: () => _stepUniformScale(1.01),
                )
              else ...[
                _ParameterStepper(
                  label: l10n.dualVisionSx,
                  value: '${(params.sx * 100).toStringAsFixed(1)}%',
                  onDecrease: () =>
                      _stepAxisScale(horizontal: true, delta: -0.01),
                  onIncrease: () =>
                      _stepAxisScale(horizontal: true, delta: 0.01),
                ),
                const SizedBox(height: 8),
                _ParameterStepper(
                  label: l10n.dualVisionSy,
                  value: '${(params.sy * 100).toStringAsFixed(1)}%',
                  onDecrease: () =>
                      _stepAxisScale(horizontal: false, delta: -0.01),
                  onIncrease: () =>
                      _stepAxisScale(horizontal: false, delta: 0.01),
                ),
              ],
              const SizedBox(height: 12),
              _ParameterStepper(
                label: l10n.dualVisionAngle,
                value: '${(params.ang * 180 / math.pi).toStringAsFixed(1)}°',
                onDecrease: () => _stepAngle(-0.5),
                onIncrease: () => _stepAngle(0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('dual-vision-quick-adjust'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.tune_rounded),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                l10n.dualVisionQuickAdjust,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(l10n.dualVisionQuickAdjustSubtitle),
              initiallyExpanded: showAdvanced,
              onExpansionChanged: onAdvancedToggled,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      _FineSlider(
                        label: l10n.dualVisionTx,
                        value: params.tx,
                        min: -cameraWidth / 2,
                        max: cameraWidth / 2,
                        decimals: 2,
                        onChanged: (value) =>
                            onAffineChanged(params.copyWith(tx: value)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionTy,
                        value: params.ty,
                        min: -cameraHeight / 2,
                        max: cameraHeight / 2,
                        decimals: 2,
                        onChanged: (value) =>
                            onAffineChanged(params.copyWith(ty: value)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionSx,
                        value: params.sx,
                        min: _dualVisionMinScale,
                        max: _dualVisionMaxScale,
                        decimals: 3,
                        onChanged: (value) {
                          if (!scaleLocked) {
                            onAffineChanged(params.copyWith(sx: value));
                            return;
                          }
                          final factor = value / params.sx;
                          onAffineChanged(
                            params.copyWith(
                              sx: value,
                              sy: (params.sy * factor)
                                  .clamp(
                                    _dualVisionMinScale,
                                    _dualVisionMaxScale,
                                  )
                                  .toDouble(),
                            ),
                          );
                        },
                      ),
                      _FineSlider(
                        label: l10n.dualVisionSy,
                        value: params.sy,
                        min: _dualVisionMinScale,
                        max: _dualVisionMaxScale,
                        decimals: 3,
                        enabled: !scaleLocked,
                        onChanged: (value) =>
                            onAffineChanged(params.copyWith(sy: value)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionAngle,
                        value: params.ang * 180 / math.pi,
                        min: _dualVisionMinAngle * 180 / math.pi,
                        max: _dualVisionMaxAngle * 180 / math.pi,
                        decimals: 1,
                        suffix: '°',
                        onChanged: (degrees) => onAffineChanged(
                          params.copyWith(ang: degrees * math.pi / 180),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('dual-vision-camera-orientation'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.flip_camera_android_rounded),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                l10n.dualVisionCameraOrientation,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(l10n.dualVisionCameraFlipSubtitle),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _FlipControl(
                  title: Text(l10n.verticalFlipCamera),
                  value: params.vflip,
                  unknownLabel: l10n.dualVisionFlipStateUnknown,
                  onToggle: onToggleVflip,
                ),
                _FlipControl(
                  title: Text(l10n.horizontalMirrorCamera),
                  value: params.hflip,
                  unknownLabel: l10n.dualVisionFlipStateUnknown,
                  onToggle: onToggleHflip,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          value,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _TranslationControl extends StatelessWidget {
  const _TranslationControl({
    required this.tx,
    required this.ty,
    required this.onNudge,
  });

  final double tx;
  final double ty;
  final void Function(double dx, double dy) onNudge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dualVisionPosition,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'X ${tx.toStringAsFixed(1)}   Y ${ty.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: _monoFontFamily,
                  fontFamilyFallback: _monoFontFallback,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 112,
          child: Column(
            children: [
              _NudgeButton(
                icon: Icons.keyboard_arrow_up,
                onPressed: () => onNudge(0, -1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NudgeButton(
                    icon: Icons.keyboard_arrow_left,
                    onPressed: () => onNudge(-1, 0),
                  ),
                  Icon(
                    Icons.control_camera_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  _NudgeButton(
                    icon: Icons.keyboard_arrow_right,
                    onPressed: () => onNudge(1, 0),
                  ),
                ],
              ),
              _NudgeButton(
                icon: Icons.keyboard_arrow_down,
                onPressed: () => onNudge(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _ParameterStepper extends StatelessWidget {
  const _ParameterStepper({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDecrease,
                icon: const Icon(Icons.remove, size: 18),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _monoFontFamily,
                    fontFamilyFallback: _monoFontFallback,
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onIncrease,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlipControl extends StatelessWidget {
  const _FlipControl({
    required this.title,
    required this.value,
    required this.unknownLabel,
    required this.onToggle,
  });

  final Widget title;
  final bool? value;
  final String unknownLabel;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: title,
      subtitle: current == null ? Text(unknownLabel) : null,
      value: current ?? false,
      onChanged: onToggle == null ? null : (_) => onToggle!(),
    );
  }
}

// ============================ Param readout ===============================

class _ParamReadout extends StatelessWidget {
  const _ParamReadout({required this.params});

  final AlignParams params;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        _ReadoutChip(
          icon: Icons.open_with_rounded,
          label: l10n.dualVisionTranslate,
          value:
              'X ${params.tx.toStringAsFixed(1)}  Y ${params.ty.toStringAsFixed(1)}',
        ),
        _ReadoutChip(
          icon: Icons.aspect_ratio_rounded,
          label: l10n.dualVisionScale,
          value:
              '${(params.sx * 100).toStringAsFixed(0)}% × ${(params.sy * 100).toStringAsFixed(0)}%',
        ),
        _ReadoutChip(
          icon: Icons.rotate_right_rounded,
          label: l10n.dualVisionAngle,
          value: '${(params.ang * 180 / math.pi).toStringAsFixed(1)}°',
        ),
      ],
    );
  }
}

class _ReadoutChip extends StatelessWidget {
  const _ReadoutChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 14),
            const SizedBox(width: 5),
            Text(
              '$label  ',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontFamily: _monoFontFamily,
                fontFamilyFallback: _monoFontFallback,
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ Fine slider row =============================

class _FineSlider extends StatelessWidget {
  const _FineSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
    this.suffix = '',
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final String suffix;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${clamped.toStringAsFixed(decimals)}$suffix',
                style: TextStyle(
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontFamily: _monoFontFamily,
                  fontFamilyFallback: _monoFontFallback,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: clamped,
            min: min,
            max: max,
            label: '${clamped.toStringAsFixed(decimals)}$suffix',
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
