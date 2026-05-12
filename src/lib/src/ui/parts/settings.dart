// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

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
