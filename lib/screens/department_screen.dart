import 'package:flutter/material.dart';

import '../staff_model.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'find_tab.dart' show staffSliver;

/// 한 부서의 교직원 목록. 부서 탭이나 상세 시트의 "같은 부서 보기"에서 연다.
/// 교내전화가 있는 사람을 먼저 보여준다(부서에 전화할 때 바로 걸 수 있게).
class DepartmentScreen extends StatelessWidget {
  final String department;
  const DepartmentScreen({super.key, required this.department});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(department, overflow: TextOverflow.ellipsis),
      ),
      body: ListenableBuilder(
        listenable: AppData.instance,
        builder: (context, _) {
          final members = [
            ...AppData.instance.departments
                .where((d) => d.name == department)
                .expand((d) => d.members),
          ];
          bool hasTel(Staff s) => s.tel.isNotEmpty && s.tel != '0000';
          members.sort((a, b) {
            final t = (hasTel(b) ? 1 : 0) - (hasTel(a) ? 1 : 0);
            return t != 0 ? t : a.name.compareTo(b.name);
          });
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const GradientIconBox(Icons.apartment_rounded),
                      const SizedBox(width: 10),
                      Text(
                        '소속 교직원',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GradientPill('${members.length}'),
                    ],
                  ),
                ),
              ),
              staffSliver(members, showDepartmentLink: false),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}
