// Dual-vision (visible-light + thermal fusion) alignment workbench.
//
// Visible-light frames stay on the device, so the app deliberately presents
// a schematic calibration stage. The user manipulates the thermal projection
// here while observing the real fused output on the device LCD.
part of '../../../main.dart';

const double _dualVisionMinScale = 0.3;
const double _dualVisionMaxScale = 3.0;
const double _dualVisionMinAngle = -math.pi / 4;
const double _dualVisionMaxAngle = math.pi / 4;

enum _AlignmentSyncStatus { idle, syncing, saved, error }

class DualVisionAlignmentPage extends ConsumerStatefulWidget {
  const DualVisionAlignmentPage({super.key});

  @override
  ConsumerState<DualVisionAlignmentPage> createState() =>
      _DualVisionAlignmentPageState();
}

class _DualVisionAlignmentPageState
    extends ConsumerState<DualVisionAlignmentPage> {
  static const _writeDebounce = Duration(milliseconds: 120);
  static const double _cameraWidth = 320;
  static const double _cameraHeight = 240;
  static const double _thermalWidth = 32 * 5;
  static const double _thermalHeight = 24 * 5;

  Timer? _affineDebounce;
  Timer? _alphaDebounce;
  AlignParams? _draft;
  int _draftRevision = 0;
  bool _showAdvanced = false;
  bool _scaleLocked = true;
  bool _vflipPending = false;
  bool _hflipPending = false;
  bool _resetPending = false;
  _AlignmentSyncStatus _syncStatus = _AlignmentSyncStatus.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProbe());
  }

  @override
  void dispose() {
    _affineDebounce?.cancel();
    _alphaDebounce?.cancel();
    super.dispose();
  }

  Future<void> _maybeProbe() async {
    final state = ref.read(thermalControllerProvider);
    if (state.connected &&
        state.dualVision.capability == DualVisionCapability.unknown) {
      await _readFromDevice();
    }
  }

  Future<void> _readFromDevice() async {
    _cancelPendingDraft(resetStatus: false);
    if (mounted) {
      setState(() => _syncStatus = _AlignmentSyncStatus.syncing);
    }
    await ref.read(thermalControllerProvider.notifier).probeDualVision();
    if (!mounted) return;
    final dualVision = ref.read(thermalControllerProvider).dualVision;
    setState(() {
      _syncStatus =
          dualVision.capability == DualVisionCapability.supported &&
              dualVision.lastError == null
          ? _AlignmentSyncStatus.saved
          : dualVision.capability == DualVisionCapability.error
          ? _AlignmentSyncStatus.error
          : _AlignmentSyncStatus.idle;
    });
  }

  AlignParams _effectiveParams(ThermalState state) {
    final confirmed = state.dualVision.params ?? AlignParams.defaults;
    final draft = _draft;
    if (draft == null) return confirmed;
    return AlignParams(
      tx: draft.tx,
      ty: draft.ty,
      sx: draft.sx,
      sy: draft.sy,
      ang: draft.ang,
      fusionAlpha: draft.fusionAlpha,
      vflip: confirmed.vflip,
      hflip: confirmed.hflip,
    );
  }

  void _commitAffine(AlignParams next) {
    final clamped = _clampParams(next);
    final revision = ++_draftRevision;
    setState(() {
      _draft = clamped;
      _syncStatus = _AlignmentSyncStatus.syncing;
    });
    _affineDebounce?.cancel();
    _affineDebounce = Timer(_writeDebounce, () async {
      await ref
          .read(thermalControllerProvider.notifier)
          .writeAlignAffine(clamped);
      _completeWrite(revision);
    });
  }

  void _commitAlpha(int next) {
    final current = _effectiveParams(ref.read(thermalControllerProvider));
    final updated = current.copyWith(fusionAlpha: next.clamp(0, 255));
    final revision = ++_draftRevision;
    setState(() {
      _draft = updated;
      _syncStatus = _AlignmentSyncStatus.syncing;
    });
    _alphaDebounce?.cancel();
    _alphaDebounce = Timer(_writeDebounce, () async {
      await ref
          .read(thermalControllerProvider.notifier)
          .writeFusionAlpha(updated.fusionAlpha);
      _completeWrite(revision);
    });
  }

  AlignParams _clampParams(AlignParams params) {
    return params.copyWith(
      tx: params.tx.clamp(-_cameraWidth / 2, _cameraWidth / 2).toDouble(),
      ty: params.ty.clamp(-_cameraHeight / 2, _cameraHeight / 2).toDouble(),
      sx: params.sx.clamp(_dualVisionMinScale, _dualVisionMaxScale).toDouble(),
      sy: params.sy.clamp(_dualVisionMinScale, _dualVisionMaxScale).toDouble(),
      ang: params.ang
          .clamp(_dualVisionMinAngle, _dualVisionMaxAngle)
          .toDouble(),
    );
  }

  void _completeWrite(int revision) {
    if (!mounted || revision != _draftRevision) return;
    final failed =
        ref.read(thermalControllerProvider).dualVision.lastError != null;
    setState(() {
      _draft = null;
      _syncStatus = failed
          ? _AlignmentSyncStatus.error
          : _AlignmentSyncStatus.saved;
    });
  }

  void _cancelPendingDraft({bool resetStatus = true}) {
    _draftRevision += 1;
    _affineDebounce?.cancel();
    _affineDebounce = null;
    _alphaDebounce?.cancel();
    _alphaDebounce = null;
    if (!mounted) return;
    if (_draft != null || resetStatus) {
      setState(() {
        _draft = null;
        if (resetStatus) _syncStatus = _AlignmentSyncStatus.idle;
      });
    }
  }

  Future<void> _toggleVflip() async {
    if (_vflipPending) return;
    setState(() {
      _vflipPending = true;
      _syncStatus = _AlignmentSyncStatus.syncing;
    });
    await ref.read(thermalControllerProvider.notifier).toggleCameraVflip();
    if (!mounted) return;
    final failed =
        ref.read(thermalControllerProvider).dualVision.lastError != null;
    setState(() {
      _vflipPending = false;
      _syncStatus = failed
          ? _AlignmentSyncStatus.error
          : _AlignmentSyncStatus.saved;
    });
  }

  Future<void> _toggleHflip() async {
    if (_hflipPending) return;
    setState(() {
      _hflipPending = true;
      _syncStatus = _AlignmentSyncStatus.syncing;
    });
    await ref.read(thermalControllerProvider.notifier).toggleCameraHflip();
    if (!mounted) return;
    final failed =
        ref.read(thermalControllerProvider).dualVision.lastError != null;
    setState(() {
      _hflipPending = false;
      _syncStatus = failed
          ? _AlignmentSyncStatus.error
          : _AlignmentSyncStatus.saved;
    });
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded),
        title: Text(l10n.dualVisionResetTitle),
        content: Text(l10n.dualVisionResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.dualVisionResetAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _resetPending = true;
      _syncStatus = _AlignmentSyncStatus.syncing;
    });
    _cancelPendingDraft(resetStatus: false);
    final revision = ++_draftRevision;
    setState(() => _draft = AlignParams.defaults);
    await ref
        .read(thermalControllerProvider.notifier)
        .resetDualVisionToDefaults();
    _completeWrite(revision);
    if (mounted) setState(() => _resetPending = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      thermalControllerProvider.select(
        (state) => (state.connected, state.dualVision.capability),
      ),
      (_, next) {
        final (connected, capability) = next;
        if (!connected) {
          _cancelPendingDraft();
        } else if (capability == DualVisionCapability.unknown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_maybeProbe());
          });
        }
      },
    );
    final l10n = context.l10n;
    final state = ref.watch(thermalControllerProvider);
    final dualVision = state.dualVision;
    final colorScheme = Theme.of(context).colorScheme;
    final displaySyncStatus = dualVision.lastError != null
        ? _AlignmentSyncStatus.error
        : dualVision.isProbing
        ? _AlignmentSyncStatus.syncing
        : _syncStatus == _AlignmentSyncStatus.idle && dualVision.params != null
        ? _AlignmentSyncStatus.saved
        : _syncStatus;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(l10n.dualVisionAlignment),
        actions: [
          if (dualVision.isSupported || dualVision.isProbing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: _SyncStatusIndicator(status: displaySyncStatus),
              ),
            ),
          IconButton(
            tooltip: l10n.dualVisionReadFromDevice,
            icon: const Icon(Icons.download_rounded),
            onPressed: state.connected && !dualVision.isProbing
                ? () => unawaited(_readFromDevice())
                : null,
          ),
          IconButton(
            tooltip: l10n.resetToDefaults,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: dualVision.isSupported && !_resetPending
                ? () => unawaited(_confirmReset())
                : null,
          ),
        ],
      ),
      body: _buildBody(context, state, dualVision, colorScheme, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThermalState state,
    DualVisionState dualVision,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    if (!state.connected) {
      return _centeredMessage(
        icon: Icons.usb_off_rounded,
        title: l10n.deviceNotConnected,
        subtitle: l10n.dualVisionConnectFirst,
        colorScheme: colorScheme,
      );
    }
    if (dualVision.isProbing ||
        dualVision.capability == DualVisionCapability.unknown) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.deviceCapabilityProbing),
          ],
        ),
      );
    }
    if (dualVision.capability == DualVisionCapability.error) {
      return _centeredMessage(
        icon: Icons.error_outline_rounded,
        title: l10n.deviceCapabilityProbeFailed,
        subtitle: dualVision.lastError ?? l10n.dualVisionProbeFailedRetryDetail,
        colorScheme: colorScheme,
        actionLabel: l10n.dualVisionRetry,
        onAction: () => unawaited(_readFromDevice()),
      );
    }
    if (dualVision.capability == DualVisionCapability.unsupported) {
      return _centeredMessage(
        icon: Icons.do_not_disturb_on_outlined,
        title: l10n.deviceCapabilityUnsupported,
        subtitle: l10n.dualVisionUnsupportedDetail,
        colorScheme: colorScheme,
        actionLabel: l10n.dualVisionRetry,
        onAction: () => unawaited(_readFromDevice()),
      );
    }
    return _buildEditor(context, state, dualVision, colorScheme, l10n);
  }

  Widget _buildEditor(
    BuildContext context,
    ThermalState state,
    DualVisionState dualVision,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final params = _effectiveParams(state);
    final canvasSection = _CanvasSection(
      errorMessage: dualVision.lastError,
      params: params,
      cameraWidth: _cameraWidth,
      cameraHeight: _cameraHeight,
      thermalWidth: _thermalWidth,
      thermalHeight: _thermalHeight,
      scaleLocked: _scaleLocked,
      onChanged: _commitAffine,
    );
    final controlsSection = _ControlsSection(
      params: params,
      cameraWidth: _cameraWidth,
      cameraHeight: _cameraHeight,
      showAdvanced: _showAdvanced,
      scaleLocked: _scaleLocked,
      onAdvancedToggled: (value) => setState(() => _showAdvanced = value),
      onScaleLockChanged: (value) => setState(() => _scaleLocked = value),
      onAlphaChanged: _commitAlpha,
      onAffineChanged: _commitAffine,
      onToggleVflip: _vflipPending ? null : () => unawaited(_toggleVflip()),
      onToggleHflip: _hflipPending ? null : () => unawaited(_toggleHflip()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: canvasSection),
                ),
              ),
              VerticalDivider(
                width: 24,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
              SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: controlsSection,
                ),
              ),
            ],
          );
        }

        final canvasHeight = math.min(
          (constraints.maxWidth - 24) * _cameraHeight / _cameraWidth,
          constraints.maxHeight * 0.55,
        );
        final sheetTop = 12 + canvasHeight + 12;
        final initialSheetSize = (1 - sheetTop / constraints.maxHeight)
            .clamp(0.42, 0.72)
            .toDouble();

        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              height: canvasHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: canvasSection,
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: initialSheetSize,
              minChildSize: 0.24,
              maxChildSize: 0.9,
              snap: true,
              snapSizes: [initialSheetSize, 0.9],
              builder: (context, scrollController) {
                return Material(
                  key: const ValueKey('dual-vision-control-sheet'),
                  elevation: 14,
                  color: colorScheme.surfaceContainerLow,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                        child: Row(
                          children: [
                            Text(
                              l10n.dualVisionAdjustments,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.swipe_up_alt_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                          child: controlsSection,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _centeredMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    icon,
                    size: 36,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusIndicator extends StatelessWidget {
  const _SyncStatusIndicator({required this.status});

  final _AlignmentSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 560;
    final (icon, label, color) = switch (status) {
      _AlignmentSyncStatus.idle => (
        Icons.cloud_outlined,
        l10n.dualVisionReady,
        colorScheme.onSurfaceVariant,
      ),
      _AlignmentSyncStatus.syncing => (
        Icons.sync_rounded,
        l10n.dualVisionSyncing,
        colorScheme.primary,
      ),
      _AlignmentSyncStatus.saved => (
        Icons.cloud_done_rounded,
        l10n.dualVisionSaved,
        colorScheme.primary,
      ),
      _AlignmentSyncStatus.error => (
        Icons.cloud_off_rounded,
        l10n.dualVisionSyncFailed,
        colorScheme.error,
      ),
    };

    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == _AlignmentSyncStatus.syncing)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 16, color: color),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasSection extends StatelessWidget {
  const _CanvasSection({
    required this.errorMessage,
    required this.params,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.thermalWidth,
    required this.thermalHeight,
    required this.scaleLocked,
    required this.onChanged,
  });

  final String? errorMessage;
  final AlignParams params;
  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final bool scaleLocked;
  final ValueChanged<AlignParams> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _AlignmentCanvas(
          cameraWidth: cameraWidth,
          cameraHeight: cameraHeight,
          thermalWidth: thermalWidth,
          thermalHeight: thermalHeight,
          params: params,
          scaleLocked: scaleLocked,
          onChanged: onChanged,
        ),
        if (errorMessage != null)
          Positioned(
            top: 58,
            left: 12,
            right: 12,
            child: _ErrorBanner(message: errorMessage!),
          ),
      ],
    );
  }
}
