import 'package:sentry_flutter/sentry_flutter.dart';

const sentryProjectId = '4511344030056448';
const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue:
      'https://d3a6b8f1b367f22df9d72cb1b06606fa@o4511344024879104.ingest.us.sentry.io/4511344030056448',
);
const _sentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: 'prod',
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

  if (_configured) {
    appRunner?.call();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = _sentryEnvironment;
    options.tracesSampleRate =
        double.tryParse(_sentryTracesSampleRateValue) ?? 0.2;
    options.enableAutoSessionTracking = true;
    options.enableAppLifecycleBreadcrumbs = true;
    options.attachStacktrace = true;
  }, appRunner: appRunner);
  _configured = true;
}
