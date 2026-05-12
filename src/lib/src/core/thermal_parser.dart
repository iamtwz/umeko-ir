import 'dart:typed_data';

import 'thermal_frame.dart';
import 'thermal_format.dart';

final _heimannPayloadSize = 4 + DevicePhotoFormat.uint16_32x32.payloadSize;
final _heimannPacketSize =
    legacyBeginMarker.length + _heimannPayloadSize + legacyEndMarker.length;

final _legacyPayloadSize = 12 + legacyWidth * legacyHeight * 4;
final _legacyPacketSize =
    legacyBeginMarker.length + _legacyPayloadSize + legacyEndMarker.length;

final _mlx40PayloadSize = 8 + DevicePhotoFormat.float32_32x24.payloadSize;
final _mlx40PacketSize =
    mlx90640BeginMarker.length + _mlx40PayloadSize + mlx90640EndMarker.length;

final _mlx41PayloadSize = 8 + DevicePhotoFormat.float32_16x12.payloadSize;
final _mlx41PacketSize =
    mlx90641BeginMarker.length + _mlx41PayloadSize + mlx90641EndMarker.length;

class ThermalParser {
  // Guard against unbounded buffer growth on malformed streams. The largest
  // known packet (legacy 160x120 float32) is ~77KB; a few MB of slack is plenty
  // while still bounding memory under garbage input.
  static const int _maxBufferBytes = 2 * 1024 * 1024;
  // When we exceed the cap, keep the tail so that a half-received real packet
  // can still be recovered once the sync marker lands.
  static const int _trimKeepTail = 128 * 1024;

  Uint8List _buffer = Uint8List(0);
  ParserStats _stats = const ParserStats.empty();
  int _frameCounter = 0;

  ParserStats get stats => _stats;

  List<ThermalFrame> feed(Uint8List chunk) {
    _stats = _stats.copyWith(
      bytesReceived: _stats.bytesReceived + chunk.length,
    );
    final nextBuffer = Uint8List(_buffer.length + chunk.length);
    nextBuffer.setAll(0, _buffer);
    nextBuffer.setAll(_buffer.length, chunk);
    _buffer = nextBuffer;

    if (_buffer.length > _maxBufferBytes) {
      // Treat this as a desync event: drop everything but the tail so a real
      // packet boundary can still be found once the marker lands.
      _buffer = _buffer.sublist(_buffer.length - _trimKeepTail);
      _stats = _stats.copyWith(syncErrors: _stats.syncErrors + 1);
    }

    final frames = <ThermalFrame>[];

    while (true) {
      final candidate = _findNextCandidate();
      if (candidate == null) {
        _buffer = _buffer.length > 9
            ? _buffer.sublist(_buffer.length - 9)
            : _buffer;
        break;
      }

      if (candidate.index > 0) {
        _buffer = _buffer.sublist(candidate.index);
        continue;
      }

      if (_buffer.length < candidate.packetSize) break;

      final endOffset = candidate.begin.length + candidate.payloadSize;
      if (!_hasBytes(_buffer, endOffset, candidate.end)) {
        _stats = _stats.copyWith(syncErrors: _stats.syncErrors + 1);
        _buffer = _buffer.sublist(1);
        continue;
      }

      final payload = _buffer.sublist(candidate.begin.length, endOffset);
      final frame = _parsePayload(payload, candidate.format);
      frames.add(frame);
      _stats = _stats.copyWith(
        packetsFound: _stats.packetsFound + 1,
        lastFormat: frame.sensorType,
      );
      _buffer = _buffer.sublist(candidate.packetSize);
    }

    _stats = _stats.copyWith(bufferLength: _buffer.length);
    return frames;
  }

  void reset() {
    _buffer = Uint8List(0);
    _stats = const ParserStats.empty();
    _frameCounter = 0;
  }

  _Candidate? _findNextCandidate() {
    final candidates = <_Candidate>[];

    final mlx40Index = _indexOfBytes(_buffer, mlx90640BeginMarker);
    if (mlx40Index != -1) {
      candidates.add(
        _Candidate(
          index: mlx40Index,
          format: ThermalSensorType.mlx90640,
          begin: mlx90640BeginMarker,
          end: mlx90640EndMarker,
          packetSize: _mlx40PacketSize,
          payloadSize: _mlx40PayloadSize,
        ),
      );
    }

    final mlx41Index = _indexOfBytes(_buffer, mlx90641BeginMarker);
    if (mlx41Index != -1) {
      candidates.add(
        _Candidate(
          index: mlx41Index,
          format: ThermalSensorType.mlx90641,
          begin: mlx90641BeginMarker,
          end: mlx90641EndMarker,
          packetSize: _mlx41PacketSize,
          payloadSize: _mlx41PayloadSize,
        ),
      );
    }

    final beginIndex = _indexOfBytes(_buffer, legacyBeginMarker);
    if (beginIndex != -1) {
      final heimannEndOffset =
          beginIndex + legacyBeginMarker.length + _heimannPayloadSize;
      final legacyEndOffset =
          beginIndex + legacyBeginMarker.length + _legacyPayloadSize;
      final canBeHeimann = _hasBytes(
        _buffer,
        heimannEndOffset,
        legacyEndMarker,
      );
      final canBeLegacy = _hasBytes(_buffer, legacyEndOffset, legacyEndMarker);
      final waitForMore =
          !canBeHeimann &&
          !canBeLegacy &&
          _buffer.length - beginIndex < _legacyPacketSize;
      candidates.add(
        _Candidate(
          index: beginIndex,
          format: canBeLegacy || waitForMore
              ? ThermalSensorType.legacy
              : ThermalSensorType.heimann,
          begin: legacyBeginMarker,
          end: legacyEndMarker,
          packetSize: canBeLegacy || waitForMore
              ? _legacyPacketSize
              : _heimannPacketSize,
          payloadSize: canBeLegacy || waitForMore
              ? _legacyPayloadSize
              : _heimannPayloadSize,
        ),
      );
    }

    candidates.sort((a, b) => a.index.compareTo(b.index));
    return candidates.isEmpty ? null : candidates.first;
  }

  ThermalFrame _parsePayload(Uint8List payload, ThermalSensorType format) {
    return switch (format) {
      ThermalSensorType.mlx90640 => _parseFloatFrame(
        payload,
        DevicePhotoFormat.float32_32x24,
      ),
      ThermalSensorType.mlx90641 => _parseFloatFrame(
        payload,
        DevicePhotoFormat.float32_16x12,
      ),
      ThermalSensorType.legacy => _parseLegacyFrame(payload),
      ThermalSensorType.heimann => _parseHeimannFrame(payload),
    };
  }

  ThermalFrame _parseFloatFrame(Uint8List payload, DevicePhotoFormat format) {
    final view = ByteData.sublistView(payload);
    final tMax = view.getFloat32(0, Endian.little);
    final tMin = view.getFloat32(4, Endian.little);
    final temps = decodeTemperaturePayload(view, format, offset: 8);
    return _frame(
      temps,
      format.width,
      format.height,
      format.sensorType,
      tMin,
      tMax,
      _mean(temps),
    );
  }

  ThermalFrame _parseLegacyFrame(Uint8List payload) {
    final view = ByteData.sublistView(payload);
    final tMax = view.getFloat32(0, Endian.little);
    final tMin = view.getFloat32(4, Endian.little);
    final tAvg = view.getFloat32(8, Endian.little);
    final temps = Float32List(legacyWidth * legacyHeight);
    for (var i = 0; i < temps.length; i++) {
      temps[i] = view.getFloat32(12 + i * 4, Endian.little);
    }
    return _frame(
      temps,
      legacyWidth,
      legacyHeight,
      ThermalSensorType.legacy,
      tMin,
      tMax,
      tAvg,
    );
  }

  ThermalFrame _parseHeimannFrame(Uint8List payload) {
    final view = ByteData.sublistView(payload);
    final tMax = view.getUint16(0, Endian.little) * 0.1 - 273.15;
    final tMin = view.getUint16(2, Endian.little) * 0.1 - 273.15;
    final temps = decodeTemperaturePayload(
      view,
      DevicePhotoFormat.uint16_32x32,
      offset: 4,
    );
    return _frame(
      temps,
      DevicePhotoFormat.uint16_32x32.width,
      DevicePhotoFormat.uint16_32x32.height,
      ThermalSensorType.heimann,
      tMin,
      tMax,
      _mean(temps),
    );
  }

  ThermalFrame _frame(
    Float32List temps,
    int width,
    int height,
    ThermalSensorType sensorType,
    double tMin,
    double tMax,
    double tAvg,
  ) {
    _frameCounter += 1;
    return ThermalFrame(
      id: 'frame-$_frameCounter',
      timestamp: DateTime.now(),
      temperatures: temps,
      width: width,
      height: height,
      sensorType: sensorType,
      tMin: tMin,
      tMax: tMax,
      tAvg: tAvg,
    );
  }
}

class _Candidate {
  const _Candidate({
    required this.index,
    required this.format,
    required this.begin,
    required this.end,
    required this.packetSize,
    required this.payloadSize,
  });

  final int index;
  final ThermalSensorType format;
  final List<int> begin;
  final List<int> end;
  final int packetSize;
  final int payloadSize;
}

int _indexOfBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

bool _hasBytes(Uint8List haystack, int offset, List<int> needle) {
  if (offset + needle.length > haystack.length) return false;
  for (var i = 0; i < needle.length; i++) {
    if (haystack[offset + i] != needle[i]) return false;
  }
  return true;
}

double _mean(Float32List values) {
  var sum = 0.0;
  for (final value in values) {
    sum += value;
  }
  return sum / values.length;
}
