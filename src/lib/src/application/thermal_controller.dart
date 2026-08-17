import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device_gallery.dart';
import '../core/dual_vision.dart';
import '../core/thermal_frame.dart';
import '../core/thermal_parser.dart';
import '../core/thermal_rendering.dart';
import '../serial/serial_adapter.dart';
import '../serial/serial_adapter_factory.dart';

final serialAdapterProvider = Provider<SerialAdapter>((ref) {
  final adapter = createSerialAdapter();
  ref.onDispose(adapter.disconnect);
  return adapter;
});

final thermalControllerProvider =
    NotifierProvider<ThermalController, ThermalState>(ThermalController.new);

class ThermalState {
  const ThermalState({
    this.ports = const [],
    this.selectedPort,
    this.connected = false,
    this.streaming = false,
    this.streamSession = 0,
    this.currentFrame,
    this.gallery = const [],
    this.parserStats = const ParserStats.empty(),
    this.renderSettings = const RenderSettings(),
    this.baudRate = 115200,
    this.debugLines = const [],
    this.galleryLoading = false,
    this.galleryLoaded = 0,
    this.galleryTotal = 0,
    this.busy = false,
    this.error,
    this.dualVision = const DualVisionState(),
  });

  final List<SerialPortDescriptor> ports;
  final SerialPortDescriptor? selectedPort;
  final bool connected;
  final bool streaming;
  final int streamSession;
  final ThermalFrame? currentFrame;
  final List<DevicePhoto> gallery;
  final ParserStats parserStats;
  final RenderSettings renderSettings;
  final int baudRate;
  final List<String> debugLines;
  final bool galleryLoading;
  final int galleryLoaded;
  final int galleryTotal;
  final bool busy;
  final String? error;
  final DualVisionState dualVision;

  ThermalState copyWith({
    List<SerialPortDescriptor>? ports,
    SerialPortDescriptor? selectedPort,
    bool? connected,
    bool? streaming,
    int? streamSession,
    ThermalFrame? currentFrame,
    List<DevicePhoto>? gallery,
    ParserStats? parserStats,
    RenderSettings? renderSettings,
    int? baudRate,
    List<String>? debugLines,
    bool? galleryLoading,
    int? galleryLoaded,
    int? galleryTotal,
    bool? busy,
    String? error,
    DualVisionState? dualVision,
    bool clearSelectedPort = false,
    bool clearError = false,
  }) {
    return ThermalState(
      ports: ports ?? this.ports,
      selectedPort: clearSelectedPort
          ? null
          : selectedPort ?? this.selectedPort,
      connected: connected ?? this.connected,
      streaming: streaming ?? this.streaming,
      streamSession: streamSession ?? this.streamSession,
      currentFrame: currentFrame ?? this.currentFrame,
      gallery: gallery ?? this.gallery,
      parserStats: parserStats ?? this.parserStats,
      renderSettings: renderSettings ?? this.renderSettings,
      baudRate: baudRate ?? this.baudRate,
      debugLines: debugLines ?? this.debugLines,
      galleryLoading: galleryLoading ?? this.galleryLoading,
      galleryLoaded: galleryLoaded ?? this.galleryLoaded,
      galleryTotal: galleryTotal ?? this.galleryTotal,
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
      dualVision: dualVision ?? this.dualVision,
    );
  }
}

class ThermalController extends Notifier<ThermalState> {
  static const _debugCapacity = 500;
  static const _serialIoTimeout = Duration(seconds: 1);

  late final SerialAdapter _serial;
  final ThermalParser _parser = ThermalParser();
  StreamSubscription<Uint8List>? _subscription;
  Completer<Uint8List>? _transactionCompleter;
  final List<int> _transactionBuffer = [];
  final StreamController<ThermalFrame> _frameController =
      StreamController<ThermalFrame>.broadcast();
  Future<void> _transportQueue = Future<void>.value();
  final Queue<String> _debugBuffer = Queue<String>();
  Timer? _debugFlushTimer;
  Timer? _streamHeartbeat;
  bool _streamWriteInFlight = false;
  int _connectionGeneration = 0;

  Stream<ThermalFrame> get frameStream => _frameController.stream;

  @override
  ThermalState build() {
    _serial = ref.watch(serialAdapterProvider);
    _subscription = _serial.input.listen(
      _handleBytes,
      onError: (Object e) {
        state = state.copyWith(error: e.toString());
      },
    );
    ref.onDispose(() {
      _streamHeartbeat?.cancel();
      _debugFlushTimer?.cancel();
      _subscription?.cancel();
      _frameController.close();
      _serial.disconnect();
    });
    Future<void>.microtask(refreshPorts);
    return const ThermalState();
  }

  Future<void> refreshPorts() async {
    try {
      if (state.connected) {
        await _disconnectForRefresh();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      final ports = await _serial.listPorts();
      final port = _resolvePort(ports);
      state = state.copyWith(
        ports: ports,
        selectedPort: port,
        clearSelectedPort: port == null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _disconnectForRefresh() async {
    try {
      await disconnect();
    } catch (_) {
      _parser.reset();
      state = state.copyWith(
        connected: false,
        streaming: false,
        parserStats: _parser.stats,
      );
    }
  }

  void selectPort(SerialPortDescriptor port) {
    state = state.copyWith(selectedPort: port, clearError: true);
  }

  Future<void> connect() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final connected = await _connectWithFreshPort();
      if (!connected) return;
      state = state.copyWith(connected: true, busy: false);
      await startStream();
    } catch (e) {
      if (!_isMissingPortError(e)) {
        state = state.copyWith(busy: false, error: e.toString());
        return;
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        final connected = await _connectWithFreshPort(ignoreSelected: true);
        if (!connected) return;
        state = state.copyWith(connected: true, busy: false);
        await startStream();
      } catch (retryError) {
        state = state.copyWith(busy: false, error: retryError.toString());
      }
    }
  }

  Future<void> disconnect() async {
    _invalidateConnection('Serial connection closed');
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    Object? disconnectError;
    try {
      await _serial.disconnect().timeout(
        _serialIoTimeout,
        onTimeout: () => throw TimeoutException(
          'Serial disconnect timed out after '
          '${_serialIoTimeout.inMilliseconds}ms',
          _serialIoTimeout,
        ),
      );
    } catch (error) {
      disconnectError = error;
    } finally {
      _parser.reset();
      state = state.copyWith(
        connected: false,
        streaming: false,
        busy: false,
        galleryLoading: false,
        parserStats: _parser.stats,
        error: disconnectError?.toString(),
        clearError: disconnectError == null,
        dualVision: const DualVisionState(),
      );
    }
  }

  Future<void> startStream() async {
    if (!state.connected) return;
    final generation = _connectionGeneration;
    _parser.reset();
    try {
      await _writeLine('stream');
    } catch (e) {
      await _handleSerialWriteFailure(e, generation);
      return;
    }
    if (!_isCurrentConnection(generation)) return;
    _streamHeartbeat?.cancel();
    _streamHeartbeat = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_sendStreamHeartbeat());
    });
    state = state.copyWith(
      streaming: true,
      streamSession: state.streamSession + 1,
      parserStats: _parser.stats,
    );
  }

  Future<void> stopStream() async {
    final generation = _connectionGeneration;
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    if (state.connected) {
      try {
        await _writeLine('stop_stream');
      } catch (e) {
        await _handleSerialWriteFailure(e, generation);
        return;
      }
    }
    if (state.connected && !_isCurrentConnection(generation)) return;
    state = state.copyWith(streaming: false);
  }

  Future<void> _sendStreamHeartbeat() async {
    if (_streamWriteInFlight || !state.connected || !state.streaming) return;
    final generation = _connectionGeneration;
    _streamWriteInFlight = true;
    try {
      await _writeLine('stream');
    } catch (e) {
      await _handleSerialWriteFailure(e, generation);
    } finally {
      if (generation == _connectionGeneration) {
        _streamWriteInFlight = false;
      }
    }
  }

  Future<void> _handleSerialWriteFailure(
    Object error,
    int expectedGeneration,
  ) async {
    if (!_isCurrentConnection(expectedGeneration)) return;
    _invalidateConnection('Serial write failed');
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    try {
      await _serial.disconnect().timeout(_serialIoTimeout);
    } catch (_) {
      // A broken serial handle can also fail while being closed.
    }
    _parser.reset();
    state = state.copyWith(
      connected: false,
      streaming: false,
      busy: false,
      galleryLoading: false,
      parserStats: _parser.stats,
      error: error.toString(),
      dualVision: const DualVisionState(),
    );
  }

  Future<void> loadGallery() async {
    if (!state.connected) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (state.streaming) {
        await _restartSerialForCommandMode();
      }
      final listBytes = await _collectCommand(
        'ls',
        const Duration(milliseconds: 8000),
        (data) {
          final text = utf8.decode(data, allowMalformed: true);
          return text.contains('Total:') ||
              text.contains('Directory is empty') ||
              text.contains('Failed to open directory') ||
              text.contains('is not a directory') ||
              text.contains('Failed to mount LittleFS');
        },
        allowPartialOnTimeout: true,
      );
      final files = parseDeviceFileList(
        utf8.decode(listBytes, allowMalformed: true),
      );
      final photos = <DevicePhoto>[];
      state = state.copyWith(
        gallery: const [],
        galleryLoading: true,
        galleryLoaded: 0,
        galleryTotal: files.length,
      );
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final catBytes = await _collectCommand(
          'cat /${file.filename}',
          const Duration(milliseconds: 2500),
          (data) {
            return findPhotoPayloadStart(file, data) != -1;
          },
          allowPartialOnTimeout: true,
        );
        final start = findPhotoPayloadStart(file, catBytes);
        if (start != -1) {
          photos.add(
            parseDevicePhoto(
              file,
              Uint8List.sublistView(catBytes, start, start + file.size),
            ),
          );
        }
        state = state.copyWith(
          gallery: List.unmodifiable(photos),
          galleryLoaded: index + 1,
        );
      }
      state = state.copyWith(
        gallery: List.unmodifiable(photos),
        busy: false,
        galleryLoading: false,
      );
    } catch (e) {
      if (e is _ConnectionChangedException) return;
      state = state.copyWith(
        busy: false,
        galleryLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _restartSerialForCommandMode() async {
    final generation = _connectionGeneration;
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;

    var reachedCommandMode = false;
    try {
      try {
        await _writeLine('stop_stream');
      } catch (e) {
        if (!_isCurrentConnection(generation)) {
          throw const _ConnectionChangedException('Connection changed');
        }
        await _handleSerialWriteFailure(e, generation);
        rethrow;
      }

      try {
        _invalidateConnection('Restarting serial command mode');
        await _serial.disconnect();
      } catch (_) {
        // Disconnect is best-effort; the underlying handle may already be
        // invalid, but we still want to drop any pending state.
      }
      _parser.reset();
      state = state.copyWith(
        connected: false,
        streaming: false,
        parserStats: _parser.stats,
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      final connected = await _connectWithFreshPort();
      if (!connected) {
        throw StateError('Serial port is not available after stopping stream');
      }
      state = state.copyWith(connected: true, streaming: false);
      reachedCommandMode = true;
    } finally {
      if (!reachedCommandMode) {
        // Any partial transition leaves us in a disconnected, non-streaming
        // state so the UI and heartbeat loop do not observe an inconsistency.
        _streamHeartbeat?.cancel();
        _streamWriteInFlight = false;
        try {
          await _serial.disconnect();
        } catch (_) {}
        _parser.reset();
        state = state.copyWith(
          connected: false,
          streaming: false,
          parserStats: _parser.stats,
        );
      }
    }
  }

  Future<void> deletePhoto(String filename) async {
    if (!state.connected || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _collectCommand(
        'rm /$filename',
        const Duration(milliseconds: 800),
        (_) => false,
        allowPartialOnTimeout: true,
      );
      state = state.copyWith(
        busy: false,
        gallery: state.gallery
            .where((photo) => photo.filename != filename)
            .toList(),
      );
    } catch (e) {
      if (e is _ConnectionChangedException) return;
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> clearPhotos() async {
    if (!state.connected || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _collectCommand(
        'clear_photos',
        const Duration(milliseconds: 1000),
        (_) => false,
        allowPartialOnTimeout: true,
      );
      state = state.copyWith(busy: false, gallery: const []);
    } catch (e) {
      if (e is _ConnectionChangedException) return;
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  void updateRenderSettings(RenderSettings settings) {
    state = state.copyWith(renderSettings: settings);
  }

  void setBaudRate(int baudRate) {
    state = state.copyWith(baudRate: baudRate);
  }

  void clearDebug() {
    _debugBuffer.clear();
    _debugFlushTimer?.cancel();
    _debugFlushTimer = null;
    state = state.copyWith(debugLines: const []);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ========================= Dual-vision (ESP32 only) =========================

  /// Probe the device for dual-vision support by sending `get_align\n` and
  /// looking for an `ALIGN ...` reply. Updates `state.dualVision`.
  ///
  /// If streaming is active, first switch to the same clean command-mode
  /// serial session used by gallery reads. Real ESP32 devices can otherwise
  /// bury or drop the short text response among queued binary frames.
  Future<void> probeDualVision() async {
    if (!state.connected) {
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(
          capability: DualVisionCapability.unknown,
          clearError: true,
        ),
      );
      return;
    }
    state = state.copyWith(
      dualVision: state.dualVision.copyWith(
        capability: DualVisionCapability.probing,
        clearError: true,
      ),
    );
    int? probeGeneration;
    try {
      if (state.streaming) {
        await _restartSerialForCommandMode();
      }
      if (!state.connected) {
        throw StateError('Serial connection closed before capability probe');
      }
      probeGeneration = _connectionGeneration;
      final bytes = await _collectCommand(
        'get_align',
        const Duration(milliseconds: 1500),
        (data) {
          final text = utf8.decode(data, allowMalformed: true);
          return AlignParams.tryParseResponse(text) != null;
        },
        allowPartialOnTimeout: true,
        terminator: '\n',
      );
      final text = utf8.decode(bytes, allowMalformed: true);
      final params = AlignParams.tryParseResponse(text);
      if (!_isCurrentConnection(probeGeneration)) return;
      if (params == null) {
        state = state.copyWith(
          dualVision: state.dualVision.copyWith(
            capability: DualVisionCapability.unsupported,
          ),
        );
      } else {
        state = state.copyWith(
          dualVision: state.dualVision.copyWith(
            capability: DualVisionCapability.supported,
            params: params,
            clearError: true,
          ),
        );
      }
    } catch (e) {
      if (probeGeneration != null && probeGeneration != _connectionGeneration) {
        return;
      }
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(
          capability: DualVisionCapability.error,
          lastError: e.toString(),
        ),
      );
    }
  }

  /// Send the affine portion (`set_align tx ty sx sy ang\n`) and update local
  /// state. Auto-saves to `/align.cfg` on the device.
  Future<void> writeAlignAffine(AlignParams desired) async {
    if (!_dualVisionReady) return;
    final generation = _connectionGeneration;
    try {
      await _writeLine(desired.formatSetAlign());
      if (!_isCurrentConnection(generation)) return;
      final current = state.dualVision.params ?? AlignParams.defaults;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(
          params: current.copyWith(
            tx: desired.tx,
            ty: desired.ty,
            sx: desired.sx,
            sy: desired.sy,
            ang: desired.ang,
          ),
          clearError: true,
        ),
      );
    } catch (e) {
      if (!_isCurrentConnection(generation)) return;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(lastError: e.toString()),
      );
    }
  }

  /// Send `set_alpha <0-255>\n`. Auto-saves on device.
  Future<void> writeFusionAlpha(int alpha) async {
    if (!_dualVisionReady) return;
    final generation = _connectionGeneration;
    final clamped = alpha.clamp(0, 255);
    try {
      await _writeLine('set_alpha $clamped');
      if (!_isCurrentConnection(generation)) return;
      final current = state.dualVision.params ?? AlignParams.defaults;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(
          params: current.copyWith(fusionAlpha: clamped),
          clearError: true,
        ),
      );
    } catch (e) {
      if (!_isCurrentConnection(generation)) return;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(lastError: e.toString()),
      );
    }
  }

  /// Toggle the camera vertical flip on the device. Persists to `/align.cfg`.
  /// Parses the firmware reply `VFLIP:0|1` to confirm the new value.
  Future<void> toggleCameraVflip() async {
    await _toggleFlip(
      command: 'toggle_vflip',
      replyPrefix: 'VFLIP:',
      apply: (params, v) => params.copyWith(vflip: v),
    );
  }

  /// Toggle the camera horizontal mirror on the device.
  Future<void> toggleCameraHflip() async {
    await _toggleFlip(
      command: 'toggle_hflip',
      replyPrefix: 'HFLIP:',
      apply: (params, v) => params.copyWith(hflip: v),
    );
  }

  /// Revert affine alignment and fusion alpha to firmware defaults.
  /// Camera orientation is left unchanged because the protocol only exposes
  /// toggle commands and its initial state may be unknown.
  Future<void> resetDualVisionToDefaults() async {
    if (!_dualVisionReady) return;
    await writeAlignAffine(AlignParams.defaults);
    await writeFusionAlpha(AlignParams.defaults.fusionAlpha);
  }

  bool get _dualVisionReady => state.connected && state.dualVision.isSupported;

  Future<void> _toggleFlip({
    required String command,
    required String replyPrefix,
    required AlignParams Function(AlignParams params, bool value) apply,
  }) async {
    if (!_dualVisionReady) return;
    final generation = _connectionGeneration;
    final responsePattern = RegExp('${RegExp.escape(replyPrefix)}([01])');
    try {
      final bytes = await _collectCommand(
        command,
        const Duration(milliseconds: 800),
        (data) {
          final text = utf8.decode(data, allowMalformed: true);
          return responsePattern.hasMatch(text);
        },
        terminator: '\n',
      );
      if (!_isCurrentConnection(generation)) return;
      final text = utf8.decode(bytes, allowMalformed: true);
      final match = responsePattern.firstMatch(text);
      if (match == null) {
        throw FormatException('Invalid response for $command: $text');
      }
      final value = match.group(1) == '1';
      final current = state.dualVision.params ?? AlignParams.defaults;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(
          params: apply(current, value),
          clearError: true,
        ),
      );
    } catch (e) {
      if (!_isCurrentConnection(generation)) return;
      state = state.copyWith(
        dualVision: state.dualVision.copyWith(lastError: e.toString()),
      );
    }
  }

  // ============================ Transport helpers ============================

  Future<void> _writeLine(String command) {
    final generation = _connectionGeneration;
    return _enqueueTransport(() {
      if (!_isCurrentConnection(generation)) return Future<void>.value();
      return _writeLineNow(command);
    });
  }

  Future<void> _writeLineNow(String command) {
    final bytes = Uint8List.fromList(utf8.encode('$command\n'));
    _appendDebugBytes('TX', bytes);
    return _writeSerial(bytes, command);
  }

  Future<void> _writeSerial(Uint8List bytes, String command) {
    return _serial
        .write(bytes)
        .timeout(
          _serialIoTimeout,
          onTimeout: () => throw TimeoutException(
            'Serial write "$command" timed out after '
            '${_serialIoTimeout.inMilliseconds}ms',
            _serialIoTimeout,
          ),
        );
  }

  Future<Uint8List> _collectCommand(
    String command,
    Duration timeout,
    bool Function(Uint8List data) done, {
    bool allowPartialOnTimeout = false,
    String terminator = '\r\n',
  }) async {
    final generation = _connectionGeneration;
    return _enqueueTransport(() {
      if (!_isCurrentConnection(generation)) {
        throw const _ConnectionChangedException('Connection changed');
      }
      return _runCollectCommand(
        command,
        timeout,
        done,
        allowPartialOnTimeout: allowPartialOnTimeout,
        terminator: terminator,
      );
    });
  }

  Future<T> _enqueueTransport<T>(Future<T> Function() operation) {
    final result = _transportQueue.then((_) => operation());
    _transportQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List> _runCollectCommand(
    String command,
    Duration timeout,
    bool Function(Uint8List data) done, {
    bool allowPartialOnTimeout = false,
    String terminator = '\r\n',
  }) async {
    _transactionBuffer.clear();
    final completer = Completer<Uint8List>();
    _transactionCompleter = completer;
    final commandBytes = Uint8List.fromList(utf8.encode('$command$terminator'));
    _appendDebugBytes('TX', commandBytes);
    Timer? timer;

    try {
      await _writeSerial(commandBytes, command);
      timer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
        final bytes = Uint8List.fromList(_transactionBuffer);
        if (done(bytes)) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete(bytes);
        }
      });
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (allowPartialOnTimeout) {
            return Uint8List.fromList(_transactionBuffer);
          }
          throw TimeoutException(
            'Serial command "$command" timed out after '
            '${timeout.inMilliseconds}ms '
            '(received ${_transactionBuffer.length} bytes)',
            timeout,
          );
        },
      );
    } finally {
      timer?.cancel();
      if (identical(_transactionCompleter, completer)) {
        _transactionCompleter = null;
        _transactionBuffer.clear();
      }
    }
  }

  void _handleBytes(Uint8List bytes) {
    _appendDebugBytes('RX', bytes);
    if (_transactionCompleter != null) {
      _transactionBuffer.addAll(bytes);
      return;
    }
    if (!state.streaming) return;
    final frames = _parser.feed(bytes);
    if (frames.isNotEmpty) {
      for (final frame in frames) {
        _frameController.add(frame);
      }
      state = state.copyWith(
        currentFrame: frames.last,
        parserStats: _parser.stats,
      );
    } else {
      state = state.copyWith(parserStats: _parser.stats);
    }
  }

  void _appendDebugBytes(String direction, Uint8List bytes) {
    _appendDebugText('$direction ${bytes.length}B  ${_hex(bytes)}');
  }

  void _appendDebugText(String line) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _debugBuffer.add('$timestamp  $line');
    while (_debugBuffer.length > _debugCapacity) {
      _debugBuffer.removeFirst();
    }
    _debugFlushTimer ??= Timer(
      const Duration(milliseconds: 100),
      _flushDebugLines,
    );
  }

  void _flushDebugLines() {
    _debugFlushTimer = null;
    state = state.copyWith(debugLines: List.unmodifiable(_debugBuffer));
  }

  SerialPortDescriptor? _resolvePort(List<SerialPortDescriptor> ports) {
    if (ports.isEmpty) return null;
    final selected = state.selectedPort;
    if (selected != null) {
      for (final port in ports) {
        if (port.id == selected.id) return port;
      }
    }
    return _resolvePreferredPort(ports);
  }

  Future<bool> _connectWithFreshPort({bool ignoreSelected = false}) async {
    final ports = await _serial.listPorts();
    final port = ignoreSelected
        ? _resolvePreferredPort(ports)
        : _resolvePort(ports);
    state = state.copyWith(
      ports: ports,
      selectedPort: port,
      clearSelectedPort: port == null,
    );
    if (port == null) {
      state = state.copyWith(busy: false);
      return false;
    }
    await _serial.connect(port, SerialOptions(baudRate: state.baudRate));
    _connectionGeneration += 1;
    return true;
  }

  bool _isCurrentConnection(int generation) {
    return state.connected && generation == _connectionGeneration;
  }

  void _invalidateConnection(String reason) {
    _connectionGeneration += 1;
    final transaction = _transactionCompleter;
    if (transaction != null && !transaction.isCompleted) {
      transaction.completeError(_ConnectionChangedException(reason));
    }
    _transactionCompleter = null;
    _transactionBuffer.clear();
  }

  SerialPortDescriptor? _resolvePreferredPort(
    List<SerialPortDescriptor> ports,
  ) {
    for (final port in ports) {
      if (_isPreferredPort(port)) return port;
    }
    if (ports.length == 1 && ports.single.virtual) return ports.single;
    return null;
  }
}

class _ConnectionChangedException implements Exception {
  const _ConnectionChangedException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isPreferredPort(SerialPortDescriptor port) {
  final id = port.id.toLowerCase();
  final label = port.label.toLowerCase();
  final description = port.description?.toLowerCase() ?? '';
  return port.vendorId == 0x2e8a ||
      port.vendorId == 0x1a86 ||
      id.contains('usbmodem') ||
      id.contains('wchusbserial') ||
      label.contains('pico') ||
      label.contains('ch340') ||
      label.contains('wch') ||
      label.contains('usbmodem') ||
      description.contains('ch340') ||
      description.contains('wch');
}

bool _isMissingPortError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('errno = 2') ||
      message.contains('no such file') ||
      message.contains('disappeared');
}

String _hex(Uint8List bytes) {
  return bytes
      .take(96)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
