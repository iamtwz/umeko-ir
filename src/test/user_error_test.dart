import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/application/user_error.dart';
import 'package:umeko_ir_flutter/src/export/thermal_export.dart';
import 'package:umeko_ir_flutter/src/storage/uir_repository_base.dart';

void main() {
  test('returns empty string for null', () {
    expect(formatUserFacingError(null), '');
  });

  test('strips FormatException prefix', () {
    expect(
      formatUserFacingError(const FormatException('UIR file is too short')),
      'UIR file is too short',
    );
  });

  test('strips TimeoutException prefix', () {
    expect(
      formatUserFacingError(TimeoutException('Serial command "ls" timed out')),
      'Serial command "ls" timed out',
    );
  });

  test('unwraps UirRepositoryException to its message', () {
    expect(
      formatUserFacingError(const UirRepositoryIoException('Disk is full')),
      'Disk is full',
    );
  });

  test('returns a friendly message for ThermalExportCancelled', () {
    expect(
      formatUserFacingError(const ThermalExportCancelled()),
      'Export cancelled.',
    );
  });

  test('keeps only the first line', () {
    expect(formatUserFacingError('boom\nframe: file.dart:42\n...'), 'boom');
  });

  test('handles FileSystemException prefix', () {
    expect(
      formatUserFacingError(const FileSystemException('permission denied')),
      startsWith('permission denied'),
    );
  });

  test('preserves arbitrary strings without known prefix', () {
    expect(formatUserFacingError('plain text'), 'plain text');
  });
}
