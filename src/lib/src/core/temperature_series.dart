import 'thermal_points.dart';
import 'uir_format.dart';

class TemperatureSample {
  const TemperatureSample({required this.elapsed, required this.temperature});

  final Duration elapsed;
  final double temperature;
}

Map<String, List<TemperatureSample>> buildTemperatureSeries({
  required List<UirFrameRecord> frames,
  required List<ThermalPoint> points,
}) {
  return {
    for (final point in points)
      point.id: [
        for (final record in frames)
          TemperatureSample(
            elapsed: record.elapsed,
            temperature: sampleThermalPoint(record.frame, point),
          ),
      ],
  };
}

String temperatureSeriesCsv({
  required List<UirFrameRecord> frames,
  required List<ThermalPoint> points,
}) {
  final buffer = StringBuffer(
    'timestamp_iso8601,elapsed_ms,frame_index,point_id,point_label,x_norm,y_norm,temperature_c\n',
  );
  for (final record in frames) {
    for (final point in points) {
      final value = sampleThermalPoint(record.frame, point);
      buffer
        ..write(record.frame.timestamp.toUtc().toIso8601String())
        ..write(',')
        ..write(record.elapsed.inMilliseconds)
        ..write(',')
        ..write(record.frameIndex)
        ..write(',')
        ..write(_csv(point.id))
        ..write(',')
        ..write(_csv(point.label))
        ..write(',')
        ..write(point.xNorm.toStringAsFixed(6))
        ..write(',')
        ..write(point.yNorm.toStringAsFixed(6))
        ..write(',')
        ..write(value.toStringAsFixed(2))
        ..write('\n');
    }
  }
  return buffer.toString();
}

String temperatureSamplesCsv({
  required Map<String, List<TemperatureSample>> series,
  required List<ThermalPoint> points,
}) {
  final buffer = StringBuffer(
    'elapsed_ms,point_id,point_label,x_norm,y_norm,temperature_c\n',
  );
  for (final point in points) {
    final samples = series[point.id] ?? const <TemperatureSample>[];
    for (final sample in samples) {
      buffer
        ..write(sample.elapsed.inMilliseconds)
        ..write(',')
        ..write(_csv(point.id))
        ..write(',')
        ..write(_csv(point.label))
        ..write(',')
        ..write(point.xNorm.toStringAsFixed(6))
        ..write(',')
        ..write(point.yNorm.toStringAsFixed(6))
        ..write(',')
        ..write(sample.temperature.toStringAsFixed(2))
        ..write('\n');
    }
  }
  return buffer.toString();
}

String _csv(String value) {
  if (!value.contains(RegExp('[,"\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
