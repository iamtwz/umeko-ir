// Dual-vision (visible-light + thermal fusion) alignment full-screen page.
//
// Interaction model
// -----------------
// The visible-light camera frames live entirely on the device — they are
// fused with the thermal sensor in firmware and never reach the host. We
// therefore cannot show the real fusion in the app. Instead we present a
// **schematic 2D canvas**:
//
//   - A rectangular **camera FOV** placeholder (gray + grid + crosshair) is
//     the fixed background. 1 stage pixel == 1 firmware `tx`/`ty` unit, so
//     drag deltas map directly to firmware affine coordinates.
//   - A draggable **thermal overlay** sits on top, representing where the
//     thermal sensor's output will land inside the camera frame after the
//     affine transform. The user manipulates this overlay; the device
//     applies the same transform and renders the real fusion on its own LCD.
//
// Gestures:
//   - drag interior        → translate (tx, ty)
//   - drag a corner handle → scale (sx, sy)
//   - drag the rotate stub → rotation (ang) around overlay center
//
// Each gesture batch debounces a `set_align` write; alpha and flips push
// independently via `set_alpha` / `toggle_*`. A collapsible "fine adjust"
// panel exposes the underlying sliders for precise tweaking. The user
// observes the actual fused image on the device's LCD while dragging.
part of '../../../main.dart';

const double _dualVisionMinScale = 0.3;
const double _dualVisionMaxScale = 3.0;
const double _dualVisionMinAngle = -math.pi / 4;
const double _dualVisionMaxAngle = math.pi / 4;

class DualVisionAlignmentPage extends ConsumerStatefulWidget {
  const DualVisionAlignmentPage({super.key});

  @override
  ConsumerState<DualVisionAlignmentPage> createState() =>
      _DualVisionAlignmentPageState();
}

class _DualVisionAlignmentPageState
    extends ConsumerState<DualVisionAlignmentPage> {
  static const _writeDebounce = Duration(milliseconds: 120);

  // Camera FOV nominal dimensions in firmware pixels.
  static const double _cameraWidth = 320;
  static const double _cameraHeight = 240;

  // Thermal sensor nominal dimensions in firmware pixels at sx=sy=1.0.
  // The firmware projects 32×24 (MLX90640) onto the camera plane; we render
  // it at the same nominal pixel-count so a "1.0" scale matches what the
  // device draws when align is identity.
  static const double _thermalWidth = 32 * 5; // 160
  static const double _thermalHeight = 24 * 5; // 120

  Timer? _affineDebounce;
  Timer? _alphaDebounce;
  AlignParams? _draft;
  int _draftRevision = 0;
  bool _showAdvanced = false;
  bool _vflipPending = false;
  bool _hflipPending = false;
  bool _resetPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeProbe();
    });
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
      _cancelPendingDraft();
      await ref.read(thermalControllerProvider.notifier).probeDualVision();
    }
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
    setState(() => _draft = clamped);
    _affineDebounce?.cancel();
    _affineDebounce = Timer(_writeDebounce, () async {
      await ref
          .read(thermalControllerProvider.notifier)
          .writeAlignAffine(clamped);
      _clearDraftIfCurrent(revision);
    });
  }

  void _commitAlpha(int next) {
    final current = _effectiveParams(ref.read(thermalControllerProvider));
    final updated = current.copyWith(fusionAlpha: next.clamp(0, 255));
    final revision = ++_draftRevision;
    setState(() => _draft = updated);
    _alphaDebounce?.cancel();
    _alphaDebounce = Timer(_writeDebounce, () async {
      await ref
          .read(thermalControllerProvider.notifier)
          .writeFusionAlpha(updated.fusionAlpha);
      _clearDraftIfCurrent(revision);
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

  void _clearDraftIfCurrent(int revision) {
    if (!mounted || revision != _draftRevision) return;
    setState(() => _draft = null);
  }

  void _cancelPendingDraft() {
    _draftRevision += 1;
    _affineDebounce?.cancel();
    _affineDebounce = null;
    _alphaDebounce?.cancel();
    _alphaDebounce = null;
    if (mounted && _draft != null) setState(() => _draft = null);
  }

  Future<void> _toggleVflip() async {
    if (_vflipPending) return;
    setState(() => _vflipPending = true);
    await ref.read(thermalControllerProvider.notifier).toggleCameraVflip();
    if (mounted) setState(() => _vflipPending = false);
  }

  Future<void> _toggleHflip() async {
    if (_hflipPending) return;
    setState(() => _hflipPending = true);
    await ref.read(thermalControllerProvider.notifier).toggleCameraHflip();
    if (mounted) setState(() => _hflipPending = false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dualVisionAlignment),
        actions: [
          IconButton(
            tooltip: l10n.dualVisionReadFromDevice,
            icon: const Icon(Icons.download),
            onPressed: state.connected && !dualVision.isProbing
                ? () {
                    _cancelPendingDraft();
                    unawaited(
                      ref
                          .read(thermalControllerProvider.notifier)
                          .probeDualVision(),
                    );
                  }
                : null,
          ),
          IconButton(
            tooltip: l10n.resetToDefaults,
            icon: const Icon(Icons.restart_alt),
            onPressed: dualVision.isSupported && !_resetPending
                ? () async {
                    setState(() => _resetPending = true);
                    _cancelPendingDraft();
                    final revision = ++_draftRevision;
                    setState(() => _draft = AlignParams.defaults);
                    await ref
                        .read(thermalControllerProvider.notifier)
                        .resetDualVisionToDefaults();
                    _clearDraftIfCurrent(revision);
                    if (mounted) setState(() => _resetPending = false);
                  }
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
        icon: Icons.usb_off,
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
        icon: Icons.error_outline,
        title: l10n.deviceCapabilityProbeFailed,
        subtitle: dualVision.lastError ?? l10n.dualVisionProbeFailedRetryDetail,
        colorScheme: colorScheme,
      );
    }
    if (dualVision.capability == DualVisionCapability.unsupported) {
      return _centeredMessage(
        icon: Icons.do_not_disturb_on_outlined,
        title: l10n.deviceCapabilityUnsupported,
        subtitle: l10n.dualVisionUnsupportedDetail,
        colorScheme: colorScheme,
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
      hint: l10n.dualVisionHint,
      errorMessage: dualVision.lastError,
      params: params,
      cameraWidth: _cameraWidth,
      cameraHeight: _cameraHeight,
      thermalWidth: _thermalWidth,
      thermalHeight: _thermalHeight,
      onChanged: _commitAffine,
    );

    final controlsSection = _ControlsSection(
      params: params,
      cameraWidth: _cameraWidth,
      cameraHeight: _cameraHeight,
      showAdvanced: _showAdvanced,
      onAdvancedToggled: (v) => setState(() => _showAdvanced = v),
      onAlphaChanged: _commitAlpha,
      onAffineChanged: _commitAffine,
      onToggleVflip: _vflipPending ? null : () => unawaited(_toggleVflip()),
      onToggleHflip: _hflipPending ? null : () => unawaited(_toggleHflip()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide split: canvas on left (non-scrolling), controls scroll on right.
        // Threshold is independent of the shell's wide threshold so this page
        // can go side-by-side even inside a narrowed window.
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: canvasSection,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: controlsSection,
                ),
              ),
            ],
          );
        }

        // Narrow stack: canvas pinned at top sized to fit the available
        // vertical budget without scrolling; controls scroll below.
        // Reserve at most ~48% of the available height for the canvas so the
        // controls keep a meaningful viewport on phones.
        final canvasMaxHeight = math.min(
          constraints.maxHeight * 0.48,
          (constraints.maxWidth - 32) * _cameraHeight / _cameraWidth + 120,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: canvasMaxHeight),
                child: canvasSection,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: controlsSection,
              ),
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
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================== Layout-aware sections ==========================

/// Hint + canvas + param readout. Designed to be sized to fit its parent's
/// constraints without internal scrolling — the canvas's AspectRatio shrinks
/// to whatever space is left after the hint and readout chips.
class _CanvasSection extends StatelessWidget {
  const _CanvasSection({
    required this.hint,
    required this.errorMessage,
    required this.params,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.thermalWidth,
    required this.thermalHeight,
    required this.onChanged,
  });

  final String hint;
  final String? errorMessage;
  final AlignParams params;
  final double cameraWidth;
  final double cameraHeight;
  final double thermalWidth;
  final double thermalHeight;
  final ValueChanged<AlignParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: 12),
        // The canvas fills the remaining height. Centred so the AspectRatio
        // does not over-stretch in either dimension.
        Expanded(
          child: Center(
            child: _AlignmentCanvas(
              cameraWidth: cameraWidth,
              cameraHeight: cameraHeight,
              thermalWidth: thermalWidth,
              thermalHeight: thermalHeight,
              params: params,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ParamReadout(params: params),
      ],
    );
  }
}
