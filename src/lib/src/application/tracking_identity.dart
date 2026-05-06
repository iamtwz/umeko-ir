import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

const anonymousUserIdPreferenceKey = 'app.anonymousUserId';
const legacySentryAnonymousUserIdPreferenceKey = 'app.sentryAnonymousUserId';

Future<String> loadOrCreateAnonymousUserId() async {
  final preferences = SharedPreferencesAsync();
  final existing = await preferences.getString(anonymousUserIdPreferenceKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final legacy = await preferences.getString(
    legacySentryAnonymousUserIdPreferenceKey,
  );
  if (legacy != null && legacy.isNotEmpty) {
    await preferences.setString(anonymousUserIdPreferenceKey, legacy);
    return legacy;
  }

  final created = _createAnonymousUserId();
  await preferences.setString(anonymousUserIdPreferenceKey, created);
  return created;
}

String _createAnonymousUserId() {
  final random = Random.secure();
  final bytes = Uint8List(16);
  for (var index = 0; index < bytes.length; index += 1) {
    bytes[index] = random.nextInt(256);
  }
  return 'anon_${base64UrlEncode(bytes).replaceAll('=', '')}';
}
