// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class LivePane extends ConsumerWidget {
  const LivePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final viewer = ThermalViewerCard(state: state);
    final controls = ControlPanel(state: state, controller: controller);
    final points = ref.watch(thermalPointsProvider);
    final sidePanel = Column(
      children: [
        const RecordingControls(),
        const SizedBox(height: 12),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 180, child: LiveTemperatureChart()),
          const SizedBox(height: 12),
        ],
        Expanded(child: controls),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              children: [
                Expanded(child: viewer),
                const SizedBox(width: 16),
                SizedBox(width: 320, child: sidePanel),
              ],
            )
          : ListView(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: viewer,
                ),
                const SizedBox(height: 16),
                const RecordingControls(),
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SizedBox(height: 180, child: LiveTemperatureChart()),
                ],
                const SizedBox(height: 16),
                controls,
              ],
            ),
    );
  }
}

class LiveTemperatureChart extends ConsumerWidget {
  const LiveTemperatureChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(temperatureHistoryProvider);
    final points = ref.watch(thermalPointsProvider);
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TemperatureCurveChart(
          series: history.series,
          points: points,
          temperatureUnit: temperatureUnit,
        ),
      ),
    );
  }
}

class RecordingControls extends ConsumerWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(
      thermalControllerProvider.select((state) => state.currentFrame),
    );
    final recorder = ref.watch(recorderControllerProvider);
    final controller = ref.read(recorderControllerProvider.notifier);
    final storageAvailable = ref.watch(
      uirRepositoryProvider.select((repository) => repository.isAvailable),
    );
    final l10n = context.l10n;
    final busy = recorder.status == RecorderStatus.finalizing;
    final canUseFrame = frame != null && !busy && storageAvailable;
    final showRecordingStatus =
        recorder.isRecording || (busy && recorder.frameCount > 0);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _RecordingActionButton(
                    onPressed: canUseFrame
                        ? () => _captureSnapshot(context, controller)
                        : null,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: l10n.capture,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: recorder.isRecording
                      ? _RecordingActionButton(
                          onPressed: busy
                              ? null
                              : () => _stopRecording(context, controller),
                          icon: const Icon(Icons.stop),
                          label: l10n.stopRecording,
                        )
                      : _RecordingActionButton(
                          onPressed: canUseFrame
                              ? () => controller.startRecording()
                              : null,
                          icon: const Icon(Icons.fiber_manual_record),
                          label: l10n.record,
                        ),
                ),
              ],
            ),
            if (showRecordingStatus) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: recorder.isRecording
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.framesMetric(recorder.frameCount)}  ${_formatDuration(recorder.elapsed)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (recorder.error != null) ...[
              const SizedBox(height: 10),
              Text(
                recorder.error!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _captureSnapshot(
    BuildContext context,
    RecorderController controller,
  ) async {
    final entry = await controller.captureSnapshot();
    if (!context.mounted || entry == null) return;
    _showSingleSnackBar(context, context.l10n.captureSaved);
  }

  Future<void> _stopRecording(
    BuildContext context,
    RecorderController controller,
  ) async {
    final entry = await controller.stopRecording();
    if (!context.mounted || entry == null) return;
    _showSingleSnackBar(context, context.l10n.recordingSaved);
  }

  void _showSingleSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(message),
        action: SnackBarAction(
          label: context.l10n.close,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 2), controller.close);
  }
}

class _RecordingActionButton extends StatelessWidget {
  const _RecordingActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(data: const IconThemeData(size: 20), child: icon),
            const SizedBox(width: 8),
            Text(label, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class ThermalViewerCard extends ConsumerWidget {
  const ThermalViewerCard({super.key, required this.state});

  final ThermalState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = state.currentFrame;
    final l10n = context.l10n;
    final points = ref.watch(thermalPointsProvider);
    final pointsController = ref.read(thermalPointsProvider.notifier);
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: frame == null
                ? EmptyPanel(
                    icon: Icons.sensors_off,
                    title: l10n.noFrame,
                    subtitle: l10n.connectAndStartStream,
                  )
                : ThermalRasterView.frame(
                    frame,
                    settings: state.renderSettings,
                    scale: 14,
                    temperatureUnit: temperatureUnit,
                    points: points,
                    onPointAdded: pointsController.add,
                    onPointMoved: pointsController.move,
                    onPointRemoved: pointsController.remove,
                  ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Wrap(
              spacing: 8,
              children: [
                StatusPill(
                  label: l10n.packets(state.parserStats.packetsFound),
                  active: state.parserStats.packetsFound > 0,
                ),
                StatusPill(
                  label: state.parserStats.lastFormat?.name ?? l10n.noFormat,
                  active: state.parserStats.lastFormat != null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
