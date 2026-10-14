import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 화면 아래에 잠깐 뜨는 알림. 이전 알림은 바로 교체한다.
void showAppToast(BuildContext context, String msg, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}

/// 확인/취소 두 버튼 다이얼로그. 확인을 누르면 true.
/// [danger]면 확인 버튼이 빨간색(로그아웃·삭제 등).
Future<bool> showAppDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget content,
  required String confirmLabel,
  String cancelLabel = '취소',
  bool danger = false,
  bool dismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) {
      final sub = AppColors.sub(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppColors.surface(ctx),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: danger ? null : AppColors.brandGradientDiagonal,
                color: danger ? AppColors.danger : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(ctx),
                ),
              ),
            ),
          ],
        ),
        content: DefaultTextStyle.merge(
          style: TextStyle(fontSize: 14, color: AppColors.text(ctx)),
          child: content,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: sub,
              side: BorderSide(color: AppColors.border(ctx), width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.deepGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
