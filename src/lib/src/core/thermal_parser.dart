import 'dart:convert';
import 'dart:typed_data';

import 'thermal_frame.dart';

final _legacyBegin = ascii.encode('BEGIN');
final _legacyEnd = ascii.encode('END');
final _mlx40Begin = ascii.encode('MLX40BEGIN');
final _mlx40End = ascii.encode('MLX40END');
final _mlx41Begin = ascii.encode('MLX41BEGIN');
final _mlx41End = ascii.encode('MLX41END');

const _heimannWidth = 32;
const _heimannHeight = 32;
const _heimannPayloadSize = 4 + _heimannWidth * _heimannHeight * 2;
final _heimannPacketSize =
    _legacyBegin.length + _heimannPayloadSize + _legacyEnd.length;

const _legacyWidth = 32;
const _legacyHeight = 24;
const _legacyPayloadSize = 12 + _legacyWidth * _legacyHeight * 4;
final _legacyPacketSize =
    _legacyBegin.length + _legacyPayloadSize + _legacyEnd.length;

const _mlx40Width = 32;
const _mlx40Height = 24;
const _mlx40PayloadSize = 8 + _mlx40Width * _mlx40Height * 4;
final _mlx40PacketSize =
    _mlx40Begin.length + _mlx40PayloadSize + _mlx40End.length;

const _mlx41Width = 16;
const _mlx41Height = 12;
const _mlx41PayloadSize = 8 + _mlx41Width * _mlx41Height * 4;
final _mlx41PacketSize =
    _mlx41Begin.length + _mlx41PayloadSize + _mlx41End.length;

class ThermalParser {
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

    final mlx40Index = _indexOfBytes(_buffer, _mlx40Begin);
    if (mlx40Index != -1) {
      candidates.add(
        _Candidate(
          index: mlx40Index,
          format: ThermalSensorType.mlx90640,
          begin: _mlx40Begin,
          end: _mlx40End,
          packetSize: _mlx40PacketSize,
          payloadSize: _mlx40PayloadSize,
        ),
      );
    }

    final mlx41Index = _indexOfBytes(_buffer, _mlx41Begin);
    if (mlx41Index != -1) {
      candidates.add(
        _Candidate(
          index: mlx41Index,
          format: ThermalSensorType.mlx90641,
          begin: _mlx41Begin,
          end: _mlx41End,
          packetSize: _mlx41PacketSize,
          payloadSize: _mlx41PayloadSize,
        ),
      );
    }

    final beginIndex = _indexOfBytes(_buffer, _legacyBegin);
    if (beginIndex != -1) {
      final heimannEndOffset =
          beginIndex + _legacyBegin.length + _heimannPayloadSize;
      final legacyEndOffset =
          beginIndex + _legacyBegin.length + _legacyPayloadSize;
      final canBeHeimann = _hasBytes(_buffer, heimannEndOffset, _legacyEnd);
      final canBeLegacy = _hasBytes(_buffer, legacyEndOffset, _legacyEnd);
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
          begin: _legacyBegin,
          end: _legacyEnd,
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
        8,
        _mlx40Width,
        _mlx40Height,
        format,
      ),
      ThermalSensorType.mlx90641 => _parseFloatFrame(
        payload,
        8,
        _mlx41Width,
        _mlx41Height,
        format,
      ),
      ThermalSensorType.legacy => _parseLegacyFrame(payload),
      ThermalSensorType.heimann => _parseHeimannFrame(payload),
    };
  }

  ThermalFrame _parseFloatFrame(
    Uint8List payload,
    int dataOffset,
    int width,
    int height,
    ThermalSensorType sensorType,
  ) {
    final view = ByteData.sublistView(payload);
    final tMax = view.getFloat32(0, Endian.little);
    final tMin = view.getFloat32(4, Endian.little);
    final temps = Float32List(width * height);
    for (var i = 0; i < temps.length; i++) {
      temps[i] = view.getFloat32(dataOffset + i * 4, Endian.little);
    }
    return _frame(temps, width, height, sensorType, tMin, tMax, _mean(temps));
  }

  ThermalFrame _parseLegacyFrame(Uint8List payload) {
    final view = ByteData.sublistView(payload);
    final tMax = view.getFloat32(0, Endian.little);
    final tMin = view.getFloat32(4, Endian.little);
    final tAvg = view.getFloat32(8, Endian.little);
    final temps = Float32List(_legacyWidth * _legacyHeight);
    for (var i = 0; i < temps.length; i++) {
      temps[i] = view.getFloat32(12 + i * 4, Endian.little);
    }
    return _frame(
      temps,
      _legacyWidth,
      _legacyHeight,
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
    final temps = Float32List(_heimannWidth * _heimannHeight);
    for (var i = 0; i < temps.length; i++) {
      temps[i] = view.getUint16(4 + i * 2, Endian.little) * 0.1 - 273.15;
    }
    return _frame(
      temps,
      _heimannWidth,
      _heimannHeight,
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
