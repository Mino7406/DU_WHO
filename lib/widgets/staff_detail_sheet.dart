import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../auth.dart';
import '../screens/department_screen.dart';
import '../staff_model.dart';
import '../state/app_data.dart';
import '../state/favorites.dart';
import '../theme/app_theme.dart';
import '../utils/contact_launcher.dart';
import 'app_feedback.dart';
import 'app_widgets.dart';

/// 교직원 상세 바텀시트(모든 화면 공용). 신분에 따라 직위·휴대폰·위치 노출을 거른다.
/// 열면 "최근 본 교직원"에 기록한다. [showDepartmentLink]가 true 면 "같은 부서 보기"를 보여준다.
Future<void> showStaffDetailSheet(
  BuildContext context,
  Staff staff, {
  bool showDepartmentLink = true,
}) {
  AppData.instance.addRecent(staff);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StaffDetail(
      staff: staff,
      showDepartmentLink: showDepartmentLink,
      parentContext: context,
    ),
  );
}

class _StaffDetail extends StatelessWidget {
  final Staff staff;
  final bool showDepartmentLink;
  final BuildContext parentContext;
  const _StaffDetail({
    required this.staff,
    required this.showDepartmentLink,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final tel = staff.tel.isNotEmpty && staff.tel != '0000' ? staff.tel : '';
    final cell =
        auth.isStaff &&
            staff.cellTel.isNotEmpty &&
            staff.cellTel != '000-0000-0000'
        ? staff.cellTel
        : '';
    final location = auth.effectiveLocation(staff.location);
    final dept = staff.department.trim();
    final colleagues = AppData.instance.colleaguesOf(staff).length;
    final text = AppColors.text(context);
    final sub = AppColors.sub(context);
    final initial = staff.name.isEmpty ? '?' : staff.name.characters.first;

    void copy(String label, String value) {
      Clipboard.setData(ClipboardData(text: value));
      Navigator.pop(context);
      showAppToast(parentContext, '$label 복사 완료');
    }

    void call(String number) {
      Navigator.pop(context);
      makePhoneCall(number);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.bgDark : AppColors.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── 머리: 아바타 · 이름 · 직위 · 부서 · ★
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradientDiagonal,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            staff.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: text,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (auth.isStaff && staff.title.isNotEmpty)
                            TitleChip(staff.title),
                        ],
                      ),
                      if (dept.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(dept, style: TextStyle(fontSize: 14, color: sub)),
                      ],
                    ],
                  ),
                ),
                if (staff.userId.isNotEmpty)
                  ListenableBuilder(
                    listenable: AppData.instance,
                    builder: (context, _) {
                      final fav = isFavorite(staff);
                      return IconButton(
                        icon: Icon(
                          fav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: fav ? Colors.amber : sub,
                          size: 30,
                        ),
                        tooltip: fav ? '즐겨찾기 해제' : '즐겨찾기 추가',
                        onPressed: () => AppData.instance.toggleFavorite(staff),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // ── 큰 동작 버튼: 교내전화 · 휴대폰 · 메일
            if (tel.isNotEmpty || cell.isNotEmpty || staff.email.isNotEmpty)
              Row(
                children: [
                  if (tel.isNotEmpty)
                    _ActionButton(
                      icon: Icons.call_rounded,
                      label: '교내전화',
                      primary: true,
                      onTap: () => call(tel),
                    ),
                  if (cell.isNotEmpty)
                    _ActionButton(
                      icon: Icons.smartphone_rounded,
                      label: '휴대폰',
                      primary: tel.isEmpty,
                      onTap: () => call(cell),
                    ),
                  if (staff.email.isNotEmpty)
                    _ActionButton(
                      icon: Icons.mail_rounded,
                      label: '메일',
                      onTap: () {
                        Navigator.pop(context);
                        sendEmail(staff.email);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 14),
            // ── 정보 카드 (길게 누르거나 복사 아이콘으로 복사)
            AppCard(
              child: Column(
                children: [
                  if (tel.isNotEmpty)
                    _InfoRow(
                      Icons.phone_rounded,
                      '교내전화',
                      tel,
                      onCopy: () => copy('교내전화', tel),
                    ),
                  if (cell.isNotEmpty)
                    _InfoRow(
                      Icons.smartphone_rounded,
                      '휴대폰',
                      cell,
                      onCopy: () => copy('휴대폰 번호', cell),
                    ),
                  if (staff.email.isNotEmpty)
                    _InfoRow(
                      Icons.mail_outline_rounded,
                      '이메일',
                      staff.email,
                      onCopy: () => copy('이메일', staff.email),
                    ),
                  if (location.isNotEmpty)
                    _InfoRow(Icons.location_on_outlined, '위치', location),
                  if (staff.chargeBusiness.isNotEmpty)
                    _InfoRow(
                      Icons.work_outline_rounded,
                      '담당업무',
                      staff.chargeBusiness,
                    ),
                  if (tel.isEmpty &&
                      cell.isEmpty &&
                      staff.email.isEmpty &&
                      location.isEmpty &&
                      staff.chargeBusiness.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '등록된 연락처가 없습니다',
                        style: TextStyle(color: sub),
                      ),
                    ),
                ],
              ),
            ),
            if (showDepartmentLink && dept.isNotEmpty && colleagues > 1) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => DepartmentScreen(department: dept),
                    ),
                  );
                },
                icon: const Icon(Icons.groups_rounded, size: 19),
                label: Text('$dept $colleagues명 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent(context),
                  backgroundColor: AppColors.surface(context),
                  side: BorderSide(
                    color: AppColors.border(context),
                    width: 1.3,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 직위 표시용 작은 칩(DU LIGHTGREEN 바탕)
class TitleChip extends StatelessWidget {
  final String title;
  const TitleChip(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lightGreen.withAlpha(
          AppColors.isDark(context) ? 50 : 80,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.isDark(context)
              ? AppColors.lightGreen
              : AppColors.black,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: primary ? AppColors.brandGradientDiagonal : null,
                color: primary ? null : AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: primary
                    ? null
                    : Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: primary ? Colors.white : AppColors.accent(context),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primary ? Colors.white : AppColors.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoRow(this.icon, this.label, this.value, {this.onCopy});

  @override
  Widget build(BuildContext context) {
    final sub = AppColors.sub(context);
    return InkWell(
      onLongPress: onCopy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: AppColors.accent(context)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 58,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text(context),
                  height: 1.4,
                ),
              ),
            ),
            if (onCopy != null)
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: sub),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
