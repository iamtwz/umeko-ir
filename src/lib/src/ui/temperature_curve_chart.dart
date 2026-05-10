import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/temperature_series.dart';
import '../core/thermal_points.dart';
import '../l10n/app_localizations.dart';

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
    final textStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 11,
    );
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
          AppLocalizations.of(context)!.noPointSamples,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    final cursorSeconds = cursor == null ? null : cursor!.inMilliseconds / 1000;
    final bounds = _ChartBounds.fromLines(lines);
    return LineChart(
      LineChartData(
        lineBarsData: lines,
        minX: bounds.minX,
        maxX: bounds.maxX,
        minY: bounds.minY,
        maxY: bounds.maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: bounds.yInterval,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(value.toStringAsFixed(1), style: textStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: bounds.xInterval,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(value.toStringAsFixed(1), style: textStyle),
              ),
            ),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 140,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.x.toStringAsFixed(1)}s  ${spot.y.toStringAsFixed(1)}C',
                  TextStyle(
                    color: spot.bar.color ?? colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartBounds {
  const _ChartBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xInterval,
    required this.yInterval,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double xInterval;
  final double yInterval;

  factory _ChartBounds.fromLines(List<LineChartBarData> lines) {
    final spots = lines.expand((line) => line.spots).toList();
    var minX = spots.first.x;
    var maxX = spots.first.x;
    var minY = spots.first.y;
    var maxY = spots.first.y;
    for (final spot in spots.skip(1)) {
      if (spot.x < minX) minX = spot.x;
      if (spot.x > maxX) maxX = spot.x;
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    final xPadding = _paddingFor(minX, maxX, minimum: 0.5);
    final yPadding = _paddingFor(minY, maxY, minimum: 0.5);
    minX = (minX - xPadding).clamp(0, double.infinity);
    maxX += xPadding;
    minY -= yPadding;
    maxY += yPadding;

    if (maxX <= minX) maxX = minX + 1;
    if (maxY <= minY) maxY = minY + 1;

    return _ChartBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      xInterval: _niceInterval(maxX - minX),
      yInterval: _niceInterval(maxY - minY),
    );
  }

  static double _paddingFor(double min, double max, {required double minimum}) {
    return ((max - min).abs() * 0.08).clamp(minimum, double.infinity);
  }

  static double _niceInterval(double range) {
    final raw = range / 4;
    if (raw <= 0) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    final normalized = raw / magnitude;
    final nice = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return nice * magnitude.toDouble();
  }
}
