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
import 'src/core/thermal_frame.dart';
import 'src/core/thermal_rendering.dart';
import 'src/core/temperature_unit.dart';
import 'src/export/thermal_export.dart';
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

String _devicePhotoInfo(
  BuildContext context,
  DevicePhoto photo,
  TemperatureUnit unit,
) {
  final l10n = context.l10n;
  return [
    '${photo.width}x${photo.height}',
    l10n.photoKind,
    _temperatureRange(photo.tMin, photo.tMax, unit),
  ].join('  ');
}

String _galleryEntryInfo(
  BuildContext context,
  GalleryEntry entry,
  Duration? duration,
  TemperatureUnit unit,
) {
  final l10n = context.l10n;
  return [
    '${entry.width}x${entry.height}',
    entry.kind == GalleryKind.photo
        ? l10n.photoKind
        : l10n.framesMetric(entry.frameCount ?? 0),
    if (entry.kind == GalleryKind.video && duration != null)
      _formatDuration(duration),
    _temperatureRange(entry.tMin, entry.tMax, unit),
  ].join('  ');
}

String _temperatureRange(double min, double max, TemperatureUnit unit) {
  return unit.formatRange(min, max);
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

String _formatDateTime(DateTime value) {
  return value
      .toLocal()
      .toIso8601String()
      .replaceFirst('T', ' ')
      .split('.')
      .first;
}

String _devicePhotoFormatLabel(DevicePhotoFormat format) {
  return switch (format) {
    DevicePhotoFormat.uint16_32x32 => 'UInt16 32x32',
    DevicePhotoFormat.float32_32x24 => 'Float32 32x24',
    DevicePhotoFormat.float32_16x12 => 'Float32 16x12',
  };
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
          ConnectionStatusDot(
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
        localGallery.error.toString(),
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
    final exporter = ThermalExporter(
      repository: ref.read(uirRepositoryProvider),
    );
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

enum _GalleryMenuAction { export, fileInfo }

enum _LocalExportFormat { png, apng, uir }

const _defaultExportScale = 32;
const _exportScaleOptions = [4, 8, 16, 24, 32, 48, 64];

class _LocalExportRequest {
  const _LocalExportRequest({required this.format, this.options});

  final _LocalExportFormat format;
  final _LocalExportOptions? options;
}

class _LocalExportOptions {
  const _LocalExportOptions({
    required this.includeLegend,
    required this.includePoints,
    required this.settings,
    required this.exportScale,
  });

  final bool includeLegend;
  final bool includePoints;
  final RenderSettings settings;
  final int exportScale;
}

Future<_LocalExportRequest?> _showLocalExportDialog(
  BuildContext context,
  RenderSettings initialSettings, {
  required int sourceWidth,
  required int sourceHeight,
  required bool supportsApng,
}) {
  var format = _LocalExportFormat.png;
  var includeLegend = true;
  var includePoints = true;
  var settings = initialSettings;
  var exportScale = _defaultExportScale;
  final l10n = context.l10n;
  final formats = [
    _LocalExportFormat.png,
    if (supportsApng) _LocalExportFormat.apng,
    _LocalExportFormat.uir,
  ];
  return showDialog<_LocalExportRequest>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final needsRenderOptions = format != _LocalExportFormat.uir;
          return AlertDialog(
            title: Text(l10n.export),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<_LocalExportFormat>(
                      initialValue: format,
                      decoration: InputDecoration(labelText: l10n.fileFormat),
                      items: [
                        for (final value in formats)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_localExportFormatLabel(l10n, value)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => format = value);
                      },
                    ),
                    if (needsRenderOptions) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeLegend,
                        title: Text(l10n.includeLegend),
                        onChanged: (value) {
                          setState(
                            () => includeLegend = value ?? includeLegend,
                          );
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includePoints,
                        title: Text(l10n.includeMeasurementPoints),
                        onChanged: (value) {
                          setState(
                            () => includePoints = value ?? includePoints,
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _ExportRenderSettingsFields(
                        settings: settings,
                        sourceWidth: sourceWidth,
                        sourceHeight: sourceHeight,
                        exportScale: exportScale,
                        onScaleChanged: (value) {
                          setState(() => exportScale = value);
                        },
                        onChanged: (value) => setState(() => settings = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _LocalExportRequest(
                    format: format,
                    options: needsRenderOptions
                        ? _LocalExportOptions(
                            includeLegend: includeLegend,
                            includePoints: includePoints,
                            settings: settings,
                            exportScale: exportScale,
                          )
                        : null,
                  ),
                ),
                child: Text(l10n.export),
              ),
            ],
          );
        },
      );
    },
  );
}

String _localExportFormatLabel(
  AppLocalizations l10n,
  _LocalExportFormat format,
) {
  return switch (format) {
    _LocalExportFormat.png => l10n.sharePng,
    _LocalExportFormat.apng => l10n.shareApng,
    _LocalExportFormat.uir => l10n.shareUir,
  };
}

String _exportScaleLabel(
  int scale,
  int sourceWidth,
  int sourceHeight,
  RenderSettings settings,
) {
  final size = displayOrientedSize(
    sourceWidth,
    sourceHeight,
    settings.rotation,
  );
  return '${scale}x (${size.width * scale}x${size.height * scale}px)';
}

Future<_LocalExportOptions?> _showPngExportOptions(
  BuildContext context,
  RenderSettings initialSettings, {
  required int sourceWidth,
  required int sourceHeight,
}) {
  var includeLegend = true;
  var includePoints = true;
  var settings = initialSettings;
  var exportScale = _defaultExportScale;
  final l10n = context.l10n;
  return showDialog<_LocalExportOptions>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.exportOptions),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeLegend,
                      title: Text(l10n.includeLegend),
                      onChanged: (value) {
                        setState(() => includeLegend = value ?? includeLegend);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includePoints,
                      title: Text(l10n.includeMeasurementPoints),
                      onChanged: (value) {
                        setState(() => includePoints = value ?? includePoints);
                      },
                    ),
                    const Divider(height: 24),
                    _ExportRenderSettingsFields(
                      settings: settings,
                      sourceWidth: sourceWidth,
                      sourceHeight: sourceHeight,
                      exportScale: exportScale,
                      onScaleChanged: (value) {
                        setState(() => exportScale = value);
                      },
                      onChanged: (value) => setState(() => settings = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _LocalExportOptions(
                    includeLegend: includeLegend,
                    includePoints: includePoints,
                    settings: settings,
                    exportScale: exportScale,
                  ),
                ),
                child: Text(l10n.sharePng),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ExportRenderSettingsFields extends StatelessWidget {
  const _ExportRenderSettingsFields({
    required this.settings,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.exportScale,
    required this.onScaleChanged,
    required this.onChanged,
  });

  final RenderSettings settings;
  final int sourceWidth;
  final int sourceHeight;
  final int exportScale;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<RenderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<int>(
          initialValue: exportScale,
          decoration: InputDecoration(labelText: l10n.resolution),
          items: [
            for (final value in _exportScaleOptions)
              DropdownMenuItem(
                value: value,
                child: Text(
                  _exportScaleLabel(value, sourceWidth, sourceHeight, settings),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onScaleChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ThermalColorMap>(
          initialValue: settings.colorMap,
          decoration: InputDecoration(labelText: l10n.colorMap),
          items: [
            for (final value in ThermalColorMap.values)
              DropdownMenuItem(value: value, child: Text(value.label(l10n))),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(settings.copyWith(colorMap: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ThermalFilter>(
          initialValue: settings.filter,
          decoration: InputDecoration(labelText: l10n.filter),
          items: [
            for (final value in ThermalFilter.values)
              DropdownMenuItem(value: value, child: Text(value.label(l10n))),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(settings.copyWith(filter: value));
          },
        ),
        const SizedBox(height: 10),
        _CompactSwitchRow(
          value: settings.upscaleEnabled,
          label: l10n.bilinear,
          onChanged: (value) =>
              onChanged(settings.copyWith(upscaleEnabled: value)),
        ),
        _ExportAdvancedRenderSettings(
          settings: settings,
          label: l10n.advancedRenderSettings,
          horizontalFlipLabel: l10n.horizontalFlip,
          verticalFlipLabel: l10n.verticalFlip,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

Future<void> _shareApngWithProgress(
  BuildContext context,
  ThermalExporter exporter,
  GalleryEntry entry,
  _LocalExportOptions options,
  TemperatureUnit temperatureUnit,
) async {
  final l10n = context.l10n;
  final labels = _apngExportLabels(l10n);
  var progress = 0.0;
  var phase = labels.preparing;
  var message = l10n.exportMessageStartingApngExport;
  final logs = <String>['${labels.preparing}: $message'];
  final logScrollController = ScrollController();
  final closeCompleter = Completer<void>();
  StateSetter? updateDialog;
  NavigatorState? dialogNavigator;
  var dialogVisible = false;
  var cancelRequested = false;
  var isCancelling = false;
  var isComplete = false;
  var logsExpanded = false;

  void scrollLogsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!logsExpanded || !logScrollController.hasClients) return;
      logScrollController.animateTo(
        logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void addLog(String line) {
    if (logs.isNotEmpty && logs.last == line) return;
    logs.add(line);
    if (logs.length > 80) logs.removeAt(0);
    scrollLogsToEnd();
  }

  void showProgressDialog() {
    if (dialogVisible || !context.mounted) return;
    dialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogNavigator = Navigator.of(context, rootNavigator: true);
          return StatefulBuilder(
            builder: (context, setState) {
              updateDialog = setState;
              return AlertDialog(
                title: Text(context.l10n.exportingApng),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text('${(progress * 100).clamp(0, 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            logsExpanded = !logsExpanded;
                          });
                          if (logsExpanded) scrollLogsToEnd();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                logsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.exportLog,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (logsExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SingleChildScrollView(
                            controller: logScrollController,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final log in logs)
                                  Text(
                                    log,
                                    style: const TextStyle(
                                      fontFamily: 'Menlo',
                                      fontFamilyFallback: [
                                        'SF Mono',
                                        'Monaco',
                                        'Courier New',
                                        'Courier',
                                      ],
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isCancelling
                        ? null
                        : () {
                            if (isComplete) {
                              if (!closeCompleter.isCompleted) {
                                closeCompleter.complete();
                              }
                              Navigator.of(context, rootNavigator: true).pop();
                              return;
                            }
                            setState(() {
                              cancelRequested = true;
                              isCancelling = true;
                              phase = l10n.exportPhaseCancelling;
                              message = l10n.exportMessageStoppingApngExport;
                              addLog('$phase: $message');
                            });
                          },
                    child: Text(isComplete ? l10n.done : l10n.cancel),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        if (!closeCompleter.isCompleted) closeCompleter.complete();
      }),
    );
  }

  try {
    await exporter.shareApng(
      entry,
      options.settings,
      temperatureUnit: temperatureUnit,
      includePoints: options.includePoints,
      includeLegend: options.includeLegend,
      exportScale: options.exportScale,
      shouldCancel: () => cancelRequested,
      onProgress: (event) {
        showProgressDialog();
        final localizedPhase = _localizeApngProgressText(event.phase, l10n);
        final localizedMessage = _localizeApngProgressText(event.message, l10n);
        updateDialog?.call(() {
          progress = event.value.clamp(0.0, 1.0);
          phase = localizedPhase;
          message = localizedMessage;
          addLog('$localizedPhase: $localizedMessage');
        });
      },
      labels: labels,
    );
    if (dialogVisible) {
      updateDialog?.call(() {
        progress = 1;
        phase = labels.complete;
        message = labels.apngFileSaved;
        isComplete = true;
        isCancelling = false;
        addLog('$phase: $message');
      });
      await closeCompleter.future;
    }
  } on ThermalExportCancelled {
    if (dialogVisible) {
      updateDialog?.call(() {
        phase = l10n.exportPhaseCancelled;
        message = l10n.exportMessageExportCancelled;
        isComplete = true;
        isCancelling = false;
        addLog('$phase: $message');
      });
      await closeCompleter.future;
    }
  } catch (_) {
    if (dialogVisible && dialogNavigator?.canPop() == true) {
      dialogNavigator?.pop();
    }
    rethrow;
  } finally {
    logScrollController.dispose();
  }
}

ThermalApngExportLabels _apngExportLabels(AppLocalizations l10n) {
  return ThermalApngExportLabels(
    preparing: l10n.exportPhasePreparing,
    preparingText: l10n.exportPhasePreparingText,
    renderingFrames: l10n.exportPhaseRenderingFrames,
    encodingApng: l10n.exportPhaseEncodingApng,
    saving: l10n.exportPhaseSaving,
    complete: l10n.exportPhaseComplete,
    readingUirFile: l10n.exportMessageReadingUirFile,
    renderingTextOverlays: _countTemplate(
      l10n.exportMessageRenderingTextOverlays,
    ),
    renderedTextOverlay: _indexTotalTemplate(
      l10n.exportMessageRenderedTextOverlay,
    ),
    renderingFrame: _indexTotalTemplate(l10n.exportMessageRenderingFrame),
    renderedFrame: _indexTotalTemplate(l10n.exportMessageRenderedFrame),
    compressingAnimatedPngFrames:
        l10n.exportMessageCompressingAnimatedPngFrames,
    apngEncodingComplete: l10n.exportMessageApngEncodingComplete,
    writingApngFile: l10n.exportMessageWritingApngFile,
    apngFileSaved: l10n.exportMessageApngFileSaved,
  );
}

String _localizeApngProgressText(String value, AppLocalizations l10n) {
  return switch (value) {
    'Preparing' => l10n.exportPhasePreparing,
    'Preparing text' => l10n.exportPhasePreparingText,
    'Rendering frames' => l10n.exportPhaseRenderingFrames,
    'Encoding APNG' => l10n.exportPhaseEncodingApng,
    'Saving' => l10n.exportPhaseSaving,
    'Complete' => l10n.exportPhaseComplete,
    'Reading UIR file' => l10n.exportMessageReadingUirFile,
    'Compressing animated PNG frames' =>
      l10n.exportMessageCompressingAnimatedPngFrames,
    'APNG encoding complete' => l10n.exportMessageApngEncodingComplete,
    'Writing APNG file' => l10n.exportMessageWritingApngFile,
    'APNG file saved' => l10n.exportMessageApngFileSaved,
    _ => value,
  };
}

String _countTemplate(String Function(Object count) formatter) {
  const countToken = '__COUNT__';
  return formatter(countToken).replaceAll(countToken, '{count}');
}

String _indexTotalTemplate(
  String Function(Object index, Object total) formatter,
) {
  const indexToken = '__INDEX__';
  const totalToken = '__TOTAL__';
  return formatter(
    indexToken,
    totalToken,
  ).replaceAll(indexToken, '{index}').replaceAll(totalToken, '{total}');
}

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
              ? Center(child: Text(snapshot.error.toString()))
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
    final exporter = ThermalExporter(
      repository: ref.read(uirRepositoryProvider),
    );
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    final exporter = ThermalExporter(
      repository: ref.read(uirRepositoryProvider),
    );
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    final exporter = ThermalExporter(
      repository: ref.read(uirRepositoryProvider),
    );
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
                DropdownButtonFormField<TemperatureUnit>(
                  initialValue: settings.temperatureUnit,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.thermostat),
                    labelText: l10n.temperatureUnit,
                  ),
                  items: [
                    for (final unit in TemperatureUnit.values)
                      DropdownMenuItem(
                        value: unit,
                        child: Text(unit.label(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setTemperatureUnit(value);
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

class ConnectionStatusDot extends StatelessWidget {
  const ConnectionStatusDot({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.outline;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: const SizedBox.square(dimension: 12),
            ),
          ),
        ),
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

extension TemperatureUnitLabel on TemperatureUnit {
  String label(AppLocalizations l10n) {
    return switch (this) {
      TemperatureUnit.celsius => l10n.temperatureUnitCelsius,
      TemperatureUnit.fahrenheit => l10n.temperatureUnitFahrenheit,
      TemperatureUnit.kelvin => l10n.temperatureUnitKelvin,
    };
  }
}
