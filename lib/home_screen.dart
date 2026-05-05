import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'call_screen.dart';
import 'main.dart';

// 홈 화면 - 로그인 후 처음 진입하는 화면
// 검색 바로가기 카드 + 즐겨찾기 등록된 연락처 목록을 표시
//
// StatefulWidget인 이유: 검색 화면에서 즐겨찾기 별을 토글하고 뒤로 돌아왔을 때
// 즐겨찾기 목록을 다시 그려야 하므로 setState 호출이 필요함
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
              // pushReplacement: 뒤로가기로 홈에 다시 못 돌아오도록 스택을 교체
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
            // 1. 교직원 검색 화면으로 이동하는 카드
            _buildSearchShortcut(),
            const SizedBox(height: 24),
            // 2. 즐겨찾기 등록된 연락처 목록 (또는 비어있을 때 안내)
            _buildFavoritesSection(),
          ],
        ),
      ),
    );
  }

  // 검색 화면으로 이동하는 바로가기 카드 위젯
  // 탭 시 SearchScreen으로 이동하고, 뒤로 돌아왔을 때 즐겨찾기 목록을 새로고침
  Widget _buildSearchShortcut() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ), // 클릭 가능한 카드 형태로 디자인
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        // 검색 화면에서 별 토글이 있었을 수 있으므로
        // await로 화면 복귀를 기다린 뒤 setState로 즐겨찾기 섹션 재빌드
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ), // 검색 화면으로 이동
          );
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 24.0,
          ), // 카드 내부 여백 설정
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12.0),
                ), // 검색 아이콘이 들어갈 컨테이너 디자인
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
                      '이름·부서로 연락처 찾기',
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

  // 즐겨찾기 섹션 전체 - 헤더 + (목록 또는 빈 안내)
  Widget _buildFavoritesSection() {
    // search_screen.dart 최상위 allStaff에서 isFavorite==true인 항목만 필터링
    final favorites = allStaff.where((s) => s["isFavorite"] == true).toList();

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
        // 즐겨찾기 항목 유무에 따라 다른 카드 분기
        if (favorites.isEmpty)
          _buildEmptyFavoritesCard()
        else
          _buildFavoritesList(favorites),
      ],
    );
  }

  // 즐겨찾기가 하나도 없을 때 표시되는 안내 카드
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
              '즐겨찾기 항목이 여기에 표시됩니다',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // 즐겨찾기 항목들을 ListTile로 나열하는 카드
  // - leading: 사람 아이콘 아바타
  // - title: 이름 (굵게)
  // - subtitle: "부서 · 전화번호"
  // - trailing: 통화 아이콘 버튼 (탭 시 데모 통화 화면으로 이동)
  Widget _buildFavoritesList(List<Map<String, dynamic>> favorites) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        children: [
          for (int i = 0; i < favorites.length; i++) ...[
            // 항목 사이 구분선 (첫 번째 항목 위쪽에는 그리지 않음)
            if (i > 0) const Divider(height: 1, indent: 72, endIndent: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: const Icon(Icons.person, color: Colors.green),
              ),
              title: Text(
                favorites[i]["name"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${favorites[i]["department"]} · ${favorites[i]["phone"]}',
                style: const TextStyle(fontSize: 12),
              ),
              // 통화 아이콘 - 탭 시 CallScreen(데모 통화 화면)으로 이동
              // isStaff 값을 전달해 학생/교직원에 따른 정보 노출 차등을 적용
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                tooltip: '전화걸기',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CallScreen(isStaff: favorites[i]["isStaff"] == true),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
