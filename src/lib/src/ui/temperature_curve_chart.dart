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
    final firstElapsed = _firstElapsedSeconds(series, points);
    final lines = [
      for (final point in points)
        if ((series[point.id] ?? const []).isNotEmpty)
          LineChartBarData(
            spots: [
              for (final sample in series[point.id]!)
                FlSpot(
                  sample.elapsed.inMilliseconds / 1000 - firstElapsed,
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
    final cursorSeconds = cursor == null
        ? null
        : cursor!.inMilliseconds / 1000 - firstElapsed;
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
              reservedSize: 52,
              interval: bounds.yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                fitInside: SideTitleFitInsideData.fromTitleMeta(
                  meta,
                  distanceFromEdge: 2,
                ),
                child: Text(value.toStringAsFixed(1), style: textStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: bounds.xInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 8,
                fitInside: SideTitleFitInsideData.fromTitleMeta(
                  meta,
                  distanceFromEdge: 2,
                ),
                child: Text(_formatElapsed(value), style: textStyle),
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
                  '${_formatElapsed(spot.x)}  ${spot.y.toStringAsFixed(1)}C',
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

  String _formatElapsed(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  double _firstElapsedSeconds(
    Map<String, List<TemperatureSample>> series,
    List<ThermalPoint> points,
  ) {
    double? first;
    for (final point in points) {
      for (final sample in series[point.id] ?? const <TemperatureSample>[]) {
        final seconds = sample.elapsed.inMilliseconds / 1000;
        if (first == null || seconds < first) first = seconds;
      }
    }
    return first ?? 0;
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

    final xInterval = _niceInterval(maxX - minX, targetSteps: 4);
    final yInterval = _niceInterval(maxY - minY, targetSteps: 4);

    return _ChartBounds(
      minX: _alignDown(minX, xInterval).clamp(0, double.infinity),
      maxX: _alignUp(maxX, xInterval),
      minY: _alignDown(minY, yInterval),
      maxY: _alignUp(maxY, yInterval),
      xInterval: xInterval,
      yInterval: yInterval,
    );
  }

  static double _paddingFor(double min, double max, {required double minimum}) {
    return ((max - min).abs() * 0.08).clamp(minimum, double.infinity);
  }

  static double _niceInterval(double range, {required int targetSteps}) {
    final raw = range / targetSteps;
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

  static double _alignDown(double value, double interval) {
    if (interval <= 0) return value;
    return (value / interval).floorToDouble() * interval;
  }

  static double _alignUp(double value, double interval) {
    if (interval <= 0) return value;
    return (value / interval).ceilToDouble() * interval;
  }
}
