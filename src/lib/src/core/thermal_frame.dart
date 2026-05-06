import 'dart:typed_data';

enum ThermalSensorType { heimann, mlx90640, mlx90641, legacy }

class ThermalFrame {
  const ThermalFrame({
    required this.id,
    required this.timestamp,
    required this.temperatures,
    required this.width,
    required this.height,
    required this.sensorType,
    required this.tMin,
    required this.tMax,
    required this.tAvg,
  });

  final String id;
  final DateTime timestamp;
  final Float32List temperatures;
  final int width;
  final int height;
  final ThermalSensorType sensorType;
  final double tMin;
  final double tMax;
  final double tAvg;

  int get pixelCount => width * height;
}

class ParserStats {
  const ParserStats({
    required this.bytesReceived,
    required this.packetsFound,
    required this.syncErrors,
    required this.bufferLength,
    this.lastFormat,
  });

  const ParserStats.empty()
    : bytesReceived = 0,
      packetsFound = 0,
      syncErrors = 0,
      bufferLength = 0,
      lastFormat = null;

  final int bytesReceived;
  final int packetsFound;
  final int syncErrors;
  final int bufferLength;
  final ThermalSensorType? lastFormat;

  ParserStats copyWith({
    int? bytesReceived,
    int? packetsFound,
    int? syncErrors,
    int? bufferLength,
    ThermalSensorType? lastFormat,
  }) {
    return ParserStats(
      bytesReceived: bytesReceived ?? this.bytesReceived,
      packetsFound: packetsFound ?? this.packetsFound,
      syncErrors: syncErrors ?? this.syncErrors,
      bufferLength: bufferLength ?? this.bufferLength,
      lastFormat: lastFormat ?? this.lastFormat,
    );
  }
}
