import 'dart:typed_data';

import 'gallery_entry.dart';

abstract interface class UirRepository {
  bool get isAvailable;

  Future<List<GalleryEntry>> listEntries();

  Future<GalleryEntry> saveBytes({
    required Uint8List bytes,
    required String name,
  });

  Future<Uint8List> readBytes(String id);

  Future<void> delete(String id);
}

class UirRepositoryException implements Exception {
  const UirRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
