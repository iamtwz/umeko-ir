import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

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
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final manifest = await _readManifest(entity);
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
    await _writeManifest(directory, manifest);
    return manifest.toGalleryEntry();
  }

  @override
  Future<Uint8List> readBytes(String id) async {
    final directory = await _ensureRecordingsDirectory();
    final manifest = await _readManifestById(directory, id);
    if (manifest == null) {
      throw UirRepositoryException('UIR recording not found: $id');
    }
    return File(_join(directory.path, manifest.filename)).readAsBytes();
  }

  @override
  Future<void> delete(String id) async {
    final directory = await _ensureRecordingsDirectory();
    final manifest = await _readManifestById(directory, id);
    if (manifest == null) return;
    await _deleteIfExists(File(_join(directory.path, manifest.filename)));
    await _deleteIfExists(File(_join(directory.path, '$id.json')));
    await _deleteIfExists(File(_join(directory.path, '$id.idx')));
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

  Future<void> _writeManifest(Directory directory, UirManifest manifest) async {
    final manifestFile = File(_join(directory.path, '${manifest.id}.json'));
    final tempFile = File('${manifestFile.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString(
      encoder.convert(manifest.toJson()),
      flush: true,
    );
    await tempFile.rename(manifestFile.path);
  }

  Future<UirManifest?> _readManifestById(Directory directory, String id) {
    return _readManifest(File(_join(directory.path, '$id.json')));
  }

  Future<UirManifest?> _readManifest(File file) async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      return UirManifest.fromJson(json);
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
