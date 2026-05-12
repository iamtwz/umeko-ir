// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class _LocalGalleryPreview extends ConsumerStatefulWidget {
  const _LocalGalleryPreview({required this.entry});

  final GalleryEntry entry;

  @override
  ConsumerState<_LocalGalleryPreview> createState() =>
      _LocalGalleryPreviewState();
}

class _GalleryThumbnailFrame extends StatelessWidget {
  const _GalleryThumbnailFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3.0,
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
    );
  }
}

class _LocalGalleryPreviewState extends ConsumerState<_LocalGalleryPreview> {
  late final Future<ThermalFrame?> _frameFuture;

  @override
  void initState() {
    super.initState();
    _frameFuture = _loadFirstFrame();
  }

  Future<ThermalFrame?> _loadFirstFrame() async {
    final bytes = await ref
        .read(uirRepositoryProvider)
        .readBytes(widget.entry.id);
    final document = const UirReader().read(bytes);
    return document.frames.isEmpty ? null : document.frames.first.frame;
  }

  @override
  Widget build(BuildContext context) {
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<ThermalFrame?>(
      future: _frameFuture,
      builder: (context, snapshot) {
        final frame = snapshot.data;
        if (frame == null) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: snapshot.hasError
                  ? Icon(
                      Icons.broken_image_outlined,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          );
        }
        return ThermalRasterView.frame(
          frame,
          settings: renderSettings,
          scale: 4,
          showOverlay: false,
          temperatureUnit: temperatureUnit,
        );
      },
    );
  }
}

class LocalUirViewer extends ConsumerStatefulWidget {
  const LocalUirViewer({super.key, required this.entry});

  final GalleryEntry entry;

  @override
  ConsumerState<LocalUirViewer> createState() => _LocalUirViewerState();
}

class _LocalUirViewerState extends ConsumerState<LocalUirViewer> {
  late final Future<UirPlaybackController> _controllerFuture;
  UirPlaybackController? _controller;

  @override
  void initState() {
    super.initState();
    _controllerFuture = _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<UirPlaybackController> _load() async {
    final bytes = await ref
        .read(uirRepositoryProvider)
        .readBytes(widget.entry.id);
    final controller = UirPlaybackController(const UirReader().read(bytes));
    _controller = controller;
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UirPlaybackController>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(widget.entry.name)),
          body: snapshot.hasError
              ? Center(child: Text(formatUserFacingError(snapshot.error)))
              : controller == null
              ? const Center(child: CircularProgressIndicator())
              : controller.isVideo
              ? _LocalUirPlaybackView(controller: controller)
              : _LocalUirPhotoView(controller: controller),
        );
      },
    );
  }
}

class _LocalUirPhotoView extends StatelessWidget {
  const _LocalUirPhotoView({required this.controller});

  final UirPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final frame = controller.currentFrame;
        return frame == null
            ? EmptyPanel(
                icon: Icons.broken_image_outlined,
                title: context.l10n.noReadableFrames,
                subtitle: context.l10n.noReadableFramesMessage,
              )
            : _ThermalFrameReviewView(
                frame: frame,
                points: controller.points,
                onPointAdded: controller.addPoint,
                onPointMoved: controller.movePoint,
                onPointRemoved: controller.removePoint,
              );
      },
    );
  }
}

class _LocalUirPlaybackView extends ConsumerWidget {
  const _LocalUirPlaybackView({required this.controller});

  final UirPlaybackController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    final liveState = ref.watch(thermalControllerProvider);
    final liveController = ref.read(thermalControllerProvider.notifier);
    final exporter = ref.watch(thermalExporterProvider);
    final filterControls = ControlPanel(
      state: liveState,
      controller: liveController,
      compact: true,
      showStreamButton: false,
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final points = controller.points;
        final series = buildTemperatureSeries(
          frames: controller.document.frames,
          points: points,
        );
        final frame = controller.currentFrame;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final viewer = frame == null
                ? EmptyPanel(
                    icon: Icons.broken_image_outlined,
                    title: context.l10n.noReadableFrames,
                    subtitle: context.l10n.noReadableFramesMessage,
                  )
                : ThermalRasterView.frame(
                    frame,
                    settings: renderSettings,
                    scale: wide ? 10 : 8,
                    temperatureUnit: temperatureUnit,
                    points: points,
                    onPointAdded: controller.addPoint,
                    onPointMoved: controller.movePoint,
                    onPointRemoved: controller.removePoint,
                  );
            final controls = _PlaybackControls(
              controller: controller,
              series: series,
              points: points,
              exporter: exporter,
              temperatureUnit: temperatureUnit,
              expandChart: wide,
            );
            if (!wide) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: math.max(280, constraints.maxHeight * 0.52),
                    child: viewer,
                  ),
                  const SizedBox(height: 12),
                  controls,
                  const SizedBox(height: 12),
                  filterControls,
                ],
              );
            }
            final bottomPanel = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 320, child: filterControls),
                const SizedBox(width: 12),
                Expanded(child: controls),
              ],
            );
            final bottomHeight = points.isEmpty ? 300.0 : 420.0;
            return Column(
              children: [
                Expanded(child: viewer),
                SizedBox(height: bottomHeight, child: bottomPanel),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.series,
    required this.points,
    required this.exporter,
    required this.temperatureUnit,
    this.expandChart = true,
  });

  final UirPlaybackController controller;
  final Map<String, List<TemperatureSample>> series;
  final List<ThermalPoint> points;
  final ThermalExporter exporter;
  final TemperatureUnit temperatureUnit;
  final bool expandChart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final frameCount = controller.frameCount;
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 3,
      overlayShape: SliderComponentShape.noOverlay,
      tickMarkShape: SliderTickMarkShape.noTickMark,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.previousFrame,
                    onPressed: frameCount > 1 ? controller.stepBackward : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: controller.isVideo
                        ? controller.togglePlay
                        : null,
                    child: Icon(
                      controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.nextFrame,
                    onPressed: frameCount > 1 ? controller.stepForward : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<double>(
                    tooltip: l10n.playbackSpeed,
                    onSelected: controller.setSpeed,
                    itemBuilder: (context) => [
                      for (final speed in _playbackSpeedOptions)
                        PopupMenuItem(
                          value: speed,
                          child: Text(_formatSpeed(speed)),
                        ),
                    ],
                    child: Chip(
                      label: Text(_formatSpeed(controller.speed)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${controller.currentIndex + 1}/$frameCount',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: sliderTheme,
              child: Slider(
                value: controller.currentIndex.toDouble(),
                min: 0,
                max: math.max(0, frameCount - 1).toDouble(),
                divisions: frameCount > 1 ? frameCount - 1 : null,
                onChanged: frameCount > 1
                    ? (value) => controller.seekToFrame(value.round())
                    : null,
              ),
            ),
            Text(
              '${_formatDuration(controller.position)} / ${_formatDuration(controller.duration)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (expandChart)
                Expanded(
                  child: _PlaybackTemperatureChartSection(
                    chart: chart,
                    onExport: () => _sharePlaybackCsv(context),
                  ),
                )
              else
                _PlaybackTemperatureChartSection(
                  chart: chart,
                  height: 190,
                  onExport: () => _sharePlaybackCsv(context),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget get chart {
    return TemperatureCurveChart(
      series: series,
      points: points,
      cursor: controller.position,
      fixedDuration: controller.duration,
      temperatureUnit: temperatureUnit,
    );
  }

  static const _playbackSpeedOptions = <double>[0.5, 0.75, 1, 1.25, 1.5, 2, 3];

  static String _formatSpeed(double value) {
    return value == value.roundToDouble()
        ? '${value.toInt()}x'
        : '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
  }

  Future<void> _sharePlaybackCsv(BuildContext context) async {
    final name = controller.document.metadata['name'] as String?;
    final exportName = name != null && name.trim().isNotEmpty
        ? '${name.trim()} temperature curve'
        : 'temperature-curve';
    try {
      await exporter.shareCsvText(
        name: exportName,
        csv: temperatureSeriesCsv(
          frames: controller.document.frames,
          points: points,
          temperatureUnit: temperatureUnit,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatUserFacingError(error))));
    }
  }
}

class _PlaybackTemperatureChartSection extends StatelessWidget {
  const _PlaybackTemperatureChartSection({
    required this.chart,
    required this.onExport,
    this.height,
  });

  final Widget chart;
  final VoidCallback onExport;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                context.l10n.temperatureCurves,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.table_chart_outlined),
                label: Text(context.l10n.exportCsv),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: chart),
      ],
    );
    if (height == null) return content;
    return SizedBox(height: height, child: content);
  }
}

void _showLocalFileInfo(
  BuildContext context,
  GalleryEntry entry,
  TemperatureUnit temperatureUnit,
) {
  final l10n = context.l10n;
  _showFileInfoDialog(
    context,
    title: l10n.fileInformation,
    rows: [
      _InfoRowData(l10n.fileName, entry.name),
      _InfoRowData(l10n.source, l10n.localRecordings),
      _InfoRowData(
        l10n.type,
        entry.kind == GalleryKind.photo ? l10n.photoKind : l10n.videoKind,
      ),
      _InfoRowData(l10n.resolution, '${entry.width}x${entry.height}'),
      if (entry.frameCount != null)
        _InfoRowData(l10n.frames, entry.frameCount.toString()),
      if (entry.duration != null)
        _InfoRowData(l10n.durationLabel, _formatDuration(entry.duration!)),
      _InfoRowData(
        l10n.temperatureRangeLabel,
        _temperatureRange(entry.tMin, entry.tMax, temperatureUnit),
      ),
      _InfoRowData(l10n.averageTemperature, temperatureUnit.format(entry.tAvg)),
      _InfoRowData(l10n.fileSize, _formatFileSize(entry.sizeBytes)),
      _InfoRowData(l10n.createdAt, _formatDateTime(entry.createdAt)),
    ],
  );
}

void _showDeviceFileInfo(
  BuildContext context,
  DevicePhoto photo,
  TemperatureUnit temperatureUnit,
) {
  final l10n = context.l10n;
  _showFileInfoDialog(
    context,
    title: l10n.fileInformation,
    rows: [
      _InfoRowData(l10n.fileName, photo.filename),
      _InfoRowData(l10n.source, l10n.deviceFilesSection),
      _InfoRowData(l10n.type, l10n.photoKind),
      _InfoRowData(l10n.fileFormat, _devicePhotoFormatLabel(photo.format)),
      _InfoRowData(l10n.resolution, '${photo.width}x${photo.height}'),
      _InfoRowData(
        l10n.temperatureRangeLabel,
        _temperatureRange(photo.tMin, photo.tMax, temperatureUnit),
      ),
      _InfoRowData(l10n.averageTemperature, temperatureUnit.format(photo.tAvg)),
      _InfoRowData(l10n.fileSize, _formatFileSize(photo.size)),
    ],
  );
}

void _showFileInfoDialog(
  BuildContext context, {
  required String title,
  required List<_InfoRowData> rows,
}) {
  showDialog<void>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          row.label,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          row.value,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      );
    },
  );
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);

  final String label;
  final String value;
}
