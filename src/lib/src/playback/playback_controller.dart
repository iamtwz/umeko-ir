import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/thermal_frame.dart';
import '../core/uir_format.dart';

class UirPlaybackController extends ChangeNotifier {
  UirPlaybackController(this.document);

  final UirDocument document;
  Timer? _timer;
  var _index = 0;
  var _playing = false;
  var _speed = 1.0;
  var _loop = false;

  int get currentIndex => _index;
  bool get isPlaying => _playing;
  double get speed => _speed;
  bool get loop => _loop;
  int get frameCount => document.frames.length;
  bool get isVideo => document.header.isVideo || frameCount > 1;
  ThermalFrame? get currentFrame =>
      document.frames.isEmpty ? null : document.frames[_index].frame;
  Duration get position =>
      document.frames.isEmpty ? Duration.zero : document.frames[_index].elapsed;
  Duration get duration =>
      document.frames.isEmpty ? Duration.zero : document.frames.last.elapsed;

  void setSpeed(double value) {
    _speed = value.clamp(0.25, 4);
    if (_playing) _scheduleNext();
    notifyListeners();
  }

  void setLoop(bool value) {
    _loop = value;
    notifyListeners();
  }

  void seekToFrame(int index) {
    if (document.frames.isEmpty) return;
    _index = index.clamp(0, document.frames.length - 1);
    if (_playing) _scheduleNext();
    notifyListeners();
  }

  void stepForward() {
    if (document.frames.isEmpty) return;
    if (_index < document.frames.length - 1) {
      _index += 1;
    } else if (_loop) {
      _index = 0;
    } else {
      pause();
      return;
    }
    notifyListeners();
  }

  void stepBackward() {
    if (document.frames.isEmpty) return;
    _index = math.max(0, _index - 1);
    if (_playing) _scheduleNext();
    notifyListeners();
  }

  void play() {
    if (!isVideo || document.frames.isEmpty) return;
    if (_index >= document.frames.length - 1) {
      _index = 0;
    }
    _playing = true;
    _scheduleNext();
    notifyListeners();
  }

  void pause() {
    _playing = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void togglePlay() {
    if (_playing) {
      pause();
    } else {
      play();
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!_playing || document.frames.length < 2) return;
    if (_index >= document.frames.length - 1) {
      if (!_loop) {
        pause();
        return;
      }
      _timer = Timer(Duration.zero, stepForward);
      return;
    }
    final current = document.frames[_index].elapsed;
    final next = document.frames[_index + 1].elapsed;
    final delta = next - current;
    final micros = math.max(1, (delta.inMicroseconds / _speed).round());
    _timer = Timer(Duration(microseconds: micros), () {
      stepForward();
      if (_playing) _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
