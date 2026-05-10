import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/thermal_points.dart';

final thermalPointsProvider =
    NotifierProvider<ThermalPointsController, List<ThermalPoint>>(
      ThermalPointsController.new,
    );

class ThermalPointsController extends Notifier<List<ThermalPoint>> {
  var _nextPointNumber = 1;

  @override
  List<ThermalPoint> build() => const [];

  void add(double xNorm, double yNorm) {
    final label = 'P$_nextPointNumber';
    _nextPointNumber += 1;
    state = [
      ...state,
      ThermalPoint(
        id: 'point-${DateTime.now().microsecondsSinceEpoch}',
        xNorm: xNorm.clamp(0.0, 1.0),
        yNorm: yNorm.clamp(0.0, 1.0),
        label: label,
        colorArgb: _colorForIndex(state.length),
      ),
    ];
  }

  void move(String id, double xNorm, double yNorm) {
    state = [
      for (final point in state)
        point.id == id
            ? point.copyWith(
                xNorm: xNorm.clamp(0.0, 1.0),
                yNorm: yNorm.clamp(0.0, 1.0),
              )
            : point,
    ];
  }

  void remove(String id) {
    state = state.where((point) => point.id != id).toList();
  }

  void clear() {
    state = const [];
  }

  int _colorForIndex(int index) {
    const colors = [
      0xffffd166,
      0xff06d6a0,
      0xffef476f,
      0xff118ab2,
      0xfff78c6b,
      0xffc77dff,
    ];
    return colors[index % colors.length];
  }
}
