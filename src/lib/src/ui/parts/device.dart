// Device tab — container that lists per-device capabilities (calibration,
// alignment, debug). Each card opens a dedicated sub-page via Navigator.
// Cards grey out when the connected device does not advertise the capability
// (or when nothing is connected).
part of '../../../main.dart';

class DevicePane extends ConsumerWidget {
  const DevicePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    final connected = state.connected;
    final dualVision = state.dualVision;

    final dualVisionAvailable =
        connected &&
        (dualVision.capability == DualVisionCapability.supported ||
            dualVision.capability == DualVisionCapability.unknown ||
            dualVision.capability == DualVisionCapability.probing ||
            dualVision.capability == DualVisionCapability.error);
    final dualVisionSubtitle = !connected
        ? l10n.deviceNotConnected
        : switch (dualVision.capability) {
            DualVisionCapability.unknown => l10n.deviceCapabilityProbeOnOpen,
            DualVisionCapability.probing => l10n.deviceCapabilityProbing,
            DualVisionCapability.supported => l10n.dualVisionAlignmentSubtitle,
            DualVisionCapability.unsupported =>
              l10n.deviceCapabilityUnsupported,
            DualVisionCapability.error => l10n.deviceCapabilityProbeFailed,
          };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            l10n.deviceCapabilitiesIntro,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        _CapabilityCard(
          icon: Icons.center_focus_strong,
          title: l10n.dualVisionAlignment,
          subtitle: dualVisionSubtitle,
          enabled: dualVisionAvailable,
          trailing: switch (dualVision.capability) {
            DualVisionCapability.unsupported => Icon(
              Icons.do_not_disturb_on_outlined,
              color: colorScheme.outline,
            ),
            DualVisionCapability.error => Icon(
              Icons.error_outline,
              color: colorScheme.error,
            ),
            _ => const Icon(Icons.chevron_right),
          },
          onTap: connected
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DualVisionAlignmentPage(),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        _CapabilityCard(
          icon: Icons.terminal,
          title: l10n.serialDebug,
          subtitle: l10n.serialDebugSubtitle,
          enabled: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SerialDebugPage())),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.4);
    final subtitleColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Card(
      child: InkWell(
        // Unsupported capabilities stay visually muted, but remain tappable
        // while connected so users can view details and retry a transient
        // probe timeout.
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
