part of '../../../main.dart';

/// Fusion alpha, camera flip switches, and the collapsible fine-adjust
/// sliders. Scrollable; safe to embed in any vertical container.
class _ControlsSection extends StatelessWidget {
  const _ControlsSection({
    required this.params,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.showAdvanced,
    required this.onAdvancedToggled,
    required this.onAlphaChanged,
    required this.onAffineChanged,
    required this.onToggleVflip,
    required this.onToggleHflip,
  });

  final AlignParams params;
  final double cameraWidth;
  final double cameraHeight;
  final bool showAdvanced;
  final ValueChanged<bool> onAdvancedToggled;
  final ValueChanged<int> onAlphaChanged;
  final ValueChanged<AlignParams> onAffineChanged;
  final VoidCallback? onToggleVflip;
  final VoidCallback? onToggleHflip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        l10n.dualVisionFusionAlpha,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: params.fusionAlpha.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '${params.fusionAlpha}',
                        onChanged: (v) => onAlphaChanged(v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${params.fusionAlpha}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontFamily: _monoFontFamily,
                          fontFamilyFallback: _monoFontFallback,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                _FlipControl(
                  title: Text(
                    l10n.verticalFlipCamera,
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: params.vflip,
                  unknownLabel: l10n.dualVisionFlipStateUnknown,
                  toggleLabel: l10n.toggle,
                  onToggle: onToggleVflip,
                ),
                _FlipControl(
                  title: Text(
                    l10n.horizontalMirrorCamera,
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: params.hflip,
                  unknownLabel: l10n.dualVisionFlipStateUnknown,
                  toggleLabel: l10n.toggle,
                  onToggle: onToggleHflip,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Theme(
            // ExpansionTile draws a hairline top/bottom border by default
            // (via its `shape`/`collapsedShape` Borders) which read as a
            // stray black divider against the dark card. Suppress them so
            // the card matches the rest of the app's flat M3 surface.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                l10n.dualVisionFineAdjust,
                style: const TextStyle(fontSize: 13),
              ),
              initiallyExpanded: showAdvanced,
              onExpansionChanged: onAdvancedToggled,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      _FineSlider(
                        label: l10n.dualVisionTx,
                        value: params.tx,
                        min: -cameraWidth / 2,
                        max: cameraWidth / 2,
                        decimals: 2,
                        onChanged: (v) =>
                            onAffineChanged(params.copyWith(tx: v)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionTy,
                        value: params.ty,
                        min: -cameraHeight / 2,
                        max: cameraHeight / 2,
                        decimals: 2,
                        onChanged: (v) =>
                            onAffineChanged(params.copyWith(ty: v)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionSx,
                        value: params.sx,
                        min: _dualVisionMinScale,
                        max: _dualVisionMaxScale,
                        decimals: 3,
                        onChanged: (v) =>
                            onAffineChanged(params.copyWith(sx: v)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionSy,
                        value: params.sy,
                        min: _dualVisionMinScale,
                        max: _dualVisionMaxScale,
                        decimals: 3,
                        onChanged: (v) =>
                            onAffineChanged(params.copyWith(sy: v)),
                      ),
                      _FineSlider(
                        label: l10n.dualVisionAngle,
                        value: params.ang * 180 / math.pi,
                        min: _dualVisionMinAngle * 180 / math.pi,
                        max: _dualVisionMaxAngle * 180 / math.pi,
                        decimals: 1,
                        suffix: '°',
                        onChanged: (deg) => onAffineChanged(
                          params.copyWith(ang: deg * math.pi / 180),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    required this.toggleLabel,
    required this.onToggle,
  });

  final Widget title;
  final bool? value;
  final String unknownLabel;
  final String toggleLabel;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current != null) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: title,
        value: current,
        onChanged: onToggle == null ? null : (_) => onToggle!(),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: title,
      subtitle: Text(unknownLabel),
      trailing: OutlinedButton(onPressed: onToggle, child: Text(toggleLabel)),
    );
  }
}

// ============================ Param readout ===============================

class _ParamReadout extends StatelessWidget {
  const _ParamReadout({required this.params});

  final AlignParams params;

  @override
  Widget build(BuildContext context) {
    String f(double v, int digits) => v.toStringAsFixed(digits);
    final pieces = [
      ('tx', f(params.tx, 2)),
      ('ty', f(params.ty, 2)),
      ('sx', f(params.sx, 3)),
      ('sy', f(params.sy, 3)),
      // Display in degrees to match what the firmware accepts on the wire.
      ('ang', '${f(params.ang * 180 / math.pi, 2)}°'),
    ];
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, value) in pieces)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label ',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: _monoFontFamily,
                  fontFamilyFallback: _monoFontFallback,
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
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
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            label: '${clamped.toStringAsFixed(decimals)}$suffix',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '${clamped.toStringAsFixed(decimals)}$suffix',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: _monoFontFamily,
              fontFamilyFallback: _monoFontFallback,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
