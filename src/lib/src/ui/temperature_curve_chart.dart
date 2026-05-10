import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/temperature_series.dart';
import '../core/thermal_points.dart';

class TemperatureCurveChart extends StatelessWidget {
  const TemperatureCurveChart({
    super.key,
    required this.series,
    required this.points,
    this.cursor,
  });

  final Map<String, List<TemperatureSample>> series;
  final List<ThermalPoint> points;
  final Duration? cursor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lines = [
      for (final point in points)
        if ((series[point.id] ?? const []).isNotEmpty)
          LineChartBarData(
            spots: [
              for (final sample in series[point.id]!)
                FlSpot(
                  sample.elapsed.inMilliseconds / 1000,
                  sample.temperature,
                ),
            ],
            isCurved: true,
            barWidth: 2,
            color: point.color,
            dotData: const FlDotData(show: false),
          ),
    ];
    if (lines.isEmpty) {
      return Center(
        child: Text(
          'No point samples',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    final cursorSeconds = cursor == null ? null : cursor!.inMilliseconds / 1000;
    return LineChart(
      LineChartData(
        lineBarsData: lines,
        minY: _minY(lines),
        maxY: _maxY(lines),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 38),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 24),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        extraLinesData: cursorSeconds == null
            ? null
            : ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: cursorSeconds,
                    color: colorScheme.primary,
                    strokeWidth: 1,
                  ),
                ],
              ),
      ),
    );
  }

  double _minY(List<LineChartBarData> lines) {
    final values = lines.expand((line) => line.spots).map((spot) => spot.y);
    return values.reduce((a, b) => a < b ? a : b) - 1;
  }

  double _maxY(List<LineChartBarData> lines) {
    final values = lines.expand((line) => line.spots).map((spot) => spot.y);
    return values.reduce((a, b) => a > b ? a : b) + 1;
  }
}
