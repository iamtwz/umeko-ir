// GENERATED: split out of debug.dart during Debug → Device refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

/// Full-screen page showing raw serial TX/RX hex log.
///
/// Reachable from the Device tab → Serial Debug capability card.
class SerialDebugPage extends ConsumerWidget {
  const SerialDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thermalControllerProvider);
    final controller = ref.read(thermalControllerProvider.notifier);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serialDebug),
        actions: [
          IconButton(
            tooltip: l10n.clear,
            onPressed: state.debugLines.isEmpty ? null : controller.clearDebug,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: state.debugLines.isEmpty
              ? Center(
                  child: Text(
                    l10n.serialDebugEmpty,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
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
      ),
    );
  }
}
