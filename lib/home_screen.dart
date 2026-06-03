import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_screen.dart';
import 'db/database_helper.dart';
import 'main.dart';
import 'search_screen.dart';
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
  }

  // ─── 수신 전화 팝업을 위한 권한 요청 ──────────────────────────

  Future<void> _requestCallPermissions() async {
    const ch = MethodChannel('du_who/call_overlay');

    // ① 전화 상태 읽기 (READ_PHONE_STATE)
    final phoneStatus = await Permission.phone.status;
    if (phoneStatus.isDenied) await Permission.phone.request();

    // ② READ_CALL_LOG — Android 10+에서 PHONE 그룹과 분리됨
    //    없으면 수신 번호를 받지 못해 교직원 조회 불가
    final hasCallLog = await ch.invokeMethod<bool>('checkCallLogPermission') ?? true;
    if (!hasCallLog) {
      await ch.invokeMethod('requestCallLogPermission');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // ③ Android 13+ 알림 권한 (수신 전화 알림 표시에 필요)
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) await Permission.notification.request();

    // ④ Samsung 배터리 최적화 제외 (백그라운드 서비스 유지)
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
    final phone = staff.tel.isNotEmpty && staff.tel != '0000'
        ? staff.tel
        : staff.cellTel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isFav = staff.id != null && favoriteStaffIds.contains(staff.id);
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: kDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimary, Color(0xFF2A9D5C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary),
                          ),
                          if (staff.title.isNotEmpty)
                            Text(
                              staff.title,
                              style: const TextStyle(
                                fontSize: 14, color: kPrimary, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav ? Colors.amber : kTextSecondary,
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
                const Divider(height: 1, color: kDivider),
                const SizedBox(height: 16),
                _detailRow(Icons.business_rounded, '부서', staff.department),
                if (staff.location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.location_on_rounded, '위치', staff.location),
                ],
                if (staff.tel.isNotEmpty && staff.tel != '0000') ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.phone_rounded, '교내전화', staff.tel),
                ],
                if (staff.cellTel.isNotEmpty && staff.cellTel != '000-0000-0000') ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.smartphone_rounded, '휴대폰', staff.cellTel),
                ],
                if (staff.email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.email_rounded, '이메일', staff.email),
                ],
                if (staff.chargeBusiness.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.work_rounded, '담당업무', staff.chargeBusiness),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: kPrimaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, color: kTextPrimary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x18000000),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: kTextSecondary),
            tooltip: '로그아웃',
            onPressed: () {
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
              _buildSectionTitle('서비스'),
              const SizedBox(height: 12),
              _buildServiceCards(),
              const SizedBox(height: 24),
              _buildSectionTitle('즐겨찾기'),
              const SizedBox(height: 12),
              _buildFavoritesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kTextPrimary,
        ),
      ),
    );
  }

  Widget _buildServiceCards() {
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

  Widget _buildFavoritesSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (_favorites.isEmpty) return _buildEmptyFavorites();
    return _buildFavoritesList();
  }

  Widget _buildEmptyFavorites() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.star_outline_rounded, size: 30, color: kTextSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            '즐겨찾기가 없습니다',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            '검색에서 ★ 를 눌러 추가하세요',
            style: TextStyle(fontSize: 13, color: kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kDivider),
        ),
        child: Column(
          children: [
            for (int i = 0; i < _favorites.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72, endIndent: 16, color: kDivider),
              _favoriteTile(_favorites[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _favoriteTile(Staff s) {
    final phone = s.tel.isNotEmpty && s.tel != '0000' ? s.tel : s.cellTel;
    final subtitle = [
      if (s.department.isNotEmpty) s.department,
      if (s.title.isNotEmpty) s.title,
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
                color: kPrimaryLight,
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: kTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              tooltip: '즐겨찾기 해제',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _toggleFavorite(s),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call_rounded, color: kPrimary, size: 18),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kDivider),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
