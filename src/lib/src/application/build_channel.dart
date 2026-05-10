enum BuildChannel {
  release,
  dev;

  bool get isDev => this == BuildChannel.dev;

  String get telemetryEnvironment {
    return switch (this) {
      BuildChannel.release => 'prod',
      BuildChannel.dev => 'dev',
    };
  }
}

const _buildChannelName = String.fromEnvironment(
  'UMEKO_BUILD_CHANNEL',
  defaultValue: 'release',
);

const buildChannel = _buildChannelName == 'dev'
    ? BuildChannel.dev
    : BuildChannel.release;

BuildChannel buildChannelFromName(String value) {
  return value.toLowerCase() == 'dev' ? BuildChannel.dev : BuildChannel.release;
}

String appDisplayName(
  String releaseName, {
  BuildChannel channel = buildChannel,
}) {
  return channel.isDev ? '$releaseName Dev' : releaseName;
}

String appVersionLabel(String version, {BuildChannel channel = buildChannel}) {
  if (version.isEmpty || !channel.isDev) return version;
  return '$version (Dev)';
}
