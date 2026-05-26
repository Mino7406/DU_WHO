import 'package:flutter/material.dart';
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
  }

  // 전체 staff 를 DB 에서 읽어 favoriteStaffIds 와 교집합으로 즐겨찾기 목록 구성.
  // 검색 화면에서 별 토글 후 돌아왔을 때도 다시 호출돼 최신 상태 반영.
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('DU-WHO'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              // 뒤로가기로 홈에 다시 못 돌아오도록 스택 교체
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchShortcut(),
            const SizedBox(height: 12),
            _buildChatShortcut(),
            const SizedBox(height: 24),
            _buildFavoritesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchShortcut() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
          if (mounted) _loadFavorites();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 24.0,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(Icons.search, color: Colors.green, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '교직원 검색',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '이름·부서·담당업무로 연락처 찾기',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatShortcut() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 24.0,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.green, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 교직원 안내',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '부서 업무·담당자를 AI에게 물어보세요',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '즐겨찾기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(child: CircularProgressIndicator(color: Colors.green)),
          )
        else if (_favorites.isEmpty)
          _buildEmptyFavoritesCard()
        else
          _buildFavoritesList(),
      ],
    );
  }

  Widget _buildEmptyFavoritesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
        child: Column(
          children: [
            Icon(Icons.star_border, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              '검색 화면에서 ★ 를 눌러 즐겨찾기를 추가하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        children: [
          for (int i = 0; i < _favorites.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72, endIndent: 16),
            _favoriteTile(_favorites[i]),
          ],
        ],
      ),
    );
  }

  Widget _favoriteTile(Staff s) {
    final phone = s.tel.isNotEmpty && s.tel != '0000' ? s.tel : s.cellTel;
    final subtitle = [
      if (s.department.isNotEmpty) s.department,
      if (s.title.isNotEmpty) s.title,
      if (phone.isNotEmpty) phone,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        child: const Icon(Icons.person, color: Colors.green),
      ),
      title: Text(
        s.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: phone.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              tooltip: '전화걸기',
              onPressed: () => _makePhoneCall(phone),
            )
          : null,
    );
  }
}
