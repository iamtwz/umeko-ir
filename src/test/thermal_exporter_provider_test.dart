import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/export/thermal_export.dart';
import 'package:umeko_ir_flutter/src/recording/recorder_controller.dart';
import 'package:umeko_ir_flutter/src/storage/gallery_entry.dart';
import 'package:umeko_ir_flutter/src/storage/uir_repository_base.dart';

void main() {
  test('thermalExporterProvider uses the bound UirRepository', () {
    final repository = _MemoryUirRepository();
    final container = ProviderContainer(
      overrides: [uirRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final exporter = container.read(thermalExporterProvider);
    expect(exporter.repository, same(repository));
  });

  test(
    'thermalExporterProvider returns identical instance on repeated reads',
    () {
      final repository = _MemoryUirRepository();
      final container = ProviderContainer(
        overrides: [uirRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final first = container.read(thermalExporterProvider);
      final second = container.read(thermalExporterProvider);
      expect(identical(first, second), isTrue);
    },
  );
}

class _MemoryUirRepository implements UirRepository {
  @override
  bool get isAvailable => true;

  @override
  Future<List<GalleryEntry>> listEntries() async => const [];

  @override
  Future<GalleryEntry> saveBytes({
    required Uint8List bytes,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readBytes(String id) async => Uint8List(0);

  @override
  Future<void> delete(String id) async {}
}
