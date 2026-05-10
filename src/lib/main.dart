import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/application/app_settings_controller.dart';
import 'src/application/build_channel.dart';
import 'src/application/posthog_service.dart';
import 'src/application/sentry_service.dart';
import 'src/application/temperature_history_controller.dart';
import 'src/application/thermal_points_controller.dart';
import 'src/application/thermal_controller.dart';
import 'src/core/temperature_series.dart';
import 'src/application/update_service.dart';
import 'src/core/device_gallery.dart';
import 'src/core/thermal_points.dart';
import 'src/core/thermal_rendering.dart';
import 'src/l10n/app_localizations.dart';
import 'src/playback/playback_controller.dart';
import 'src/playback/uir_reader.dart';
import 'src/recording/recorder_controller.dart';
import 'src/serial/serial_adapter.dart';
import 'src/storage/gallery_entry.dart';
import 'src/ui/temperature_curve_chart.dart';
import 'src/ui/thermal_raster_view.dart';

const _monoFontFamily = 'Menlo';
const _monoFontFallback = ['SF Mono', 'Monaco', 'Courier New', 'Courier'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesAsync();
  final appTrackingEnabled =
      await preferences.getBool(appTrackingEnabledPreferenceKey) ?? true;
  await configurePostHog(enabled: appTrackingEnabled);
  await configureSentry(
    enabled: appTrackingEnabled,
    appRunner: () => runApp(const ProviderScope(child: UmekoIrApp())),
  );
}

class UmekoIrApp extends ConsumerWidget {
  const UmekoIrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final navigatorObservers = <NavigatorObserver>[
      if (settings.appTrackingEnabled && isSentryConfigured)
        SentryNavigatorObserver(),
      if (settings.appTrackingEnabled && isPostHogConfigured) PosthogObserver(),
    ];
    return MaterialApp(
      onGenerateTitle: (context) => appDisplayName(context.l10n.appTitle),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      themeMode: settings.themeMode,
      theme: _buildAppTheme(Brightness.light),
      darkTheme: _buildAppTheme(Brightness.dark),
      navigatorObservers: navigatorObservers,
      home: const AppShell(),
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff2dd4bf),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: dark
        ? const Color(0xff0b0f14)
        : const Color(0xfff8fafc),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff111821) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      isDense: true,
    ),
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(1)} MB';
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  bool _updateCheckStarted = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettingsState>(appSettingsProvider, (_, settings) {
      _maybeStartUpdateCheck(settings);
    });
    final error = ref.watch(
      thermalControllerProvider.select((state) => state.error),
    );
    final controller = ref.read(thermalControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final l10n = context.l10n;

    final content = switch (_index) {
      0 => const LivePane(),
      1 => const GalleryPane(),
      2 => const DebugPane(),
      _ => const AppSettingsPane(),
    };

    return Scaffold(
      body: SafeArea(
        bottom: wide,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                minWidth: 76,
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.thermostat, color: Color(0xfff97316)),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.monitor_heart_outlined),
                    selectedIcon: const Icon(Icons.monitor_heart),
                    label: Text(l10n.live),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.photo_library_outlined),
                    selectedIcon: const Icon(Icons.photo_library),
                    label: Text(l10n.gallery),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.terminal_outlined),
                    selectedIcon: const Icon(Icons.terminal),
                    label: Text(l10n.debug),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(l10n.settings),
                  ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  const TopBar(),
                  if (error != null)
                    ErrorStrip(message: error, onClose: controller.clearError),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.monitor_heart_outlined),
                  selectedIcon: const Icon(Icons.monitor_heart),
                  label: l10n.live,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.photo_library_outlined),
                  selectedIcon: const Icon(Icons.photo_library),
                  label: l10n.gallery,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.terminal_outlined),
                  selectedIcon: const Icon(Icons.terminal),
                  label: l10n.debug,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: l10n.settings,
                ),
              ],
            ),
    );
  }

  void _maybeStartUpdateCheck(AppSettingsState settings) {
    if (!settings.loaded ||
        !settings.autoUpdateCheckEnabled ||
        _updateCheckStarted) {
      return;
    }
    _updateCheckStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkForUpdates());
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final packageInfo = await ref.read(packageInfoProvider.future);
      final update = await checkForUpdate(currentVersion: packageInfo.version);
      if (!mounted || update == null) return;

      final l10n = context.l10n;
      final openDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.updateAvailableTitle),
          content: Text(l10n.updateAvailableMessage(update.version)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.downloadUpdate),
            ),
          ],
        ),
      );
      if (openDownload == true) {
        await launchUrl(update.htmlUrl, mode: LaunchMode.externalApplication);
      }
    } catch (error, stackTrace) {
      debugPrint('Update check failed: $error\n$stackTrace');
    }
  }
}

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      thermalControllerProvider.select(_TopBarSnapshot.fromState),
    );
    final controller = ref.read(thermalControllerProvider.notifier);
    final compact = MediaQuery.sizeOf(context).width < 980;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: 10,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(state: state, controller: controller),
                  if (_showPortPicker(state)) ...[
                    const SizedBox(height: 10),
                    _PortPicker(state: state, controller: controller),
                  ],
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _HeaderRow(state: state, controller: controller),
                  ),
                  if (_showPortPicker(state)) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 360,
                      child: _PortPicker(state: state, controller: controller),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  bool _showPortPicker(_TopBarSnapshot state) {
    return !kIsWeb || state.ports.any((port) => !port.virtual);
  }
}

class _TopBarSnapshot {
  const _TopBarSnapshot({
    required this.ports,
    required this.selectedPort,
    required this.connected,
    required this.streaming,
    required this.busy,
  });

  factory _TopBarSnapshot.fromState(ThermalState state) {
    return _TopBarSnapshot(
      ports: state.ports,
      selectedPort: state.selectedPort,
      connected: state.connected,
      streaming: state.streaming,
      busy: state.busy,
    );
  }

  final List<SerialPortDescriptor> ports;
  final SerialPortDescriptor? selectedPort;
  final bool connected;
  final bool streaming;
  final bool busy;

  @override
  bool operator ==(Object other) {
    return other is _TopBarSnapshot &&
        other.ports == ports &&
        other.selectedPort == selectedPort &&
        other.connected == connected &&
        other.streaming == streaming &&
        other.busy == busy;
  }

  @override
  int get hashCode {
    return Object.hash(ports, selectedPort, connected, streaming, busy);
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.state, required this.controller});

  final _TopBarSnapshot state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = <Widget>[
          StatusPill(
            label: state.connected ? l10n.connected : l10n.disconnected,
            active: state.connected,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.refreshPorts,
            onPressed: state.busy ? null : controller.refreshPorts,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.deviceSettings,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
            icon: const Icon(Icons.tune),
          ),
          FilledButton.icon(
            onPressed: state.busy
                ? null
                : state.connected
                ? controller.disconnect
                : controller.connect,
            icon: Icon(state.connected ? Icons.link_off : Icons.usb),
            label: Text(
              state.connected ? l10n.disconnect : l10n.connect,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ];
        final title = Text(
          l10n.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: controls,
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            ...controls,
          ],
        );
      },
    );
  }
}

class _PortPicker extends StatelessWidget {
  const _PortPicker({required this.state, required this.controller});

  final _TopBarSnapshot state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visiblePorts = state.ports.where((port) => !port.virtual).toList();
    final selectedPort =
        visiblePorts.any((port) => port.id == state.selectedPort?.id)
        ? state.selectedPort
        : null;
    return PopupMenuButton<SerialPortDescriptor>(
      enabled:
          visiblePorts.isNotEmpty &&
          !(state.connected || state.busy || state.streaming),
      onSelected: controller.selectPort,
      itemBuilder: (context) => [
        for (final port in visiblePorts)
          PopupMenuItem(
            value: port,
            child: PortOption(port: port),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.cable),
          labelText: l10n.serialPort,
        ),
        child: SizedBox(
          height: 36,
          child: Align(
            alignment: selectedPort == null && visiblePorts.isEmpty
                ? Alignment.center
                : Alignment.centerLeft,
            child: selectedPort == null
                ? PortPlaceholder(
                    text: visiblePorts.isEmpty
                        ? l10n.noSerialPorts
                        : l10n.chooseSerialPort,
                    centered: visiblePorts.isEmpty,
                  )
                : PortOption(
                    port: selectedPort,
                    dense: true,
                    reserveDescription: true,
                  ),
          ),
        ),
      ),
    );
  }
}

class PortPlaceholder extends StatelessWidget {
  const PortPlaceholder({super.key, required this.text, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class PortOption extends StatelessWidget {
  const PortOption({
    super.key,
    required this.port,
    this.dense = false,
    this.reserveDescription = false,
  });

  final SerialPortDescriptor port;
  final bool dense;
  final bool reserveDescription;

  @override
  Widget build(BuildContext context) {
    final description = port.description;
    final hasDescription = description != null && description.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          port.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: dense ? 14 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasDescription || reserveDescription)
          Text(
            hasDescription ? description : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class ErrorStrip extends StatelessWidget {
  const ErrorStrip({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xff7f1d1d),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: context.l10n.dismiss,
          ),
        ],
      ),
    );
  }
}

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TemperatureCurveChart(series: history.series, points: points),
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
    final busy = recorder.status == RecorderStatus.finalizing;
    final canUseFrame = frame != null && !busy;
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
                  child: FilledButton.icon(
                    onPressed: canUseFrame
                        ? () => controller.captureSnapshot()
                        : null,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Capture'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: recorder.isRecording
                      ? FilledButton.icon(
                          onPressed: busy ? null : controller.stopRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        )
                      : FilledButton.icon(
                          onPressed: canUseFrame
                              ? () => controller.startRecording()
                              : null,
                          icon: const Icon(Icons.fiber_manual_record),
                          label: const Text('Record'),
                        ),
                ),
              ],
            ),
            if (recorder.isRecording || busy) ...[
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
                      '${recorder.frameCount} frames  ${_formatDuration(recorder.elapsed)}',
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

class GalleryPane extends ConsumerWidget {
  const GalleryPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final localGallery = ref.watch(localGalleryProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final localEntries = localGallery.asData?.value ?? const <GalleryEntry>[];
    final hasAnyEntries = state.gallery.isNotEmpty || localEntries.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: state.connected && !state.busy
                    ? controller.loadGallery
                    : null,
                icon: const Icon(Icons.sync),
                label: Text(l10n.readDevice),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.gallery.isEmpty
                    ? null
                    : () => confirmClearDevice(context, controller),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l10n.clearDevice),
              ),
              const Spacer(),
              Text(
                '${l10n.deviceFiles(state.gallery.length)}  Local: ${localEntries.length}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
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
            child: !hasAnyEntries && !localGallery.isLoading
                ? EmptyPanel(
                    icon: Icons.photo_library_outlined,
                    title: l10n.noDevicePhotos,
                    subtitle: l10n.readDeviceFiles,
                  )
                : CustomScrollView(
                    slivers: [
                      if (state.gallery.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _GallerySectionHeader(
                            title: 'Device files',
                            count: state.gallery.length,
                          ),
                        ),
                        SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: state.gallery.length,
                          itemBuilder: (context, index) {
                            final photo = state.gallery[index];
                            return GalleryTile(photo: photo);
                          },
                        ),
                      ],
                      if (localGallery.isLoading)
                        const SliverToBoxAdapter(
                          child: LinearProgressIndicator(),
                        ),
                      if (localGallery.hasError)
                        SliverToBoxAdapter(
                          child: Text(
                            localGallery.error.toString(),
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      if (localEntries.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _GallerySectionHeader(
                            title: 'Local recordings',
                            count: localEntries.length,
                          ),
                        ),
                        SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: localEntries.length,
                          itemBuilder: (context, index) {
                            return LocalGalleryTile(entry: localEntries[index]);
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GallerySectionHeader extends StatelessWidget {
  const _GallerySectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class LocalGalleryTile extends StatelessWidget {
  const LocalGalleryTile({super.key, required this.entry});

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = entry.duration;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog.fullscreen(child: LocalUirViewer(entry: entry)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  Chip(
                    label: const Text('Local'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  '${entry.width}x${entry.height}',
                  if (entry.frameCount != null) '${entry.frameCount} frames',
                  if (duration != null) _formatDuration(duration),
                  _formatBytes(entry.sizeBytes),
                ].join('  '),
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
              ? Center(child: Text(snapshot.error.toString()))
              : controller == null
              ? const Center(child: CircularProgressIndicator())
              : _LocalUirPlaybackView(controller: controller),
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
    final points = ref.watch(thermalPointsProvider);
    final pointsController = ref.read(thermalPointsProvider.notifier);
    final series = buildTemperatureSeries(
      frames: controller.document.frames,
      points: points,
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final frame = controller.currentFrame;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final viewer = frame == null
                ? const EmptyPanel(
                    icon: Icons.broken_image_outlined,
                    title: 'No frames',
                    subtitle: 'This UIR file does not contain readable frames.',
                  )
                : ThermalRasterView.frame(
                    frame,
                    settings: renderSettings,
                    scale: wide ? 10 : 8,
                    points: points,
                    onPointAdded: pointsController.add,
                    onPointMoved: pointsController.move,
                    onPointRemoved: pointsController.remove,
                  );
            final controls = _PlaybackControls(
              controller: controller,
              series: series,
              points: points,
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
                      SizedBox(height: 190, child: controls),
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
  });

  final UirPlaybackController controller;
  final Map<String, List<TemperatureSample>> series;
  final List<ThermalPoint> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final frameCount = controller.frameCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous frame',
                  onPressed: frameCount > 1 ? controller.stepBackward : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                FilledButton(
                  onPressed: controller.isVideo ? controller.togglePlay : null,
                  child: Icon(
                    controller.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  tooltip: 'Next frame',
                  onPressed: frameCount > 1 ? controller.stepForward : null,
                  icon: const Icon(Icons.skip_next),
                ),
                const Spacer(),
                Text(
                  '${controller.currentIndex + 1}/$frameCount',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            Slider(
              value: controller.currentIndex.toDouble(),
              min: 0,
              max: math.max(0, frameCount - 1).toDouble(),
              divisions: frameCount > 1 ? frameCount - 1 : null,
              onChanged: frameCount > 1
                  ? (value) => controller.seekToFrame(value.round())
                  : null,
            ),
            Text(
              '${_formatDuration(controller.position)} / ${_formatDuration(controller.duration)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0.5, label: Text('0.5x')),
                ButtonSegment(value: 1, label: Text('1x')),
                ButtonSegment(value: 2, label: Text('2x')),
              ],
              selected: {controller.speed},
              onSelectionChanged: (values) {
                controller.setSpeed(values.first);
              },
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                child: TemperatureCurveChart(
                  series: series,
                  points: points,
                  cursor: controller.position,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GalleryTile extends ConsumerWidget {
  const GalleryTile({super.key, required this.photo});

  final DevicePhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderSettings = ref.watch(
      thermalControllerProvider.select((state) => state.renderSettings),
    );
    final canDelete = ref.watch(
      thermalControllerProvider.select(
        (state) => state.connected && !state.busy,
      ),
    );
    final controller = ref.read(thermalControllerProvider.notifier);
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog.fullscreen(
            child: Consumer(
              builder: (context, ref, _) {
                final liveState = ref.watch(thermalControllerProvider);
                final liveController = ref.read(
                  thermalControllerProvider.notifier,
                );
                return Scaffold(
                  appBar: AppBar(title: Text(photo.filename)),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final viewer = ThermalRasterView(
                        temperatures: photo.temperatures,
                        width: photo.width,
                        height: photo.height,
                        tMin: photo.tMin,
                        tMax: photo.tMax,
                        settings: liveState.renderSettings,
                        scale: wide ? 10 : 8,
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
                  ),
                );
              },
            ),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ThermalRasterView(
                temperatures: photo.temperatures,
                width: photo.width,
                height: photo.height,
                tMin: photo.tMin,
                tMax: photo.tMax,
                settings: renderSettings,
                scale: 4,
                showOverlay: false,
              ),
            ),
            ListTile(
              dense: true,
              title: Text(photo.filename, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                l10n.photoStats(
                  photo.width,
                  photo.height,
                  photo.tMax.toStringAsFixed(1),
                  photo.tMin.toStringAsFixed(1),
                ),
              ),
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: canDelete
                    ? () => controller.deletePhoto(photo.filename)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            SwitchListTile(
              value: settings.upscaleEnabled,
              title: Text(l10n.bilinear),
              onChanged: (value) => controller.updateRenderSettings(
                settings.copyWith(upscaleEnabled: value),
              ),
            ),
            SwitchListTile(
              value: settings.hflip,
              title: Text(l10n.horizontalFlip),
              onChanged: (value) => controller.updateRenderSettings(
                settings.copyWith(hflip: value),
              ),
            ),
            SwitchListTile(
              value: settings.vflip,
              title: Text(l10n.verticalFlip),
              onChanged: (value) => controller.updateRenderSettings(
                settings.copyWith(vflip: value),
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: RotationLabel('0')),
                ButtonSegment(value: 90, label: RotationLabel('90')),
                ButtonSegment(value: 180, label: RotationLabel('180')),
                ButtonSegment(value: 270, label: RotationLabel('270')),
              ],
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              selected: {settings.rotation},
              onSelectionChanged: (value) => controller.updateRenderSettings(
                settings.copyWith(rotation: value.first),
              ),
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

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static const bitrates = [115200, 460800, 921600, 1000000, 2000000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.l10n.deviceSettings),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: state.baudRate,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.speed),
                labelText: context.l10n.bitrate,
              ),
              items: [
                for (final rate in bitrates)
                  DropdownMenuItem(value: rate, child: Text('$rate')),
              ],
              onChanged: state.connected
                  ? null
                  : (value) {
                      if (value != null) controller.setBaudRate(value);
                    },
            ),
            const SizedBox(height: 10),
            Text(
              state.connected
                  ? context.l10n.disconnectBeforeBitrate
                  : context.l10n.defaultFirmwareBitrate,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
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
  }
}

class AppSettingsPane extends ConsumerWidget {
  const AppSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final packageInfo = ref.watch(packageInfoProvider).asData?.value;
    final l10n = context.l10n;
    final version = packageInfo?.version ?? '';
    final displayVersion = appVersionLabel(version);
    final versionText = displayVersion.isEmpty
        ? null
        : l10n.version(displayVersion);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.appSettings,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<AppLanguage>(
                  initialValue: settings.language,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.language),
                    labelText: l10n.language,
                  ),
                  items: [
                    for (final language in AppLanguage.values)
                      DropdownMenuItem(
                        value: language,
                        child: Text(language.label(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setLanguage(value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppThemePreference>(
                  initialValue: settings.theme,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.contrast),
                    labelText: l10n.theme,
                  ),
                  items: [
                    for (final theme in AppThemePreference.values)
                      DropdownMenuItem(
                        value: theme,
                        child: Text(theme.label(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setTheme(value);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.analytics_outlined),
                  title: Text(l10n.appTracking),
                  subtitle: Text(l10n.appTrackingDescription),
                  value: settings.appTrackingEnabled,
                  onChanged: controller.setAppTrackingEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.system_update_alt),
                  title: Text(l10n.autoUpdateCheck),
                  subtitle: Text(l10n.autoUpdateCheckDescription),
                  value: settings.autoUpdateCheckEnabled,
                  onChanged: controller.setAutoUpdateCheckEnabled,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.about),
                subtitle: Text(
                  versionText == null
                      ? l10n.aboutAppDescription
                      : '${l10n.aboutAppDescription}\n$versionText',
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: appDisplayName(l10n.appTitle),
                  applicationVersion: displayVersion,
                  applicationIcon: const Icon(
                    Icons.thermostat,
                    color: Color(0xfff97316),
                    size: 42,
                  ),
                  children: [Text(l10n.aboutAppDescription)],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l10n.githubRepository),
                subtitle: const Text(umekoIrRepositoryUrl),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse(umekoIrRepositoryUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.licenses),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: appDisplayName(l10n.appTitle),
                  applicationVersion: displayVersion,
                  applicationIcon: const Icon(
                    Icons.thermostat,
                    color: Color(0xfff97316),
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DebugPane extends ConsumerWidget {
  const DebugPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.terminal),
                  const SizedBox(width: 8),
                  Text(
                    l10n.serialDebug,
                    style: const TextStyle(
                      fontFamily: _monoFontFamily,
                      fontFamilyFallback: _monoFontFallback,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: state.debugLines.isEmpty
                        ? null
                        : controller.clearDebug,
                    icon: const Icon(Icons.clear_all),
                    label: Text(
                      l10n.clear,
                      style: const TextStyle(
                        fontFamily: _monoFontFamily,
                        fontFamilyFallback: _monoFontFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: state.debugLines.length,
                itemBuilder: (context, index) {
                  final line =
                      state.debugLines[state.debugLines.length - 1 - index];
                  return SelectableText(
                    line,
                    style: const TextStyle(
                      fontFamily: _monoFontFamily,
                      fontFamilyFallback: _monoFontFallback,
                      fontSize: 12,
                    ).copyWith(color: colorScheme.onSurface),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> confirmClearDevice(
  BuildContext context,
  ThermalController controller,
) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.clearDevicePhotosTitle),
      content: Text(l10n.clearDevicePhotosMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.clear),
        ),
      ],
    ),
  );
  if (ok == true) {
    await controller.clearPhotos();
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          Text(
            value,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = active
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = active
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(color: foreground, fontSize: 12),
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension ThermalColorMapLabel on ThermalColorMap {
  String label(AppLocalizations l10n) {
    return switch (this) {
      ThermalColorMap.ironbow => l10n.colorMapIronbow,
      ThermalColorMap.rainbow => l10n.colorMapRainbow,
      ThermalColorMap.grayscale => l10n.colorMapGrayscale,
      ThermalColorMap.blackHot => l10n.colorMapBlackHot,
      ThermalColorMap.hot => l10n.colorMapHot,
      ThermalColorMap.inferno => l10n.colorMapInferno,
      ThermalColorMap.plasma => l10n.colorMapPlasma,
      ThermalColorMap.jet => l10n.colorMapJet,
      ThermalColorMap.cool => l10n.colorMapCool,
    };
  }
}

extension ThermalFilterLabel on ThermalFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      ThermalFilter.none => l10n.filterNone,
      ThermalFilter.gaussian => l10n.filterGaussian,
      ThermalFilter.sharpen => l10n.filterSharpen,
      ThermalFilter.sobel => l10n.filterSobel,
      ThermalFilter.emboss => l10n.filterEmboss,
    };
  }
}

extension AppLanguageLabel on AppLanguage {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AppLanguage.system => l10n.systemLanguage,
      AppLanguage.english => l10n.english,
      AppLanguage.chinese => l10n.chinese,
      AppLanguage.japanese => l10n.japanese,
    };
  }

  IconData get icon {
    return switch (this) {
      AppLanguage.system => Icons.language,
      AppLanguage.english => Icons.text_fields,
      AppLanguage.chinese => Icons.translate,
      AppLanguage.japanese => Icons.translate,
    };
  }
}

extension AppThemePreferenceLabel on AppThemePreference {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AppThemePreference.system => l10n.systemTheme,
      AppThemePreference.light => l10n.lightTheme,
      AppThemePreference.dark => l10n.darkTheme,
    };
  }
}
