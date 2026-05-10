import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'build_channel.dart';
import 'tracking_identity.dart';

const sentryProjectId = '4511344030056448';
const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue:
      'https://d3a6b8f1b367f22df9d72cb1b06606fa@o4511344024879104.ingest.us.sentry.io/4511344030056448',
);
const _sentryEnvironmentOverride = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: '',
);
const _sentryTracesSampleRateValue = String.fromEnvironment(
  'SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '0.2',
);

bool _configured = false;

bool get isSentryConfigured => _configured;
bool get hasSentryDsn => _sentryDsn.isNotEmpty;

Future<void> configureSentry({
  required bool enabled,
  AppRunner? appRunner,
}) async {
  if (!enabled || _sentryDsn.isEmpty) {
    if (_configured) {
      await Sentry.close();
      _configured = false;
    }
    appRunner?.call();
    return;
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final anonymousUserId = await loadOrCreateAnonymousUserId();
  final release =
      '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';

  if (_configured) {
    await _setSentryUser(anonymousUserId);
    appRunner?.call();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = _sentryEnvironmentOverride.isEmpty
        ? buildChannel.telemetryEnvironment
        : _sentryEnvironmentOverride;
    options.release = release;
    options.dist = packageInfo.buildNumber;
    options.tracesSampleRate =
        double.tryParse(_sentryTracesSampleRateValue) ?? 0.2;
    options.enableAutoSessionTracking = true;
    options.enableAppLifecycleBreadcrumbs = true;
    options.attachStacktrace = true;
  }, appRunner: appRunner);
  await _setSentryUser(anonymousUserId);
  _configured = true;
}

Future<void> _setSentryUser(String anonymousUserId) async {
  await Sentry.configureScope((scope) {
    scope.setUser(SentryUser(id: anonymousUserId));
  });
}
