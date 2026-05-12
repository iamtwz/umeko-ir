import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/uir_format.dart';
import '../playback/uir_reader.dart';
import 'gallery_entry.dart';
import 'uir_manifest.dart';
import 'uir_repository_base.dart';

UirRepository createUirRepository() => IoUirRepository();

class IoUirRepository implements UirRepository {
  IoUirRepository({Directory? recordingsDirectory})
    : _recordingsDirectory = recordingsDirectory;

  final Directory? _recordingsDirectory;

  @override
  bool get isAvailable => true;

  @override
  Future<List<GalleryEntry>> listEntries() async {
    final directory = await _ensureRecordingsDirectory();
    final manifests = <UirManifest>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.uir')) continue;
      final manifest = await _readUirEntry(entity);
      if (manifest != null) manifests.add(manifest);
    }
    manifests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable([
      for (final manifest in manifests) manifest.toGalleryEntry(),
    ]);
  }

  @override
  Future<GalleryEntry> saveBytes({
    required Uint8List bytes,
    required String name,
  }) async {
    final directory = await _ensureRecordingsDirectory();
    final document = const UirReader().read(bytes);
    late String id;
    late String filename;
    late File dataFile;
    do {
      id = _newId(document.header.createdAt);
      filename = '$id.uir';
      dataFile = File(p.join(directory.path, filename));
    } while (await dataFile.exists());
    final tempFile = File('${dataFile.path}.tmp');
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      await tempFile.rename(dataFile.path);
    } catch (e) {
      // Best-effort cleanup so failed saves do not litter the directory.
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      throw UirRepositoryIoException('Failed to save UIR recording: $e');
    }

    final manifest = UirManifest.fromDocument(
      id: id,
      filename: filename,
      name: _cleanName(name),
      sizeBytes: bytes.length,
      document: document,
    );
    return manifest.toGalleryEntry();
  }

  @override
  Future<Uint8List> readBytes(String id) async {
    final directory = await _ensureRecordingsDirectory();
    final file = File(p.join(directory.path, '${_checkedId(id)}.uir'));
    if (!await file.exists()) {
      throw UirRepositoryException('UIR recording not found: $id');
    }
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw UirRepositoryIoException(
        'Failed to read UIR recording $id: ${e.message}',
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    final directory = await _ensureRecordingsDirectory();
    try {
      await _deleteIfExists(
        File(p.join(directory.path, '${_checkedId(id)}.uir')),
      );
    } on FileSystemException catch (e) {
      throw UirRepositoryIoException(
        'Failed to delete UIR recording $id: ${e.message}',
      );
    }
  }

  Future<Directory> _ensureRecordingsDirectory() async {
    final directory =
        _recordingsDirectory ?? await _defaultRecordingsDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _defaultRecordingsDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'recordings'));
  }

  Future<UirManifest?> _readUirEntry(File file) async {
    final Uint8List bytes;
    try {
      if (!await file.exists()) return null;
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      // I/O failures (permissions, device errors) should be observable even
      // though we still want the rest of the gallery to render.
      debugPrint('uir_repository: skipping ${file.path} due to I/O error: $e');
      return null;
    }
    final filename = p.basename(file.path);
    final id = filename.endsWith('.uir')
        ? filename.substring(0, filename.length - 4)
        : filename;
    if (!_idPattern.hasMatch(id)) return null;
    try {
      final document = const UirReader().read(bytes);
      return UirManifest.fromDocument(
        id: id,
        filename: filename,
        name: _nameFromDocument(document, id),
        sizeBytes: bytes.length,
        document: document,
      );
    } on FormatException catch (e) {
      debugPrint('uir_repository: ${file.path} is corrupted: $e');
      return null;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _newId(DateTime createdAt) {
    final micros = createdAt.toUtc().microsecondsSinceEpoch;
    final suffix = _idRandom.nextInt(0xfffff).toRadixString(16).padLeft(5, '0');
    return 'uir_${micros}_$suffix';
  }

  String _cleanName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Untitled recording' : trimmed;
  }

  String _nameFromDocument(UirDocument document, String fallback) {
    final name = document.metadata['name'];
    if (name is String && name.trim().isNotEmpty) return _cleanName(name);
    return fallback;
  }

  String _checkedId(String id) {
    if (!_idPattern.hasMatch(id)) {
      throw UirRepositoryException('Invalid UIR recording id: $id');
    }
    return id;
  }
}

final _idPattern = RegExp(r'^[A-Za-z0-9_]+$');
final _idRandom = math.Random();
