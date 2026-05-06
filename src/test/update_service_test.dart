import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:umeko_ir_flutter/src/application/update_service.dart';

void main() {
  group('isNewerReleaseVersion', () {
    test('detects newer semantic releases', () {
      expect(isNewerReleaseVersion('v1.0.1', '1.0.0'), isTrue);
      expect(isNewerReleaseVersion('1.2.0', '1.1.9+12'), isTrue);
      expect(isNewerReleaseVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('ignores equal and older releases', () {
      expect(isNewerReleaseVersion('v1.0.0', '1.0.0+1'), isFalse);
      expect(isNewerReleaseVersion('1.0.0', '1.0.1'), isFalse);
      expect(isNewerReleaseVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('ignores unparsable release tags', () {
      expect(isNewerReleaseVersion('latest', '1.0.0'), isFalse);
      expect(isNewerReleaseVersion('v1.0.beta', '1.0.0'), isFalse);
    });
  });

  group('checkForUpdate', () {
    test('returns release info for newer stable release', () async {
      final update = await checkForUpdate(
        currentVersion: '1.0.0',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.1.0',
              'name': 'Umeko IR 1.1.0',
              'html_url':
                  'https://github.com/iamtwz/umeko-ir/releases/tag/v1.1.0',
              'draft': false,
              'prerelease': false,
            }),
            200,
          ),
        ),
      );

      expect(update, isNotNull);
      expect(update!.version, 'v1.1.0');
      expect(update.name, 'Umeko IR 1.1.0');
    });

    test('ignores prerelease releases', () async {
      final update = await checkForUpdate(
        currentVersion: '1.0.0',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.1.0-beta.1',
              'html_url':
                  'https://github.com/iamtwz/umeko-ir/releases/tag/v1.1.0-beta.1',
              'prerelease': true,
            }),
            200,
          ),
        ),
      );

      expect(update, isNull);
    });
  });
}
