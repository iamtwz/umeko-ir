import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'serial_adapter.dart';

class WebSerialAdapter implements SerialAdapter {
  JSObject? _port;
  JSObject? _reader;
  final _controller = StreamController<Uint8List>.broadcast();
  bool _reading = false;

  @override
  Stream<Uint8List> get input => _controller.stream;

  JSObject? get _serial {
    final navigator = globalContext['navigator'] as JSObject?;
    return navigator?['serial'] as JSObject?;
  }

  @override
  Future<List<SerialPortDescriptor>> listPorts() async {
    final serial = _serial;
    if (serial == null) return const [];

    final ports = await serial
        .callMethod<JSPromise<JSArray<JSObject>>>('getPorts'.toJS)
        .toDart;
    final descriptors = <SerialPortDescriptor>[];
    final seenIds = <String, int>{};
    for (var i = 0; i < ports.length; i++) {
      final port = ports[i];
      final descriptor = _descriptorFor(port, i);
      // Disambiguate collisions (e.g. multiple identical devices with no serial).
      final count = (seenIds[descriptor.id] ?? 0) + 1;
      seenIds[descriptor.id] = count;
      descriptors.add(
        count == 1
            ? descriptor
            : SerialPortDescriptor(
                id: '${descriptor.id}#$count',
                label: descriptor.label,
                description: descriptor.description,
                vendorId: descriptor.vendorId,
                productId: descriptor.productId,
                virtual: descriptor.virtual,
              ),
      );
    }
    if (descriptors.isEmpty) {
      descriptors.add(
        const SerialPortDescriptor(
          id: 'browser-request-port',
          label: 'Browser Serial - choose device',
          description: 'Request access from the browser',
          virtual: true,
        ),
      );
    }
    return descriptors;
  }

  @override
  Future<void> connect(SerialPortDescriptor port, SerialOptions options) async {
    final serial = _serial;
    if (serial == null) {
      throw UnsupportedError(
        'Web Serial API is not available. Use Chrome or Edge over localhost/HTTPS.',
      );
    }

    JSObject selectedPort;
    if (port.id == 'browser-request-port') {
      selectedPort = await serial
          .callMethod<JSPromise<JSObject>>('requestPort'.toJS)
          .toDart;
    } else {
      final ports = await serial
          .callMethod<JSPromise<JSArray<JSObject>>>('getPorts'.toJS)
          .toDart;
      JSObject? matched;
      final seenIds = <String, int>{};
      for (var i = 0; i < ports.length; i++) {
        final candidate = ports[i];
        final descriptor = _descriptorFor(candidate, i);
        final count = (seenIds[descriptor.id] ?? 0) + 1;
        seenIds[descriptor.id] = count;
        final effectiveId = count == 1
            ? descriptor.id
            : '${descriptor.id}#$count';
        if (effectiveId == port.id) {
          matched = candidate;
          break;
        }
      }
      if (matched == null) {
        throw StateError(
          'Authorized serial port "${port.id}" is no longer available. '
          'Re-select the device.',
        );
      }
      selectedPort = matched;
    }

    final openOptions = JSObject()
      ..['baudRate'] = options.baudRate.toJS
      ..['dataBits'] = 8.toJS
      ..['stopBits'] = 1.toJS
      ..['parity'] = 'none'.toJS
      ..['flowControl'] = 'none'.toJS
      ..['bufferSize'] = (16 * 1024).toJS;
    await selectedPort
        .callMethod<JSPromise<JSAny?>>('open'.toJS, openOptions)
        .toDart;

    await _setSignals(selectedPort, false, false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _setSignals(selectedPort, options.dtr, options.rts);

    _port = selectedPort;
    _startReadLoop();
  }

  @override
  Future<void> write(Uint8List data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port is not open');
    final writable = port['writable'] as JSObject?;
    if (writable == null) throw StateError('Serial port is not writable');
    final writer = writable.callMethod<JSObject>('getWriter'.toJS);
    try {
      await writer
          .callMethod<JSPromise<JSAny?>>('write'.toJS, data.toJS)
          .toDart;
    } finally {
      writer.callMethod<JSAny?>('releaseLock'.toJS);
    }
  }

  @override
  Future<void> disconnect() async {
    _reading = false;
    final reader = _reader;
    _reader = null;
    if (reader != null) {
      try {
        await reader.callMethod<JSPromise<JSAny?>>('cancel'.toJS).toDart;
      } catch (_) {}
      try {
        reader.callMethod<JSAny?>('releaseLock'.toJS);
      } catch (_) {}
    }
    final port = _port;
    _port = null;
    if (port != null) {
      try {
        await port.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
      } catch (_) {}
    }
  }

  Future<void> _setSignals(JSObject port, bool dtr, bool rts) async {
    final signals = JSObject()
      ..['dataTerminalReady'] = dtr.toJS
      ..['requestToSend'] = rts.toJS;
    await port.callMethod<JSPromise<JSAny?>>('setSignals'.toJS, signals).toDart;
  }

  void _startReadLoop() {
    final port = _port;
    if (port == null) return;
    final readable = port['readable'] as JSObject?;
    if (readable == null) return;
    _reader = readable.callMethod<JSObject>('getReader'.toJS);
    _reading = true;
    unawaited(_readLoop());
  }

  Future<void> _readLoop() async {
    final reader = _reader;
    if (reader == null) return;
    try {
      while (_reading) {
        try {
          final result = await reader
              .callMethod<JSPromise<JSObject>>('read'.toJS)
              .toDart;
          final done = (result['done'] as JSBoolean?)?.toDart ?? false;
          if (done) break;
          final value = result['value'] as JSUint8Array?;
          if (value != null) {
            _controller.add(Uint8List.fromList(value.toDart));
          }
        } catch (e) {
          if (_reading) _controller.addError(e);
          break;
        }
      }
    } finally {
      _reading = false;
    }
  }

  SerialPortDescriptor _descriptorFor(JSObject port, int index) {
    final info = port.callMethod<JSObject>('getInfo'.toJS);
    final vendorId = (info['usbVendorId'] as JSNumber?)?.toDartInt;
    final productId = (info['usbProductId'] as JSNumber?)?.toDartInt;
    final serialNumber = (info['serialNumber'] as JSString?)?.toDart;
    final id = _stableId(vendorId, productId, serialNumber, index);
    final label = vendorId != null && productId != null
        ? 'Authorized Serial '
              '${vendorId.toRadixString(16).padLeft(4, '0')}:'
              '${productId.toRadixString(16).padLeft(4, '0')}'
              '${serialNumber != null && serialNumber.isNotEmpty ? ' ($serialNumber)' : ''}'
        : 'Authorized Serial ${index + 1}';
    return SerialPortDescriptor(
      id: id,
      label: label,
      description: 'Browser-authorized serial device',
      vendorId: vendorId,
      productId: productId,
    );
  }

  static String _stableId(
    int? vendorId,
    int? productId,
    String? serialNumber,
    int index,
  ) {
    if (vendorId != null && productId != null) {
      final vid = vendorId.toRadixString(16).padLeft(4, '0');
      final pid = productId.toRadixString(16).padLeft(4, '0');
      if (serialNumber != null && serialNumber.isNotEmpty) {
        return 'authorized-$vid-$pid-$serialNumber';
      }
      return 'authorized-$vid-$pid';
    }
    // Fallback: stable only within one session.
    return 'authorized-unknown-$index';
  }
}
