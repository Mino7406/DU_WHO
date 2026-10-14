import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../staff_model.dart';
import '../theme/app_theme.dart';
import 'staff_tile.dart';

/// 질문 하나와 그 답변. [answer]가 null 이면 답을 기다리는 중
class AiExchange {
  final String question;
  AiAnswer? answer;
  AiExchange(this.question);
}

/// 홈 화면에 나오는 AI 질문·답변 한 쌍. 답변 아래에 근거 교직원(최대 3명)을 바로 보여준다.
class AiExchangeView extends StatelessWidget {
  final AiExchange exchange;

  const AiExchangeView({super.key, required this.exchange});

  @override
  Widget build(BuildContext context) {
    final answer = exchange.answer;
    final related = answer == null ? const <Staff>[] : answer.staff.take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UserBubble(exchange.question),
        const SizedBox(height: 10),
        _BotBubble(answer == null ? null : _answerText(answer)),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              children: [
                for (final s in related) ...[
                  StaffTile(staff: s, compact: true),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 서버를 못 써서 만든 안내문은 아래에 교직원 카드가 따로 나오므로 이유만 보여준다
  static String _answerText(AiAnswer a) {
    if (a.fromAi || a.staff.isEmpty) return a.text;
    return '${a.text.split('\n\n').first}\n\n대신 교직원 DB에서 찾은 결과입니다.';
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradientDiagonal,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  /// null 이면 입력 중 표시(점 세 개)
  final String? text;
  const _BotBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradientDiagonal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: text == null
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedDot(delay: 0),
                      SizedBox(width: 5),
                      _AnimatedDot(delay: 200),
                      SizedBox(width: 5),
                      _AnimatedDot(delay: 400),
                    ],
                  )
                : SelectableText(
                    text!,
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _anim = Tween<double>(
    begin: 0.3,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.accent(context),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
