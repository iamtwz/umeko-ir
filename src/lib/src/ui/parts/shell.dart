// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

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
