import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdate {
  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri apkUrl;

  bool get isAvailable => _compareVersions(latestVersion, currentVersion) > 0;
}

Future<AppUpdate> checkForAppUpdate() async {
  final currentVersion = (await PackageInfo.fromPlatform()).version;
  final response = await http
      .get(
        Uri.parse(
          'https://api.github.com/repos/playertwo1/Command/releases/latest',
        ),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Command-Android',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw const FormatException('GitHub release lookup failed.');
  }

  final release = jsonDecode(response.body);
  if (release is! Map<String, dynamic>) {
    throw const FormatException('Invalid GitHub release response.');
  }
  final tag = release['tag_name'];
  final versionMatch = tag is String
      ? RegExp(r'^command-v(\d+\.\d+\.\d+)$').firstMatch(tag)
      : null;
  if (versionMatch == null) {
    throw const FormatException('Invalid Command release tag.');
  }

  final assets = release['assets'];
  if (assets is! List) {
    throw const FormatException('Command APK is missing from the release.');
  }
  Map<String, dynamic>? apk;
  for (final value in assets) {
    if (value is Map && value['name'] == 'Command.apk') {
      apk = Map<String, dynamic>.from(value);
      break;
    }
  }
  final rawUrl = apk?['browser_download_url'];
  final apkUrl = rawUrl is String ? Uri.tryParse(rawUrl) : null;
  if (apkUrl == null ||
      apkUrl.scheme != 'https' ||
      apkUrl.host != 'github.com' ||
      !apkUrl.path.startsWith('/playertwo1/Command/releases/download/') ||
      apkUrl.pathSegments.isEmpty ||
      apkUrl.pathSegments.last != 'Command.apk') {
    throw const FormatException('Invalid Command APK download URL.');
  }

  final latestVersion = versionMatch.group(1)!;
  _compareVersions(latestVersion, currentVersion);
  return AppUpdate(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    apkUrl: apkUrl,
  );
}

int _compareVersions(String left, String right) {
  final leftParts = _parseVersion(left);
  final rightParts = _parseVersion(right);
  for (var i = 0; i < leftParts.length; i++) {
    final comparison = leftParts[i].compareTo(rightParts[i]);
    if (comparison != 0) return comparison;
  }
  return 0;
}

List<int> _parseVersion(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
  if (match == null) {
    throw const FormatException('Unsupported app version.');
  }
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}
