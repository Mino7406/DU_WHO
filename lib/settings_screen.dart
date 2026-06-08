import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _currentMode = themeNotifier.value;
  bool _isCheckingUpdate = false;

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _currentMode = mode);
    await saveThemeMode(mode);
  }

  Future<void> _manualCheckUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    final info = await UpdateService.checkForUpdate();

    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('최신 버전을 사용 중입니다.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('업데이트 알림',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새 버전 v${info.latestVersion}이 출시되었습니다.',
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            if (info.releaseNotes != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  info.releaseNotes!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('나중에',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse(info.apkUrl ?? info.releaseUrl);
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            child: const Text('지금 업데이트'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('앱 설정')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _sectionHeader(context, '테마'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                _themeOption(
                  context,
                  icon: Icons.brightness_auto_rounded,
                  label: '시스템 기본값',
                  subtitle: '기기 설정에 따라 자동 전환',
                  mode: ThemeMode.system,
                ),
                Divider(height: 1, indent: 56, endIndent: 16, color: cs.outlineVariant),
                _themeOption(
                  context,
                  icon: Icons.light_mode_rounded,
                  label: '라이트 모드',
                  subtitle: '항상 밝은 테마 사용',
                  mode: ThemeMode.light,
                ),
                Divider(height: 1, indent: 56, endIndent: 16, color: cs.outlineVariant),
                _themeOption(
                  context,
                  icon: Icons.dark_mode_rounded,
                  label: '다크 모드',
                  subtitle: '항상 어두운 테마 사용',
                  mode: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, '앱 정보'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                _infoRow(context, '앱 이름', 'DU-WHO'),
                Divider(height: 1, indent: 56, endIndent: 16, color: cs.outlineVariant),
                _versionRow(context),
                Divider(height: 1, indent: 56, endIndent: 16, color: cs.outlineVariant),
                _infoRow(context, '제공', '대구대학교'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required ThemeMode mode,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _currentMode == mode;

    return InkWell(
      onTap: () => _setTheme(mode),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? cs.primaryContainer : cs.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? kPrimary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: kPrimary, size: 22)
            else
              Icon(Icons.circle_outlined, color: cs.outlineVariant, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _versionRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAndroid = Platform.isAndroid;

    return InkWell(
      onTap: isAndroid ? _manualCheckUpdate : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(
                '버전',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              UpdateService.currentVersion,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            if (isAndroid) ...[
              const Spacer(),
              _isCheckingUpdate
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimary),
                    )
                  : Text(
                      '업데이트 확인',
                      style: TextStyle(
                        fontSize: 12,
                        color: kPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
