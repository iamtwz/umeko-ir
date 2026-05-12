import '../export/thermal_export.dart' show ThermalExportCancelled;
import '../storage/uir_repository.dart' show UirRepositoryException;

/// Strip Dart exception boilerplate from [error]'s string form so it reads as
/// a single short line for end users.
///
/// - Recognized domain exceptions (export cancelled, UIR repository) get a
///   clean message path.
/// - Generic `toString()` output is stripped of common `<Type>: ` prefixes
///   ('FormatException: ...', 'TimeoutException: ...', ...) because those surface
///   from framework / SDK code and add no value to the user.
/// - Only the first line is returned; stack traces / cause chains belong in
///   logs, not UI.
String formatUserFacingError(Object? error) {
  if (error == null) return '';
  if (error is ThermalExportCancelled) return 'Export cancelled.';
  var text = error is UirRepositoryException ? error.message : error.toString();
  for (final prefix in _exceptionPrefixes) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
      break;
    }
  }
  final newline = text.indexOf('\n');
  if (newline != -1) text = text.substring(0, newline);
  return text.trim();
}

const _exceptionPrefixes = <String>[
  'FormatException: ',
  'TimeoutException: ',
  'StateError: ',
  'Exception: ',
  '_Exception: ',
  'HttpException: ',
  'SocketException: ',
  'FileSystemException: ',
];
