// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class GalleryPane extends ConsumerWidget {
  const GalleryPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final localGallery = ref.watch(localGalleryProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final l10n = context.l10n;
    final localEntries = localGallery.asData?.value ?? const <GalleryEntry>[];
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l10n.deviceFilesSection),
                Tab(text: l10n.localRecordings),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _DeviceGalleryTab(state: state, controller: controller),
                  _LocalGalleryTab(
                    localGallery: localGallery,
                    entries: localEntries,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceGalleryTab extends StatelessWidget {
  const _DeviceGalleryTab({required this.state, required this.controller});

  final ThermalState state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: state.connected && !state.busy
                    ? controller.loadGallery
                    : null,
                icon: const Icon(Icons.sync),
                label: Text(l10n.readDevice),
              ),
              OutlinedButton.icon(
                onPressed: state.gallery.isEmpty
                    ? null
                    : () => confirmClearDevice(context, controller),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l10n.clearDevice),
              ),
            ],
          ),
        ),
        if (state.galleryLoading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.galleryTotal == 0
                ? null
                : state.galleryLoaded / state.galleryTotal,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${state.galleryLoaded}/${state.galleryTotal}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: state.gallery.isEmpty
              ? EmptyPanel(
                  icon: Icons.photo_library_outlined,
                  title: l10n.noDevicePhotos,
                  subtitle: l10n.readDeviceFiles,
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 218,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: state.gallery.length,
                  itemBuilder: (context, index) {
                    return GalleryTile(photo: state.gallery[index]);
                  },
                ),
        ),
        const SizedBox(height: 12),
        _GalleryFooter(text: l10n.deviceFiles(state.gallery.length)),
      ],
    );
  }
}

class _LocalGalleryTab extends StatelessWidget {
  const _LocalGalleryTab({required this.localGallery, required this.entries});

  final AsyncValue<List<GalleryEntry>> localGallery;
  final List<GalleryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    if (localGallery.isLoading) {
      return const Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(),
      );
    }
    if (localGallery.hasError) {
      return Text(
        formatUserFacingError(localGallery.error),
        style: TextStyle(color: colorScheme.error),
      );
    }
    final photoCount = entries
        .where((entry) => entry.kind == GalleryKind.photo)
        .length;
    final videoCount = entries
        .where((entry) => entry.kind == GalleryKind.video)
        .length;
    final footerText =
        '${l10n.localFiles(entries.length)} · '
        '${l10n.localFileBreakdown(photoCount, videoCount)}';
    if (entries.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: EmptyPanel(
              icon: Icons.folder_outlined,
              title: l10n.localRecordings,
              subtitle: l10n.localFileBreakdown(0, 0),
            ),
          ),
          const SizedBox(height: 12),
          _GalleryFooter(text: footerText),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 218,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return LocalGalleryTile(entry: entries[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
        _GalleryFooter(text: footerText),
      ],
    );
  }
}

class _GalleryFooter extends StatelessWidget {
  const _GalleryFooter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}

class LocalGalleryTile extends ConsumerWidget {
  const LocalGalleryTile({super.key, required this.entry});

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = entry.duration;
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final temperatureUnit = ref.watch(
      appSettingsProvider.select((settings) => settings.temperatureUnit),
    );
    final exporter = ref.watch(thermalExporterProvider);
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog.fullscreen(child: LocalUirViewer(entry: entry)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    entry.kind == GalleryKind.video
                        ? Icons.movie_outlined
                        : Icons.image_outlined,
                    color: colorScheme.primary,
                  ),
                  const Spacer(),
                  PopupMenuButton<_GalleryMenuAction>(
                    tooltip: l10n.moreActions,
                    padding: EdgeInsets.zero,
                    onSelected: (action) {
                      switch (action) {
                        case _GalleryMenuAction.export:
                          _exportLocalEntry(
                            context,
                            exporter,
                            renderSettings,
                            temperatureUnit,
                          );
                        case _GalleryMenuAction.fileInfo:
                          _showLocalFileInfo(context, entry, temperatureUnit);
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
              _GalleryThumbnailFrame(child: _LocalGalleryPreview(entry: entry)),
              const SizedBox(height: 8),
              Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _galleryEntryInfo(context, entry, duration, temperatureUnit),
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

  Future<void> _exportLocalEntry(
    BuildContext context,
    ThermalExporter exporter,
    RenderSettings renderSettings,
    TemperatureUnit temperatureUnit,
  ) async {
    final request = await _showLocalExportDialog(
      context,
      renderSettings,
      sourceWidth: entry.width,
      sourceHeight: entry.height,
      supportsApng: entry.kind == GalleryKind.video,
    );
    if (request == null) return;
    if (!context.mounted) return;
    try {
      switch (request.format) {
        case _LocalExportFormat.uir:
          await exporter.shareUir(entry);
        case _LocalExportFormat.png:
          final options = request.options;
          if (options == null) return;
          await exporter.sharePng(
            entry,
            options.settings,
            temperatureUnit: temperatureUnit,
            includePoints: options.includePoints,
            includeLegend: options.includeLegend,
            exportScale: options.exportScale,
          );
        case _LocalExportFormat.apng:
          final options = request.options;
          if (options == null) return;
          await _shareApngWithProgress(
            context,
            exporter,
            entry,
            options,
            temperatureUnit,
          );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatUserFacingError(error))));
    }
  }
}
