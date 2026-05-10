import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/thermal_controller.dart';
import '../core/thermal_frame.dart';
import '../storage/gallery_entry.dart';
import '../storage/uir_repository.dart';
import 'uir_writer.dart';

final uirRepositoryProvider = Provider<UirRepository>((ref) {
  return createUirRepository();
});

final localGalleryProvider = FutureProvider<List<GalleryEntry>>((ref) {
  ref.watch(
    recorderControllerProvider.select((state) => state.lastSavedEntry?.id),
  );
  return ref.watch(uirRepositoryProvider).listEntries();
});

final recorderControllerProvider =
    NotifierProvider<RecorderController, RecorderState>(RecorderController.new);

enum RecorderStatus { idle, recording, finalizing, error }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.frameCount = 0,
    this.lastSavedEntry,
    this.error,
  });

  final RecorderStatus status;
  final DateTime? startedAt;
  final Duration elapsed;
  final int frameCount;
  final GalleryEntry? lastSavedEntry;
  final String? error;

  bool get isRecording => status == RecorderStatus.recording;

  RecorderState copyWith({
    RecorderStatus? status,
    DateTime? startedAt,
    Duration? elapsed,
    int? frameCount,
    GalleryEntry? lastSavedEntry,
    String? error,
    bool clearStartedAt = false,
    bool clearLastSavedEntry = false,
    bool clearError = false,
  }) {
    return RecorderState(
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      elapsed: elapsed ?? this.elapsed,
      frameCount: frameCount ?? this.frameCount,
      lastSavedEntry: clearLastSavedEntry
          ? null
          : lastSavedEntry ?? this.lastSavedEntry,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class RecorderController extends Notifier<RecorderState> {
  UirByteWriter? _writer;
  StreamSubscription<ThermalFrame>? _frameSubscription;
  Stopwatch? _stopwatch;
  Timer? _elapsedTimer;

  @override
  RecorderState build() {
    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _frameSubscription?.cancel();
    });
    return const RecorderState();
  }

  Future<GalleryEntry?> captureSnapshot({String? name}) async {
    final frame = ref.read(thermalControllerProvider).currentFrame;
    if (frame == null) {
      state = state.copyWith(
        status: RecorderStatus.error,
        error: 'No thermal frame is available to capture.',
      );
      return null;
    }
    state = state.copyWith(
      status: RecorderStatus.finalizing,
      clearError: true,
      clearLastSavedEntry: true,
    );
    try {
      final writer = UirByteWriter(
        width: frame.width,
        height: frame.height,
        sensorType: frame.sensorType,
        createdAt: frame.timestamp,
      )..writeFrame(frame, elapsed: Duration.zero);
      final entry = await ref
          .read(uirRepositoryProvider)
          .saveBytes(
            bytes: writer.finish(),
            name: name ?? _snapshotName(frame),
          );
      state = RecorderState(lastSavedEntry: entry);
      return entry;
    } catch (error) {
      state = RecorderState(
        status: RecorderStatus.error,
        error: error.toString(),
      );
      return null;
    }
  }

  Future<void> startRecording({String? name}) async {
    if (state.isRecording) return;
    final frame = ref.read(thermalControllerProvider).currentFrame;
    if (frame == null) {
      state = state.copyWith(
        status: RecorderStatus.error,
        error: 'No thermal frame is available to start recording.',
      );
      return;
    }

    await _frameSubscription?.cancel();
    _stopwatch = Stopwatch()..start();
    _writer = UirByteWriter(
      width: frame.width,
      height: frame.height,
      sensorType: frame.sensorType,
      createdAt: frame.timestamp,
      isVideo: true,
    );
    _writeFrame(frame);
    _frameSubscription = ref
        .read(thermalControllerProvider.notifier)
        .frameStream
        .listen(_writeFrame, onError: _fail);
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final stopwatch = _stopwatch;
      if (stopwatch == null || !state.isRecording) return;
      state = state.copyWith(elapsed: stopwatch.elapsed);
    });
    state = RecorderState(
      status: RecorderStatus.recording,
      startedAt: frame.timestamp,
      elapsed: Duration.zero,
      frameCount: 1,
    );
  }

  Future<GalleryEntry?> stopRecording({String? name}) async {
    if (!state.isRecording || _writer == null) return null;
    state = state.copyWith(status: RecorderStatus.finalizing);
    _elapsedTimer?.cancel();
    _stopwatch?.stop();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    final writer = _writer;
    _writer = null;
    try {
      final entry = await ref
          .read(uirRepositoryProvider)
          .saveBytes(bytes: writer!.finish(), name: name ?? _recordingName());
      state = RecorderState(lastSavedEntry: entry);
      return entry;
    } catch (error) {
      state = RecorderState(
        status: RecorderStatus.error,
        error: error.toString(),
      );
      return null;
    } finally {
      _stopwatch = null;
    }
  }

  Future<void> cancelRecording() async {
    _elapsedTimer?.cancel();
    _stopwatch?.stop();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    _writer = null;
    _stopwatch = null;
    state = const RecorderState();
  }

  void clearError() {
    state = state.copyWith(status: RecorderStatus.idle, clearError: true);
  }

  void _writeFrame(ThermalFrame frame) {
    final writer = _writer;
    final stopwatch = _stopwatch;
    if (writer == null || stopwatch == null) return;
    writer.writeFrame(frame, elapsed: stopwatch.elapsed);
    state = state.copyWith(
      frameCount: writer.frameCount,
      elapsed: stopwatch.elapsed,
    );
  }

  void _fail(Object error) {
    _elapsedTimer?.cancel();
    _stopwatch?.stop();
    state = RecorderState(
      status: RecorderStatus.error,
      frameCount: state.frameCount,
      elapsed: state.elapsed,
      error: error.toString(),
    );
  }

  String _snapshotName(ThermalFrame frame) {
    return 'Snapshot ${frame.timestamp.toLocal().toIso8601String()}';
  }

  String _recordingName() {
    final startedAt = state.startedAt ?? DateTime.now();
    return 'Recording ${startedAt.toLocal().toIso8601String()}';
  }
}
