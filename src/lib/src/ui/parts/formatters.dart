// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _devicePhotoInfo(
  BuildContext context,
  DevicePhoto photo,
  TemperatureUnit unit,
) {
  final l10n = context.l10n;
  return [
    '${photo.width}x${photo.height}',
    l10n.photoKind,
    _temperatureRange(photo.tMin, photo.tMax, unit),
  ].join('  ');
}

String _galleryEntryInfo(
  BuildContext context,
  GalleryEntry entry,
  Duration? duration,
  TemperatureUnit unit,
) {
  final l10n = context.l10n;
  return [
    '${entry.width}x${entry.height}',
    entry.kind == GalleryKind.photo
        ? l10n.photoKind
        : l10n.framesMetric(entry.frameCount ?? 0),
    if (entry.kind == GalleryKind.video && duration != null)
      _formatDuration(duration),
    _temperatureRange(entry.tMin, entry.tMax, unit),
  ].join('  ');
}

String _temperatureRange(double min, double max, TemperatureUnit unit) {
  return unit.formatRange(min, max);
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

String _formatDateTime(DateTime value) {
  return value
      .toLocal()
      .toIso8601String()
      .replaceFirst('T', ' ')
      .split('.')
      .first;
}

String _devicePhotoFormatLabel(DevicePhotoFormat format) {
  return switch (format) {
    DevicePhotoFormat.uint16_32x32 => 'UInt16 32x32',
    DevicePhotoFormat.float32_32x24 => 'Float32 32x24',
    DevicePhotoFormat.float32_16x12 => 'Float32 16x12',
  };
}
