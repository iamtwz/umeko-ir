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
import 'src/application/user_error.dart';
import 'src/ui/temperature_curve_chart.dart';
import 'src/ui/thermal_raster_view.dart';

// Part files: see lib/src/ui/parts/ - each file declares `part of`
// this library so widget classes stay in one logical library without
// promoting every underscore-prefixed member to public.
part 'src/ui/parts/formatters.dart';
part 'src/ui/parts/shell.dart';
part 'src/ui/parts/top_bar.dart';
part 'src/ui/parts/live.dart';
part 'src/ui/parts/gallery.dart';
part 'src/ui/parts/export_dialogs.dart';
part 'src/ui/parts/playback.dart';
part 'src/ui/parts/device_gallery.dart';
part 'src/ui/parts/controls.dart';
part 'src/ui/parts/settings.dart';
part 'src/ui/parts/debug.dart';
part 'src/ui/parts/common_widgets.dart';
part 'src/ui/parts/label_extensions.dart';

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

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
