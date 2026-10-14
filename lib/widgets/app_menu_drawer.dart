import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 메뉴 한 줄. [count]가 있으면 오른쪽에 개수 알약을 붙인다.
class MenuEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool danger;
  const MenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.danger = false,
  });
}

/// 오른쪽에서 밀려 나오는 메뉴(알림메모와 같은 구성). 홈의 보조 기능을 모았다.
/// 항목을 누르면 메뉴를 닫고 동작을 실행한다.
class AppMenuDrawer extends StatelessWidget {
  final List<(String, List<MenuEntry>)> sections;
  const AppMenuDrawer({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text(context);
    final sub = AppColors.sub(context);
    final isDark = AppColors.isDark(context);

    Widget item(MenuEntry e) {
      final color = e.danger ? AppColors.danger : AppColors.accent(context);
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(context);
          e.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 36 : 24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(e.icon, size: 19, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: e.danger ? AppColors.danger : text,
                  ),
                ),
              ),
              if (e.count != null && e.count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${e.count}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Drawer(
      key: const Key('menu-drawer'),
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                '메뉴',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
            ),
            for (final (title, entries) in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sub,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              for (final e in entries) item(e),
            ],
          ],
        ),
      ),
    );
  }
}
