import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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
    final id = _newId(document.header.createdAt);
    final filename = '$id.uir';
    final dataFile = File(_join(directory.path, filename));
    final tempFile = File('${dataFile.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    await tempFile.rename(dataFile.path);

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
    final file = File(_join(directory.path, '$id.uir'));
    if (!await file.exists()) {
      throw UirRepositoryException('UIR recording not found: $id');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String id) async {
    final directory = await _ensureRecordingsDirectory();
    await _deleteIfExists(File(_join(directory.path, '$id.uir')));
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
    final documents = await getApplicationDocumentsDirectory();
    return Directory(_join(documents.path, 'Umeko IR', 'recordings'));
  }

  Future<UirManifest?> _readUirEntry(File file) async {
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final filename = _basename(file.path);
      final id = filename.endsWith('.uir')
          ? filename.substring(0, filename.length - 4)
          : filename;
      final document = const UirReader().read(bytes);
      return UirManifest.fromDocument(
        id: id,
        filename: filename,
        name: _nameFromDocument(document, id),
        sizeBytes: bytes.length,
        document: document,
      );
    } catch (_) {
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
    final suffix = math.Random()
        .nextInt(0xfffff)
        .toRadixString(16)
        .padLeft(5, '0');
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

  String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _join(String part1, String part2, [String? part3]) {
    final separator = Platform.pathSeparator;
    String joinTwo(String left, String right) {
      if (left.endsWith(separator)) return '$left$right';
      return '$left$separator$right';
    }

    final joined = joinTwo(part1, part2);
    return part3 == null ? joined : joinTwo(joined, part3);
  }
}
