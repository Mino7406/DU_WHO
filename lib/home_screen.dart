import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth.dart';
import 'chat_screen.dart';
import 'db/database_helper.dart';
import 'main.dart';
import 'search_screen.dart';
import 'services/update_service.dart';
import 'settings_screen.dart';
import 'staff_model.dart';
import 'state/favorites.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Staff> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestCallPermissions());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) return;
    final info = await UpdateService.checkForUpdate();
    if (!mounted || info == null) return;
    _showUpdateDialog(info);
  }

  void _showUpdateDialog(UpdateInfo info) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('업데이트 알림',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새 버전 v${info.latestVersion}이 출시되었습니다.',
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            if (info.releaseNotes != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  info.releaseNotes!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('나중에',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse(info.apkUrl ?? info.releaseUrl);
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            child: const Text('지금 업데이트'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCallPermissions() async {
    const ch = MethodChannel('du_who/call_overlay');

    final phoneStatus = await Permission.phone.status;
    if (phoneStatus.isDenied) await Permission.phone.request();

    final hasCallLog = await ch.invokeMethod<bool>('checkCallLogPermission') ?? true;
    if (!hasCallLog) {
      await ch.invokeMethod('requestCallLogPermission');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) await Permission.notification.request();

    if (!mounted) return;
    await ch.invokeMethod('requestBatteryExemption');
  }

  Future<void> _loadFavorites() async {
    final all = await DatabaseHelper.instance.getAllStaff();
    if (!mounted) return;
    setState(() {
      _favorites = all
          .where((s) => s.id != null && favoriteStaffIds.contains(s.id))
          .toList();
      _loading = false;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || cleaned == '0000') return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _toggleFavorite(Staff staff) async {
    final id = staff.id;
    if (id == null) return;
    await toggleFavorite(id);
    if (mounted) _loadFavorites();
  }

  void _showStaffDetails(BuildContext context, Staff staff) {
    final auth = AuthService.instance;
    final phone = auth.effectivePhone(staff.tel, staff.cellTel);
    final location = auth.effectiveLocation(staff.location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cs = Theme.of(ctx).colorScheme;
          final isFav = staff.id != null && favoriteStaffIds.contains(staff.id);
          return Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimary, Color(0xFF2A9D5C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface),
                          ),
                          // 직위: 교직원만 표시
                          if (auth.isStaff && staff.title.isNotEmpty)
                            Text(
                              staff.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: kPrimary,
                                  fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav ? Colors.amber : cs.onSurfaceVariant,
                        size: 28,
                      ),
                      tooltip: isFav ? '즐겨찾기 해제' : '즐겨찾기 추가',
                      onPressed: () async {
                        await _toggleFavorite(staff);
                        if (!ctx.mounted) return;
                        setSheetState(() {});
                        if (!favoriteStaffIds.contains(staff.id)) {
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: cs.outlineVariant),
                const SizedBox(height: 16),
                _detailRow(ctx, Icons.business_rounded, '부서', staff.department),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(ctx, Icons.location_on_rounded, '위치', location),
                ],
                if (staff.tel.isNotEmpty && staff.tel != '0000') ...[
                  const SizedBox(height: 12),
                  _detailRow(ctx, Icons.phone_rounded, '교내전화', staff.tel),
                ],
                // 휴대전화: 교직원만 표시
                if (auth.isStaff &&
                    staff.cellTel.isNotEmpty &&
                    staff.cellTel != '000-0000-0000') ...[
                  const SizedBox(height: 12),
                  _detailRow(ctx, Icons.smartphone_rounded, '휴대폰', staff.cellTel),
                ],
                if (staff.email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(ctx, Icons.email_rounded, '이메일', staff.email),
                ],
                if (staff.chargeBusiness.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(
                      ctx, Icons.work_rounded, '담당업무', staff.chargeBusiness),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (staff.email.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendEmail(staff.email);
                          },
                          icon: const Icon(Icons.email_rounded, size: 18),
                          label: const Text('메일보내기'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (staff.email.isNotEmpty && phone.isNotEmpty)
                      const SizedBox(width: 12),
                    if (phone.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _makePhoneCall(phone);
                          },
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('전화걸기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(
      BuildContext ctx, IconData icon, String label, String value) {
    final cs = Theme.of(ctx).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 13, color: cs.onSurface)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = AuthService.instance;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'DU-WHO',
          style: TextStyle(
            color: kPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // 신분 뱃지
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: auth.isStaff
                  ? kPrimary.withValues(alpha: 0.12)
                  : const Color(0xFF1565A8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              auth.isStaff ? '교직원' : '학생',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: auth.isStaff ? kPrimary : const Color(0xFF1565A8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: cs.onSurfaceVariant),
            tooltip: '설정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: cs.onSurfaceVariant),
            tooltip: '로그아웃',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    backgroundColor: cs.surfaceContainerLowest,
                    title: const Text('로그아웃',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('취소',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  );
                },
              );
              if (confirmed != true) return;
              await AuthService.instance.clearSession();
              AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _loadFavorites,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, '서비스'),
              const SizedBox(height: 12),
              _buildServiceCards(context),
              const SizedBox(height: 24),
              _buildSectionTitle(context, '즐겨찾기'),
              const SizedBox(height: 12),
              _buildFavoritesSection(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildServiceCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ServiceCard(
            icon: Icons.manage_search_rounded,
            iconBgStart: const Color(0xFF1A6B3C),
            iconBgEnd: const Color(0xFF2A9D5C),
            title: '교직원 검색',
            subtitle: '이름·부서·담당업무로 연락처 찾기',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (mounted) _loadFavorites();
            },
          ),
          const SizedBox(height: 10),
          _ServiceCard(
            icon: Icons.smart_toy_rounded,
            iconBgStart: const Color(0xFF1565A8),
            iconBgEnd: const Color(0xFF2196F3),
            title: 'AI 교직원 안내',
            subtitle: '부서 업무·담당자를 AI에게 물어보세요',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (_favorites.isEmpty) return _buildEmptyFavorites(context);
    return _buildFavoritesList(context);
  }

  Widget _buildEmptyFavorites(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.star_outline_rounded,
                size: 30, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            '즐겨찾기가 없습니다',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            '검색에서 ★ 를 눌러 추가하세요',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            for (int i = 0; i < _favorites.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: cs.outlineVariant),
              _favoriteTile(context, _favorites[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _favoriteTile(BuildContext context, Staff s) {
    final cs = Theme.of(context).colorScheme;
    final auth = AuthService.instance;
    final phone = auth.effectivePhone(s.tel, s.cellTel);

    // 학생: 직위 미표시
    final subtitle = [
      if (s.department.isNotEmpty) s.department,
      if (auth.isStaff && s.title.isNotEmpty) s.title,
    ].join(' · ');

    return InkWell(
      onTap: () => _showStaffDetails(context, s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: kPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.star_rounded,
                  color: Colors.amber, size: 22),
              tooltip: '즐겨찾기 해제',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _toggleFavorite(s),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call_rounded,
                      color: kPrimary, size: 18),
                  padding: EdgeInsets.zero,
                  tooltip: '전화걸기',
                  onPressed: () => _makePhoneCall(phone),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgStart;
  final Color iconBgEnd;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.iconBgStart,
    required this.iconBgEnd,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconBgStart, iconBgEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.outlineVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
