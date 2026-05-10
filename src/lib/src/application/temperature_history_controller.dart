import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/temperature_series.dart';
import '../core/thermal_frame.dart';
import '../core/thermal_points.dart';
import 'thermal_controller.dart';
import 'thermal_points_controller.dart';

final temperatureHistoryProvider =
    NotifierProvider<TemperatureHistoryController, TemperatureHistoryState>(
      TemperatureHistoryController.new,
    );

class TemperatureHistoryState {
  const TemperatureHistoryState({this.series = const {}});

  final Map<String, List<TemperatureSample>> series;
}

class TemperatureHistoryController extends Notifier<TemperatureHistoryState> {
  static const _window = Duration(seconds: 60);
  StreamSubscription<ThermalFrame>? _subscription;
  DateTime? _startedAt;

  @override
  TemperatureHistoryState build() {
    ref.listen<int>(
      thermalControllerProvider.select((state) => state.streamSession),
      (previous, next) {
        if (previous != null && next != previous) clear();
      },
    );
    _subscription = ref
        .read(thermalControllerProvider.notifier)
        .frameStream
        .listen(_recordFrame);
    ref.onDispose(() => _subscription?.cancel());
    return const TemperatureHistoryState();
  }

  void clear() {
    _startedAt = null;
    state = const TemperatureHistoryState();
  }

  void _recordFrame(ThermalFrame frame) {
    final points = ref.read(thermalPointsProvider);
    if (points.isEmpty) {
      if (state.series.isNotEmpty) state = const TemperatureHistoryState();
      return;
    }
    _startedAt ??= frame.timestamp;
    final elapsed = frame.timestamp.difference(_startedAt!);
    final next = <String, List<TemperatureSample>>{};
    for (final point in points) {
      final previous = state.series[point.id] ?? const <TemperatureSample>[];
      final updated = [
        ...previous,
        TemperatureSample(
          elapsed: elapsed,
          temperature: sampleThermalPoint(frame, point),
        ),
      ].where((sample) => elapsed - sample.elapsed <= _window).toList();
      next[point.id] = updated;
    }
    state = TemperatureHistoryState(series: Map.unmodifiable(next));
  }
}
