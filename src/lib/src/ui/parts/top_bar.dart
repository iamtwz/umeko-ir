// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      thermalControllerProvider.select(_TopBarSnapshot.fromState),
    );
    final controller = ref.read(thermalControllerProvider.notifier);
    final compact = MediaQuery.sizeOf(context).width < 980;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: 10,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(state: state, controller: controller),
                  if (_showPortPicker(state)) ...[
                    const SizedBox(height: 10),
                    _PortPicker(state: state, controller: controller),
                  ],
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _HeaderRow(state: state, controller: controller),
                  ),
                  if (_showPortPicker(state)) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 360,
                      child: _PortPicker(state: state, controller: controller),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  bool _showPortPicker(_TopBarSnapshot state) {
    return !kIsWeb || state.ports.any((port) => !port.virtual);
  }
}

class _TopBarSnapshot {
  const _TopBarSnapshot({
    required this.ports,
    required this.selectedPort,
    required this.connected,
    required this.streaming,
    required this.busy,
  });

  factory _TopBarSnapshot.fromState(ThermalState state) {
    return _TopBarSnapshot(
      ports: state.ports,
      selectedPort: state.selectedPort,
      connected: state.connected,
      streaming: state.streaming,
      busy: state.busy,
    );
  }

  final List<SerialPortDescriptor> ports;
  final SerialPortDescriptor? selectedPort;
  final bool connected;
  final bool streaming;
  final bool busy;

  @override
  bool operator ==(Object other) {
    return other is _TopBarSnapshot &&
        other.ports == ports &&
        other.selectedPort == selectedPort &&
        other.connected == connected &&
        other.streaming == streaming &&
        other.busy == busy;
  }

  @override
  int get hashCode {
    return Object.hash(ports, selectedPort, connected, streaming, busy);
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.state, required this.controller});

  final _TopBarSnapshot state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = <Widget>[
          ConnectionStatusDot(
            label: state.connected ? l10n.connected : l10n.disconnected,
            active: state.connected,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.refreshPorts,
            onPressed: state.busy ? null : controller.refreshPorts,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.deviceSettings,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
            icon: const Icon(Icons.tune),
          ),
          FilledButton.icon(
            onPressed: state.busy
                ? null
                : state.connected
                ? controller.disconnect
                : controller.connect,
            icon: Icon(state.connected ? Icons.link_off : Icons.usb),
            label: Text(
              state.connected ? l10n.disconnect : l10n.connect,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ];
        final title = Text(
          l10n.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: controls,
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            ...controls,
          ],
        );
      },
    );
  }
}

class _PortPicker extends StatelessWidget {
  const _PortPicker({required this.state, required this.controller});

  final _TopBarSnapshot state;
  final ThermalController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visiblePorts = state.ports.where((port) => !port.virtual).toList();
    final selectedPort =
        visiblePorts.any((port) => port.id == state.selectedPort?.id)
        ? state.selectedPort
        : null;
    return PopupMenuButton<SerialPortDescriptor>(
      enabled:
          visiblePorts.isNotEmpty &&
          !(state.connected || state.busy || state.streaming),
      onSelected: controller.selectPort,
      itemBuilder: (context) => [
        for (final port in visiblePorts)
          PopupMenuItem(
            value: port,
            child: PortOption(port: port),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.cable),
          labelText: l10n.serialPort,
        ),
        child: SizedBox(
          height: 36,
          child: Align(
            alignment: selectedPort == null && visiblePorts.isEmpty
                ? Alignment.center
                : Alignment.centerLeft,
            child: selectedPort == null
                ? PortPlaceholder(
                    text: visiblePorts.isEmpty
                        ? l10n.noSerialPorts
                        : l10n.chooseSerialPort,
                    centered: visiblePorts.isEmpty,
                  )
                : PortOption(
                    port: selectedPort,
                    dense: true,
                    reserveDescription: true,
                  ),
          ),
        ),
      ),
    );
  }
}

class PortPlaceholder extends StatelessWidget {
  const PortPlaceholder({super.key, required this.text, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class PortOption extends StatelessWidget {
  const PortOption({
    super.key,
    required this.port,
    this.dense = false,
    this.reserveDescription = false,
  });

  final SerialPortDescriptor port;
  final bool dense;
  final bool reserveDescription;

  @override
  Widget build(BuildContext context) {
    final description = port.description;
    final hasDescription = description != null && description.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          port.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: dense ? 14 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasDescription || reserveDescription)
          Text(
            hasDescription ? description : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class ErrorStrip extends StatelessWidget {
  const ErrorStrip({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xff7f1d1d);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: foreground),
            tooltip: context.l10n.dismiss,
          ),
        ],
      ),
    );
  }
}
