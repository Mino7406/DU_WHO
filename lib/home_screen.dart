import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth.dart';
import 'login_screen.dart';
import 'screens/departments_tab.dart';
import 'screens/favorites_tab.dart';
import 'screens/find_tab.dart';
import 'services/ai_chat_service.dart';
import 'services/update_service.dart';
import 'settings_screen.dart';
import 'state/app_data.dart';
import 'theme/app_theme.dart';
import 'widgets/app_feedback.dart';
import 'widgets/app_menu_drawer.dart';
import 'widgets/app_widgets.dart';

/// 앱의 뼈대: 상단바(☰ 메뉴) + 하단 탭 3개(찾기 · 부서 · 즐겨찾기).
/// 시작할 때 전화·알림 권한을 요청하고 새 버전을 확인한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('du_who/call_overlay');

  final _findKey = GlobalKey<FindTabState>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    AppData.instance.load();
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _requestCallPermissions(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  void _selectTab(int i) {
    // 찾기 탭을 다시 누르면 입력창으로 올라가 바로 입력할 수 있게
    if (i == _tab && i == 0) _findKey.currentState?.focusInput();
    setState(() => _tab = i);
  }

  // ─── 권한·업데이트·메뉴 동작 ─────────────────────────────────

  Future<void> _requestCallPermissions() async {
    // 공통: Notification 권한 (iOS는 CallKit 감지에 별도 권한 불필요)
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) await Permission.notification.request();

    if (!Platform.isAndroid) return;

    final phoneStatus = await Permission.phone.status;
    if (phoneStatus.isDenied) await Permission.phone.request();

    final hasCallLog =
        await _channel.invokeMethod<bool>('checkCallLogPermission') ?? true;
    if (!hasCallLog) {
      await _channel.invokeMethod('requestCallLogPermission');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (!mounted) return;
    await _channel.invokeMethod('requestBatteryExemption');
  }

  Future<void> _checkForUpdate({bool manual = false}) async {
    if (!Platform.isAndroid) return;
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    if (info == null) {
      if (manual) showAppToast(context, '최신 버전을 사용 중입니다');
      return;
    }
    final go = await showAppDialog(
      context,
      icon: Icons.system_update_rounded,
      title: '업데이트 알림',
      dismissible: false,
      confirmLabel: '지금 업데이트',
      cancelLabel: '나중에',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('새 버전 v${info.latestVersion}이 출시되었습니다.'),
          if (info.releaseNotes != null) ...[
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                info.releaseNotes!,
                style: TextStyle(fontSize: 12, color: AppColors.sub(context)),
              ),
            ),
          ],
        ],
      ),
    );
    if (!go) return;
    final url = Uri.parse(info.apkUrl ?? info.releaseUrl);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _logout() async {
    final ok = await showAppDialog(
      context,
      icon: Icons.logout_rounded,
      title: '로그아웃',
      content: const Text('정말 로그아웃 하시겠습니까?'),
      confirmLabel: '로그아웃',
      danger: true,
    );
    if (!ok) return;
    await AuthService.instance.clearSession();
    AuthService.instance.logout();
    // 이전 계정의 대화가 다음 계정으로 이어지지 않게
    AiChatService.instance.resetChat();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // iOS 전용: 걸려온 번호를 입력해 교직원 알림을 띄운다(iOS는 발신 번호를 자동으로 못 읽음)
  Future<void> _showPhoneLookupDialog() async {
    final controller = TextEditingController();
    final ok = await showAppDialog(
      context,
      icon: Icons.phone_in_talk_rounded,
      title: '전화번호 교직원 조회',
      confirmLabel: '조회',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('수신한 전화번호를 입력하면\n교직원 정보를 알림으로 알려드립니다.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '예) 053-850-0000',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
        ],
      ),
    );
    final number = controller.text.trim();
    controller.dispose();
    if (!ok || number.isEmpty) return;
    try {
      await _channel.invokeMethod('lookupNumber', {'number': number});
    } catch (_) {}
  }

  // ─── 화면 ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final find = _findKey.currentState;
    return Scaffold(
      endDrawer: AppMenuDrawer(
        sections: [
          (
            '바로가기',
            [
              MenuEntry(
                icon: Icons.search_rounded,
                label: '교직원 찾기',
                onTap: () => _selectTab(0),
              ),
              MenuEntry(
                icon: Icons.apartment_rounded,
                label: '부서별 보기',
                count: AppData.instance.departments.length,
                onTap: () => _selectTab(1),
              ),
              MenuEntry(
                icon: Icons.star_rounded,
                label: '즐겨찾기',
                count: AppData.instance.favorites.length,
                onTap: () => _selectTab(2),
              ),
              if (Platform.isIOS)
                MenuEntry(
                  icon: Icons.phone_in_talk_rounded,
                  label: '전화번호로 조회',
                  onTap: _showPhoneLookupDialog,
                ),
              if (find != null && find.hasConversation)
                MenuEntry(
                  icon: Icons.refresh_rounded,
                  label: 'AI 대화 지우기',
                  onTap: find.clearChat,
                ),
            ],
          ),
          (
            '앱',
            [
              if (Platform.isAndroid)
                MenuEntry(
                  icon: Icons.system_update_rounded,
                  label: '업데이트 확인',
                  onTap: () => _checkForUpdate(manual: true),
                ),
              MenuEntry(
                icon: Icons.settings_rounded,
                label: '설정',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              if (kLoginEnabled)
                MenuEntry(
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  danger: true,
                  onTap: _logout,
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            Expanded(
              // 탭을 오가도 입력·스크롤 위치가 남도록 IndexedStack 으로 모두 유지한다
              child: IndexedStack(
                index: _tab,
                children: [
                  FindTab(key: _findKey),
                  const DepartmentsTab(),
                  const FavoritesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(index: _tab, onSelect: _selectTab),
    );
  }
}

// 하단 탭 바. 선택된 탭은 브랜드 그라데이션 알약으로 표시한다
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _BottomNav({required this.index, required this.onSelect});

  static const _items = [
    (Icons.search_rounded, '찾기'),
    (Icons.apartment_rounded, '부서'),
    (Icons.star_rounded, '즐겨찾기'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = AppColors.sub(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : sub,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accent(context) : sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
