import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const umekoIrRepositoryUrl = 'https://github.com/iamtwz/umeko-ir';
const _latestReleaseUrl =
    'https://api.github.com/repos/iamtwz/umeko-ir/releases/latest';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.name,
    required this.htmlUrl,
  });

  final String version;
  final String name;
  final Uri htmlUrl;
}

Future<UpdateInfo?> checkForUpdate({
  required String currentVersion,
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final httpClient = client ?? http.Client();
  final closeClient = client == null;
  try {
    final http.Response response;
    try {
      response = await httpClient
          .get(
            Uri.parse(_latestReleaseUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Umeko-IR',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    }
    if (response.statusCode != 200) return null;

    final Object? payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (payload is! Map<String, Object?>) return null;
    if (payload['draft'] == true || payload['prerelease'] == true) return null;

    final tagName = payload['tag_name'];
    final htmlUrl = payload['html_url'];
    if (tagName is! String || htmlUrl is! String) return null;
    if (!isNewerReleaseVersion(tagName, currentVersion)) return null;

    return UpdateInfo(
      version: tagName,
      name: payload['name'] is String ? payload['name'] as String : tagName,
      htmlUrl: Uri.parse(htmlUrl),
    );
  } finally {
    if (closeClient) httpClient.close();
  }
}

bool isNewerReleaseVersion(String releaseVersion, String currentVersion) {
  final release = _SemanticVersion.tryParse(releaseVersion);
  final current = _SemanticVersion.tryParse(currentVersion);
  if (release == null || current == null) return false;
  return release.compareTo(current) > 0;
}

class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static _SemanticVersion? tryParse(String value) {
    final normalized = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    final parts = normalized.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null) return null;
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return _SemanticVersion(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(_SemanticVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) return majorCompare;
    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) return minorCompare;
    return patch.compareTo(other.patch);
  }
}
