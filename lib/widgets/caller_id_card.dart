import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';

import '../services/caller_id_service.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';
import 'app_widgets.dart';

/// BETA: 걸려온 학교 번호 알림. 켜고 끄기, 필요한 권한 상태, 알림 미리보기.
/// 설정 앱에서 권한을 바꾸고 돌아오면 상태를 다시 읽는다.
class CallerIdBetaCard extends StatefulWidget {
  const CallerIdBetaCard({super.key});

  @override
  State<CallerIdBetaCard> createState() => _CallerIdBetaCardState();
}

class _CallerIdBetaCardState extends State<CallerIdBetaCard>
    with WidgetsBindingObserver {
  CallerIdStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await CallerIdService.status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _toggle(bool on) async {
    await CallerIdService.setEnabled(on);
    await _refresh();
    if (mounted) {
      showAppToast(context, on ? '학교 번호 알림을 켰습니다' : '학교 번호 알림을 껐습니다');
    }
  }

  // 빠진 권한을 요청하고, 다시 묻지 않음 상태면 설정 앱을 연다
  Future<void> _grant() async {
    setState(() => _busy = true);
    final results = await [Permission.phone, Permission.notification].request();
    const ch = MethodChannel('du_who/call_overlay');
    try {
      final hasCallLog = await ch.invokeMethod<bool>('checkCallLogPermission');
      if (hasCallLog == false) {
        await ch.invokeMethod('requestCallLogPermission');
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (_) {}
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    final blocked = results.values.any((s) => s.isPermanentlyDenied);
    if (blocked || !(_status?.ready ?? true)) {
      final open = await showAppDialog(
        context,
        icon: Icons.settings_rounded,
        title: '권한이 필요해요',
        content: const Text(
          '전화·통화기록·알림 권한을 허용해야 걸려온 학교 번호를 알려드릴 수 있어요.\n설정에서 직접 허용해 주세요.',
        ),
        confirmLabel: '설정 열기',
      );
      if (open) await openAppSettings();
    }
  }

  // 미리보기는 실제 교직원이 아닌 예시 정보(네이티브가 만듦)와 이 가상번호로 보여준다
  static const _virtualNumber = '053-850-0000';

  Future<void> _preview() async {
    final ok = await CallerIdService.preview(_virtualNumber);
    if (!mounted) return;
    showAppToast(
      context,
      ok ? '예시 알림을 보냈어요 (가상번호 $_virtualNumber)' : '미리보기를 보내지 못했습니다',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final text = AppColors.text(context);
    final sub = AppColors.sub(context);
    final isIOS = Platform.isIOS;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIconBox(
                Icons.phone_callback_rounded,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '걸려온 학교 번호 알림',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const _BetaBadge(),
                  ],
                ),
              ),
              if (s != null)
                Switch(
                  value: s.enabled,
                  activeTrackColor: AppColors.deepGreen,
                  onChanged: _toggle,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isIOS
                ? 'iOS는 발신 번호를 읽을 수 없어 전화가 오면 안내 알림만 보내요. 메뉴의 "전화번호로 조회"로 번호를 직접 확인할 수 있어요.'
                : '교직원 번호로 전화가 오면 이름·부서를 알림으로 알려드려요. 학교 번호가 아니면 알리지 않아요.',
            style: TextStyle(fontSize: 12.5, color: sub, height: 1.5),
          ),
          if (s == null) ...[
            const SizedBox(height: 8),
            Text(
              '이 기기에서는 사용할 수 없어요',
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
          ] else ...[
            if (s.supported) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip('전화', s.phone),
                  _StatusChip('통화기록', s.callLog),
                  _StatusChip('알림', s.notifications),
                  _StatusChip('배터리 예외', s.battery, optional: true),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: s.enabled ? _preview : null,
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      size: 17,
                    ),
                    label: const Text('알림 미리보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent(context),
                      side: BorderSide(
                        color: AppColors.border(context),
                        width: 1.3,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (s.supported && !s.ready) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _grant,
                      icon: const Icon(Icons.lock_open_rounded, size: 17),
                      label: const Text('권한 허용'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepGreen,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'BETA',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.black,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool ok;

  /// 없어도 동작은 하지만 있으면 더 안정적인 항목(배터리 최적화 예외)
  final bool optional;
  const _StatusChip(this.label, this.ok, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AppColors.accent(context)
        : (optional ? AppColors.sub(context) : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok
                ? Icons.check_circle_rounded
                : (optional
                      ? Icons.info_outline_rounded
                      : Icons.cancel_rounded),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            optional && !ok ? '$label 권장' : label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
