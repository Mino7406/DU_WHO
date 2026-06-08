import 'dart:convert';
import 'package:http/http.dart' as http;

const _kCurrentVersion = '1.0.0';
const _kRepo           = 'Mino7406/DU_WHO';

class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    this.apkUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  UpdateService._();

  // 최신 릴리즈를 조회하여 현재 버전보다 새로운 경우 UpdateInfo 반환, 아니면 null
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final resp = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/$_kRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String?)?.trim() ?? '';
      final latestVersion = rawTag.startsWith('v')
          ? rawTag.substring(1)
          : rawTag;

      if (latestVersion.isEmpty) return null;
      if (!_isNewer(latestVersion, _kCurrentVersion)) return null;

      final releaseUrl = (data['html_url'] as String?) ?? '';
      final assets = data['assets'] as List<dynamic>?;
      String? apkUrl;
      if (assets != null) {
        for (final a in assets) {
          final name = (a['name'] as String?) ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String?;
            break;
          }
        }
      }

      final notes = data['body'] as String?;
      final shortNotes = _trimNotes(notes);

      return UpdateInfo(
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        apkUrl: apkUrl,
        releaseNotes: shortNotes,
      );
    } catch (_) {
      return null;
    }
  }

  // major.minor.patch 비교 – latest > current 이면 true
  static bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(
        3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }

  static String? _trimNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    const maxLen = 200;
    final trimmed = notes.trim();
    return trimmed.length > maxLen
        ? '${trimmed.substring(0, maxLen)}…'
        : trimmed;
  }

  static String get currentVersion => _kCurrentVersion;
}
