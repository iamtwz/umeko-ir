// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class GalleryTile extends ConsumerWidget {
  const GalleryTile({super.key, required this.photo});

  final DevicePhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    final canDelete = ref.watch(
      thermalControllerProvider.select(
        (state) => state.connected && !state.busy,
      ),
    );
    final controller = ref.read(thermalControllerProvider.notifier);
    final exporter = ref.watch(thermalExporterProvider);
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog.fullscreen(child: _DevicePhotoViewer(photo: photo)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image_outlined, color: colorScheme.primary),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.delete,
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: canDelete
                        ? () => controller.deletePhoto(photo.filename)
                        : null,
                  ),
                  PopupMenuButton<_GalleryMenuAction>(
                    tooltip: l10n.moreActions,
                    padding: EdgeInsets.zero,
                    onSelected: (action) {
                      switch (action) {
                        case _GalleryMenuAction.export:
                          _exportDevicePhoto(
                            context,
                            exporter,
                            renderSettings,
                            temperatureUnit,
                            const [],
                          );
                        case _GalleryMenuAction.fileInfo:
                          _showDeviceFileInfo(context, photo, temperatureUnit);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _GalleryMenuAction.export,
                        child: Text(l10n.export),
                      ),
                      PopupMenuItem(
                        value: _GalleryMenuAction.fileInfo,
                        child: Text(l10n.fileInformation),
                      ),
                    ],
                    child: const SizedBox.square(
                      dimension: 36,
                      child: Center(child: Icon(Icons.more_vert, size: 22)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _GalleryThumbnailFrame(
                child: ThermalRasterView(
                  temperatures: photo.temperatures,
                  width: photo.width,
                  height: photo.height,
                  tMin: photo.tMin,
                  tMax: photo.tMax,
                  settings: renderSettings,
                  scale: 4,
                  showOverlay: false,
                  temperatureUnit: temperatureUnit,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                photo.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _devicePhotoInfo(context, photo, temperatureUnit),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportDevicePhoto(
    BuildContext context,
    ThermalExporter exporter,
    RenderSettings renderSettings,
    TemperatureUnit temperatureUnit,
    List<ThermalPoint> points,
  ) async {
    final options = await _showPngExportOptions(
      context,
      renderSettings,
      sourceWidth: photo.width,
      sourceHeight: photo.height,
    );
    if (options == null) return;
    try {
      await exporter.shareFramePng(
        name: photo.filename,
        frame: _frameFromDevicePhoto(photo),
        settings: options.settings,
        points: points,
        temperatureUnit: temperatureUnit,
        includePoints: options.includePoints,
        includeLegend: options.includeLegend,
        exportScale: options.exportScale,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatUserFacingError(error))));
    }
  }
}

class _DevicePhotoViewer extends ConsumerStatefulWidget {
  const _DevicePhotoViewer({required this.photo});

  final DevicePhoto photo;

  @override
  ConsumerState<_DevicePhotoViewer> createState() => _DevicePhotoViewerState();
}

class _DevicePhotoViewerState extends ConsumerState<_DevicePhotoViewer> {
  var _points = const <ThermalPoint>[];

  @override
  Widget build(BuildContext context) {
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    final exporter = ref.watch(thermalExporterProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.photo.filename),
        actions: [
          IconButton(
            tooltip: context.l10n.export,
            onPressed: () => _exportCurrentPhoto(
              context,
              exporter,
              renderSettings,
              temperatureUnit,
            ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: _ThermalFrameReviewView(
        frame: _frameFromDevicePhoto(widget.photo),
        points: _points,
        onPointAdded: _addPoint,
        onPointMoved: _movePoint,
        onPointRemoved: _removePoint,
      ),
    );
  }

  Future<void> _exportCurrentPhoto(
    BuildContext context,
    ThermalExporter exporter,
    RenderSettings renderSettings,
    TemperatureUnit temperatureUnit,
  ) async {
    final options = await _showPngExportOptions(
      context,
      renderSettings,
      sourceWidth: widget.photo.width,
      sourceHeight: widget.photo.height,
    );
    if (options == null) return;
    try {
      await exporter.shareFramePng(
        name: widget.photo.filename,
        frame: _frameFromDevicePhoto(widget.photo),
        settings: options.settings,
        points: _points,
        temperatureUnit: temperatureUnit,
        includePoints: options.includePoints,
        includeLegend: options.includeLegend,
        exportScale: options.exportScale,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatUserFacingError(error))));
    }
  }

  void _addPoint(double xNorm, double yNorm) {
    final label = 'P${_points.length + 1}';
    setState(() {
      _points = [
        ..._points,
        ThermalPoint(
          id: 'device-point-${DateTime.now().microsecondsSinceEpoch}',
          xNorm: xNorm.clamp(0.0, 1.0),
          yNorm: yNorm.clamp(0.0, 1.0),
          label: label,
          colorArgb: _pointColorForIndex(_points.length),
        ),
      ];
    });
  }

  void _movePoint(String id, double xNorm, double yNorm) {
    setState(() {
      _points = [
        for (final point in _points)
          point.id == id
              ? point.copyWith(
                  xNorm: xNorm.clamp(0.0, 1.0),
                  yNorm: yNorm.clamp(0.0, 1.0),
                )
              : point,
      ];
    });
  }

  void _removePoint(String id) {
    setState(() {
      _points = _points.where((point) => point.id != id).toList();
    });
  }
}

class _ThermalFrameReviewView extends ConsumerWidget {
  const _ThermalFrameReviewView({
    required this.frame,
    required this.points,
    required this.onPointAdded,
    required this.onPointMoved,
    required this.onPointRemoved,
  });

  final ThermalFrame frame;
  final List<ThermalPoint> points;
  final void Function(double xNorm, double yNorm) onPointAdded;
  final void Function(String id, double xNorm, double yNorm) onPointMoved;
  final void Function(String id) onPointRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveState = ref.watch(thermalControllerProvider);
    final liveController = ref.read(thermalControllerProvider.notifier);
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final viewer = ThermalRasterView.frame(
          frame,
          settings: liveState.renderSettings,
          scale: wide ? 10 : 8,
          temperatureUnit: temperatureUnit,
          points: points,
          onPointAdded: onPointAdded,
          onPointMoved: onPointMoved,
          onPointRemoved: onPointRemoved,
        );
        final controls = ControlPanel(
          state: liveState,
          controller: liveController,
          compact: true,
          showStreamButton: false,
        );
        return wide
            ? Row(
                children: [
                  Expanded(child: viewer),
                  SizedBox(width: 320, child: controls),
                ],
              )
            : Column(
                children: [
                  Expanded(child: viewer),
                  SizedBox(height: 260, child: controls),
                ],
              );
      },
    );
  }
}

ThermalFrame _frameFromDevicePhoto(DevicePhoto photo) {
  return ThermalFrame(
    id: photo.filename,
    timestamp: DateTime.fromMicrosecondsSinceEpoch(0),
    temperatures: photo.temperatures,
    width: photo.width,
    height: photo.height,
    sensorType: ThermalSensorType.legacy,
    tMin: photo.tMin,
    tMax: photo.tMax,
    tAvg: photo.tAvg,
  );
}

int _pointColorForIndex(int index) {
  const colors = [
    0xffffd166,
    0xff06d6a0,
    0xffef476f,
    0xff118ab2,
    0xfff78c6b,
    0xffc77dff,
  ];
  return colors[index % colors.length];
}
