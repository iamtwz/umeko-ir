import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'tracking_identity.dart';

const postHogProjectToken = String.fromEnvironment(
  'POSTHOG_PROJECT_TOKEN',
  defaultValue: 'phc_zX9PHNb6C5Yne9L676ApQsKjiWFk5PA8UdMUfDwpT8Ve',
);
const postHogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);

bool _configured = false;
bool _appOpenCaptured = false;

bool get isPostHogConfigured => _configured;
bool get hasPostHogProjectToken => postHogProjectToken.isNotEmpty;

Future<void> configurePostHog({required bool enabled}) async {
  if (postHogProjectToken.isEmpty) return;

  if (!enabled) {
    if (_configured) {
      await Posthog().disable();
    }
    return;
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final anonymousUserId = await loadOrCreateAnonymousUserId();
  final release =
      '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';

  if (!_configured) {
    final config = PostHogConfig(postHogProjectToken)
      ..host = postHogHost
      ..captureApplicationLifecycleEvents = true
      ..debug = false
      ..optOut = false
      ..personProfiles = PostHogPersonProfiles.identifiedOnly
      ..sessionReplay = false;
    await Posthog().setup(config);
    _configured = true;
  } else {
    await Posthog().enable();
  }

  await Posthog().identify(
    userId: anonymousUserId,
    userProperties: {
      'app_name': packageInfo.appName,
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      'package_name': packageInfo.packageName,
      'release': release,
    },
    userPropertiesSetOnce: {'first_seen_release': release},
  );
  await Posthog().register('app_name', packageInfo.appName);
  await Posthog().register('app_version', packageInfo.version);
  await Posthog().register('build_number', packageInfo.buildNumber);
  await Posthog().register('package_name', packageInfo.packageName);
  await Posthog().register('release', release);

  if (!_appOpenCaptured) {
    _appOpenCaptured = true;
    await Posthog().capture(eventName: 'app_opened');
  }
}
