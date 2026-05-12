// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

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
