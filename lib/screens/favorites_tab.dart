import 'package:flutter/material.dart';

import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'find_tab.dart' show staffSliver;

/// 즐겨찾기 탭: 자주 연락하는 사람(★)과 최근 본 교직원.
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final favorites = data.favorites;
        final recents = data.recents;
        return CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroTitle('자주 찾는 \n사람들'),
                    SizedBox(height: 6),
                    HeroSubtitle('★를 누른 교직원과 최근에 본 교직원이에요.'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  '즐겨찾기',
                  count: favorites.isEmpty ? null : favorites.length,
                ),
              ),
            ),
            if (!data.loaded)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (favorites.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: EmptyCard(
                    icon: Icons.star_outline_rounded,
                    title: '즐겨찾기가 없습니다',
                    subtitle: '교직원 카드나 상세 화면에서 ★를 눌러 추가하세요',
                  ),
                ),
              )
            else
              staffSliver(favorites),
            if (recents.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    '최근 본 교직원',
                    trailing: TextButton(
                      onPressed: data.clearRecents,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sub(context),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('지우기'),
                    ),
                  ),
                ),
              ),
              staffSliver(recents),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}
