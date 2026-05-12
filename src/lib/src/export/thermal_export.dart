import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recording/recorder_controller.dart';
import 'thermal_export_stub.dart' if (dart.library.io) 'thermal_export_io.dart';

export 'thermal_export_stub.dart' if (dart.library.io) 'thermal_export_io.dart';

/// Shared [ThermalExporter] bound to the default [UirRepository]. Callers
/// should read through this provider instead of constructing an exporter in
/// build methods - exporters have no per-call state, and recreating them on
/// every widget rebuild is pure churn.
final thermalExporterProvider = Provider<ThermalExporter>((ref) {
  return ThermalExporter(repository: ref.watch(uirRepositoryProvider));
});
