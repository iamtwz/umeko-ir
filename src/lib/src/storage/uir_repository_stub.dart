import 'dart:typed_data';

import 'gallery_entry.dart';
import 'uir_repository_base.dart';

UirRepository createUirRepository() => const UnsupportedUirRepository();

class UnsupportedUirRepository implements UirRepository {
  const UnsupportedUirRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<void> delete(String id) async {
    throw const UirRepositoryException(
      'Local UIR storage is not implemented on this platform yet.',
    );
  }

  @override
  Future<List<GalleryEntry>> listEntries() async {
    return const [];
  }

  @override
  Future<Uint8List> readBytes(String id) async {
    throw const UirRepositoryException(
      'Local UIR storage is not implemented on this platform yet.',
    );
  }

  @override
  Future<GalleryEntry> saveBytes({
    required Uint8List bytes,
    required String name,
  }) async {
    throw const UirRepositoryException(
      'Local UIR storage is not implemented on this platform yet.',
    );
  }
}
