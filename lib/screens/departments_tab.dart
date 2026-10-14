import 'package:flutter/material.dart';

import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../utils/staff_search.dart';
import '../widgets/app_widgets.dart';
import '../widgets/staff_tile.dart';
import 'department_screen.dart';

/// 부서 탭: 부서 목록(인원 수)을 이름으로 거르고, 누르면 그 부서 사람들을 본다.
/// "○○과 전화번호" 처럼 부서 단위로 찾을 때 가장 빠른 길.
class DepartmentsTab extends StatefulWidget {
  const DepartmentsTab({super.key});

  @override
  State<DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<DepartmentsTab> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<DepartmentInfo> _filtered(List<DepartmentInfo> all) {
    final q = _filter.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    final chosung = isChoseongQuery(q);
    return [
      for (final d in all)
        if (chosung
            ? toChoseong(d.name).contains(q.replaceAll(' ', ''))
            : d.name.toLowerCase().contains(q))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) {
        final all = AppData.instance.departments;
        final list = _filtered(all);
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroTitle('부서별로 \n찾아볼까요?'),
                    const SizedBox(height: 6),
                    HeroSubtitle('${all.length}개 부서 · 부서를 누르면 소속 교직원이 나와요.'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _filter,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '부서 이름 (초성 가능)',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.accent(context),
                    ),
                    suffixIcon: _filter.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(_filter.clear),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: EmptyCard(
                    icon: Icons.search_off_rounded,
                    title: '해당하는 부서가 없습니다',
                    subtitle: '찾기 탭에서 업무 키워드로 검색해 보세요',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _DepartmentTile(info: list[i], highlight: _filter.text),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _DepartmentTile extends StatelessWidget {
  final DepartmentInfo info;
  final String highlight;
  const _DepartmentTile({required this.info, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DepartmentScreen(department: info.name),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.apartment_rounded, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HighlightText(
                  info.name,
                  query: highlight,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              Text(
                '${info.members.length}명',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub(context),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.border(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
