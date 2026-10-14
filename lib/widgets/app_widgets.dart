import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// 화면 맨 위: 앱 로고와 이름, 오른쪽에 메뉴(☰) 버튼
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradientDiagonal,
              ),
              padding: const EdgeInsets.all(3),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'DU-WHO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          AnimatedIconButton(
            key: const Key('menu-button'),
            icon: Icons.menu_rounded,
            color: text,
            size: 28,
            outlined: true,
            tooltip: '메뉴',
            onTap: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
    );
  }
}

// 누르는 동안 살짝 작아지는 아이콘 버튼
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  /// true면 윤곽선 있는 둥근 네모 버튼(터치 영역이 눈에 보인다).
  final bool outlined;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
    this.outlined = false,
    this.tooltip,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.outlined
            ? Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border(context),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: widget.size,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: widget.size,
                ),
              ),
      ),
    );
    final tip = widget.tooltip;
    return tip == null ? child : Tooltip(message: tip, child: child);
  }
}

// 화면 위쪽의 큰 제목. 설명 문구와 함께 스크롤하지 않고 상단바 아래에 고정한다
class HeroTitle extends StatelessWidget {
  final String text;
  const HeroTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.text(context),
        letterSpacing: -0.5,
        height: 1.35,
      ),
    );
  }
}

// 제목 아래 설명 문구
class HeroSubtitle extends StatelessWidget {
  final String text;
  const HeroSubtitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.sub(context),
        height: 1.5,
      ),
    );
  }
}

// 목록 위의 작은 구역 제목. 오른쪽에 개수·버튼을 붙일 수 있다
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.count, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            GradientPill('$count'),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

// 브랜드 그라데이션 위의 흰 글자 알약(개수 표시 등)
class GradientPill extends StatelessWidget {
  final String text;
  const GradientPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// 그라데이션 배경의 둥근 아이콘 상자
class GradientIconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final double radius;
  const GradientIconBox(
    this.icon, {
    super.key,
    this.size = 36,
    this.iconSize = 18,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientDiagonal,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

// 흰 카드(테두리 + 둥근 모서리). 목록·설정 묶음에 쓴다
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// 빈 상태 카드(아이콘 + 제목 + 설명 + 선택 버튼)
class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: AppColors.accent(context)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.sub(context)),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

// 교직원 정보가 최신이 아닐 수 있다는 안내(제목 설명 아래 작은 글씨)
class DataNotice extends StatelessWidget {
  const DataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '(갱신 등 문제로 모든 정보가 일치하지 않을 수 있습니다.)',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.sub(context).withAlpha(170),
        height: 1.5,
      ),
    );
  }
}
