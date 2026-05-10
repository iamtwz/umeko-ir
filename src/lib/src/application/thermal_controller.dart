import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device_gallery.dart';
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
    );
  }
}

class ThermalController extends Notifier<ThermalState> {
  static const _debugCapacity = 500;

  late final SerialAdapter _serial;
  final ThermalParser _parser = ThermalParser();
  StreamSubscription<Uint8List>? _subscription;
  Completer<Uint8List>? _transactionCompleter;
  final List<int> _transactionBuffer = [];
  final StreamController<ThermalFrame> _frameController =
      StreamController<ThermalFrame>.broadcast();
  Future<void> _transactionQueue = Future<void>.value();
  final Queue<String> _debugBuffer = Queue<String>();
  Timer? _debugFlushTimer;
  Timer? _streamHeartbeat;
  bool _streamWriteInFlight = false;

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
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    await _serial.disconnect();
    _parser.reset();
    state = state.copyWith(
      connected: false,
      streaming: false,
      parserStats: _parser.stats,
    );
  }

  Future<void> startStream() async {
    if (!state.connected) return;
    _transactionCompleter = null;
    _transactionBuffer.clear();
    _parser.reset();
    try {
      await _writeLine('stream');
    } catch (e) {
      await _handleSerialWriteFailure(e);
      return;
    }
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
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    if (state.connected) {
      try {
        await _writeLine('stop_stream');
      } catch (e) {
        await _handleSerialWriteFailure(e);
        return;
      }
    }
    state = state.copyWith(streaming: false);
  }

  Future<void> _sendStreamHeartbeat() async {
    if (_streamWriteInFlight || !state.connected || !state.streaming) return;
    _streamWriteInFlight = true;
    try {
      await _writeLine('stream');
    } catch (e) {
      await _handleSerialWriteFailure(e);
    } finally {
      _streamWriteInFlight = false;
    }
  }

  Future<void> _handleSerialWriteFailure(Object error) async {
    _streamHeartbeat?.cancel();
    _streamWriteInFlight = false;
    try {
      await _serial.disconnect();
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
    );
  }

  Future<void> loadGallery() async {
    if (!state.connected) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (state.streaming) {
        await stopStream();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final listBytes = await _collectCommand(
        'ls',
        const Duration(milliseconds: 3500),
        (data) {
          return utf8.decode(data, allowMalformed: true).contains('Total:');
        },
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
      state = state.copyWith(
        busy: false,
        galleryLoading: false,
        error: e.toString(),
      );
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
      );
      state = state.copyWith(
        busy: false,
        gallery: state.gallery
            .where((photo) => photo.filename != filename)
            .toList(),
      );
    } catch (e) {
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
      );
      state = state.copyWith(busy: false, gallery: const []);
    } catch (e) {
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

  Future<void> _writeLine(String command) {
    final bytes = Uint8List.fromList(utf8.encode('$command\n'));
    _appendDebugBytes('TX', bytes);
    return _serial.write(bytes);
  }

  Future<Uint8List> _collectCommand(
    String command,
    Duration timeout,
    bool Function(Uint8List data) done,
  ) async {
    final transaction = _transactionQueue.then(
      (_) => _runCollectCommand(command, timeout, done),
    );
    _transactionQueue = transaction.then<void>((_) {}, onError: (_) {});
    return transaction;
  }

  Future<Uint8List> _runCollectCommand(
    String command,
    Duration timeout,
    bool Function(Uint8List data) done,
  ) async {
    _transactionBuffer.clear();
    final completer = Completer<Uint8List>();
    _transactionCompleter = completer;
    final commandBytes = Uint8List.fromList(utf8.encode('$command\r\n'));
    _appendDebugBytes('TX', commandBytes);
    await _serial.write(commandBytes);

    final timer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      final bytes = Uint8List.fromList(_transactionBuffer);
      if (done(bytes)) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(bytes);
      }
    });

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => Uint8List.fromList(_transactionBuffer),
      );
    } finally {
      timer.cancel();
      _transactionCompleter = null;
      _transactionBuffer.clear();
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
    return true;
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

bool _isPreferredPort(SerialPortDescriptor port) {
  final id = port.id.toLowerCase();
  final label = port.label.toLowerCase();
  return port.vendorId == 0x2e8a ||
      id.contains('usbmodem') ||
      label.contains('pico') ||
      label.contains('usbmodem');
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
