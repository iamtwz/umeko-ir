// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.state,
    required this.controller,
    this.compact = false,
    this.showStreamButton = true,
  });

  final ThermalState state;
  final ThermalController controller;
  final bool compact;
  final bool showStreamButton;

  @override
  Widget build(BuildContext context) {
    final settings = state.renderSettings;
    final l10n = context.l10n;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStreamButton) ...[
              StreamToggleButton(state: state, controller: controller),
              const SizedBox(height: 14),
            ],
            OptionPopup<ThermalColorMap>(
              label: l10n.colorMap,
              icon: Icons.palette_outlined,
              value: settings.colorMap,
              values: ThermalColorMap.values,
              labelOf: (value) => value.label(l10n),
              onSelected: (value) => controller.updateRenderSettings(
                settings.copyWith(colorMap: value),
              ),
            ),
            const SizedBox(height: 12),
            OptionPopup<ThermalFilter>(
              label: l10n.filter,
              icon: Icons.auto_fix_high,
              value: settings.filter,
              values: ThermalFilter.values,
              labelOf: (value) => value.label(l10n),
              onSelected: (value) => controller.updateRenderSettings(
                settings.copyWith(filter: value),
              ),
            ),
            const SizedBox(height: 8),
            _CompactSwitchRow(
              value: settings.upscaleEnabled,
              label: l10n.bilinear,
              onChanged: (value) => controller.updateRenderSettings(
                settings.copyWith(upscaleEnabled: value),
              ),
            ),
            _AdvancedRenderSettings(
              settings: settings,
              controller: controller,
              label: l10n.advancedRenderSettings,
              horizontalFlipLabel: l10n.horizontalFlip,
              verticalFlipLabel: l10n.verticalFlip,
            ),
            if (!compact) ...[
              const Divider(height: 28),
              MetricRow(
                label: l10n.received,
                value: '${state.parserStats.bytesReceived} B',
              ),
              MetricRow(
                label: l10n.packetsMetric,
                value: '${state.parserStats.packetsFound}',
              ),
              MetricRow(
                label: l10n.format,
                value: state.parserStats.lastFormat?.name ?? '-',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          _MiniSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackColor = value
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final borderColor = value ? colorScheme.primary : colorScheme.outline;
    final thumbColor = value ? colorScheme.onPrimary : colorScheme.outline;
    return Semantics(
      toggled: value,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: thumbColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancedRenderSettings extends StatefulWidget {
  const _AdvancedRenderSettings({
    required this.settings,
    required this.controller,
    required this.label,
    required this.horizontalFlipLabel,
    required this.verticalFlipLabel,
  });

  final RenderSettings settings;
  final ThermalController controller;
  final String label;
  final String horizontalFlipLabel;
  final String verticalFlipLabel;

  @override
  State<_AdvancedRenderSettings> createState() =>
      _AdvancedRenderSettingsState();
}

class _AdvancedRenderSettingsState extends State<_AdvancedRenderSettings> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(top: 6),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _CompactSwitchRow(
              value: settings.hflip,
              label: widget.horizontalFlipLabel,
              onChanged: (value) => widget.controller.updateRenderSettings(
                settings.copyWith(hflip: value),
              ),
            ),
            _CompactSwitchRow(
              value: settings.vflip,
              label: widget.verticalFlipLabel,
              onChanged: (value) => widget.controller.updateRenderSettings(
                settings.copyWith(vflip: value),
              ),
            ),
            const SizedBox(height: 8),
            _RotationPicker(
              value: settings.rotation,
              onChanged: (value) => widget.controller.updateRenderSettings(
                settings.copyWith(rotation: value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportAdvancedRenderSettings extends StatefulWidget {
  const _ExportAdvancedRenderSettings({
    required this.settings,
    required this.label,
    required this.horizontalFlipLabel,
    required this.verticalFlipLabel,
    required this.onChanged,
  });

  final RenderSettings settings;
  final String label;
  final String horizontalFlipLabel;
  final String verticalFlipLabel;
  final ValueChanged<RenderSettings> onChanged;

  @override
  State<_ExportAdvancedRenderSettings> createState() =>
      _ExportAdvancedRenderSettingsState();
}

class _ExportAdvancedRenderSettingsState
    extends State<_ExportAdvancedRenderSettings> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(top: 6),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _CompactSwitchRow(
              value: settings.hflip,
              label: widget.horizontalFlipLabel,
              onChanged: (value) {
                widget.onChanged(settings.copyWith(hflip: value));
              },
            ),
            _CompactSwitchRow(
              value: settings.vflip,
              label: widget.verticalFlipLabel,
              onChanged: (value) {
                widget.onChanged(settings.copyWith(vflip: value));
              },
            ),
            const SizedBox(height: 8),
            _RotationPicker(
              value: settings.rotation,
              onChanged: (value) {
                widget.onChanged(settings.copyWith(rotation: value));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RotationPicker extends StatelessWidget {
  const _RotationPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const values = [0, 90, 180, 270];
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final item in values) ...[
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  alignment: Alignment.center,
                  color: value == item
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  child: Text(
                    '$item',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: value == item
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            if (item != values.last)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class StreamToggleButton extends StatelessWidget {
  const StreamToggleButton({
    super.key,
    required this.state,
    required this.controller,
  });

  final ThermalState state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = state.streaming ? l10n.stopStream : l10n.startStream;
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onPressed: state.connected
          ? state.streaming
                ? controller.stopStream
                : controller.startStream
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.streaming ? Icons.stop : Icons.play_arrow),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class RotationLabel extends StatelessWidget {
  const RotationLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class OptionPopup<T> extends StatelessWidget {
  const OptionPopup({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in values)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                Icon(item == value ? Icons.check : null, size: 18),
                const SizedBox(width: 8),
                Text(labelOf(item)),
              ],
            ),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
        child: Text(
          labelOf(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}
