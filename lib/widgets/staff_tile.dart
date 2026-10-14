import 'package:flutter/material.dart';

import '../auth.dart';
import '../staff_model.dart';
import '../state/app_data.dart';
import '../state/favorites.dart';
import '../theme/app_theme.dart';
import '../utils/contact_launcher.dart';
import '../utils/staff_search.dart';
import 'staff_detail_sheet.dart';

/// 교직원 한 명을 보여주는 카드(검색 결과·즐겨찾기·최근·AI 근거·부서 목록 공용).
/// 이름 첫 글자 아바타 + 이름/직위 + 부서 + 전화, 오른쪽에 ★·전화 버튼.
/// 누르면 상세 시트, 전화 버튼은 바로 전화를 걸고 최근 본 교직원에 기록한다.
class StaffTile extends StatelessWidget {
  final Staff staff;

  /// 검색어. 이름·부서에서 걸린 부분을 강조한다
  final String highlight;

  /// true면 높이를 낮추고 전화번호 줄을 뺀다(AI 답변 아래 근거 목록)
  final bool compact;

  /// 부서 화면 안에서는 "같은 부서 보기"가 의미 없어 끈다
  final bool showDepartmentLink;

  const StaffTile({
    super.key,
    required this.staff,
    this.highlight = '',
    this.compact = false,
    this.showDepartmentLink = true,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final phone = auth.effectivePhone(staff.tel, staff.cellTel);
    final fav = isFavorite(staff);
    final text = AppColors.text(context);
    final sub = AppColors.sub(context);
    final accent = AppColors.accent(context);
    final initial = staff.name.isEmpty ? '?' : staff.name.characters.first;

    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => showStaffDetailSheet(
          context,
          staff,
          showDepartmentLink: showDepartmentLink,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            compact ? 9 : 12,
            8,
            compact ? 9 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 46,
                height: compact ? 38 : 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: HighlightText(
                            staff.name,
                            query: highlight,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: text,
                            ),
                          ),
                        ),
                        if (auth.isStaff && staff.title.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(child: TitleChip(staff.title)),
                        ],
                      ],
                    ),
                    if (staff.department.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      HighlightText(
                        staff.department,
                        query: highlight,
                        style: TextStyle(fontSize: 12.5, color: sub),
                      ),
                    ],
                    if (!compact && phone.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      HighlightText(
                        phone,
                        query: highlight,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: sub,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (staff.userId.isNotEmpty)
                IconButton(
                  icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? Colors.amber : AppColors.border(context),
                    size: 24,
                  ),
                  tooltip: fav ? '즐겨찾기 해제' : '즐겨찾기 추가',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => AppData.instance.toggleFavorite(staff),
                ),
              if (phone.isNotEmpty)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradientDiagonal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: '전화걸기',
                    onPressed: () {
                      AppData.instance.addRecent(staff);
                      makePhoneCall(phone);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 검색어가 걸린 부분을 브랜드 색 배경으로 강조하는 한 줄 글자
class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  const HighlightText(
    this.text, {
    super.key,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = matchRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final mark = style.copyWith(
      color: AppColors.accent(context),
      backgroundColor: AppColors.lightGreen.withAlpha(
        AppColors.isDark(context) ? 40 : 70,
      ),
    );
    final spans = <TextSpan>[];
    var pos = 0;
    for (final (start, end) in ranges) {
      if (start < pos) continue; // 겹치는 구간은 건너뛴다
      if (start > pos) spans.add(TextSpan(text: text.substring(pos, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: mark));
      pos = end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
