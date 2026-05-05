import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'call_screen.dart';

// 전체 교직원 임시 데이터 (Mock Data)
final List<Map<String, dynamic>> allStaff = [
  {
    "name": "김지연",
    "department": "컴퓨터정보공학부",
    "phone": "053-850-6571",
    "location": "IT·공과대학\n(D17) 000호",
    "isStaff": true,
    "isFavorite": true,
  },
  {
    "name": "박순진",
    "department": "총장실",
    "phone": "053-850-1234",
    "location": "본관\n1층",
    "isStaff": true,
    "isFavorite": true,
  },
  {
    "name": "홍길동",
    "department": "행정실",
    "phone": "053-850-9999",
    "location": "본관\n2층",
    "isStaff": true,
    "isFavorite": false,
  },
  {
    "name": "신유라",
    "department": "도서관",
    "phone": "053-850-8001",
    "location": "창파도서관\n1층",
    "isStaff": true,
    "isFavorite": false,
  },
  {
    "name": "권형준",
    "department": "학생지원팀",
    "phone": "053-850-8101",
    "location": "웅지관\n2층",
    "isStaff": true,
    "isFavorite": true,
  },
  {
    "name": "문가영",
    "department": "입학처",
    "phone": "053-850-8201",
    "location": "본관\n(A01) 301호",
    "isStaff": true,
    "isFavorite": false,
  },
  {
    "name": "류지석",
    "department": "산학협력단",
    "phone": "053-850-8301",
    "location": "산학협력관\n(R02) 201호",
    "isStaff": true,
    "isFavorite": false,
  },
  {
    "name": "안소민",
    "department": "보건진료소",
    "phone": "053-850-8401",
    "location": "보건진료소\n(S04) 201호",
    "isStaff": true,
    "isFavorite": false,
  },
];

// 전화 다이얼러 호출 - 화면 간 공유
Future<void> makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    debugPrint('전화 연결을 지원하지 않는 기기이거나 오류가 발생했습니다: $phoneNumber');
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<String, dynamic>> _foundStaff = [];

  @override
  void initState() {
    super.initState();
    _foundStaff = allStaff;
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = allStaff;
    } else {
      results = allStaff
          .where(
            (staff) =>
                staff["name"].toString().contains(enteredKeyword) ||
                staff["department"].toString().contains(enteredKeyword),
          )
          .toList();
    }

    setState(() {
      _foundStaff = results;
    });
  }

  // 즐겨찾기 ON/OFF 토글
  // staff Map의 isFavorite 값을 직접 뒤집고 setState로 화면 갱신
  // (allStaff와 같은 Map 객체를 참조하므로 홈 화면 즐겨찾기 목록에도 즉시 반영됨)
  void _toggleFavorite(Map<String, dynamic> staff) {
    setState(() {
      // null 또는 false면 true로, true면 false로 (== true 비교로 nullable 안전 처리)
      staff["isFavorite"] = !(staff["isFavorite"] == true);
    });
  }

  // 항목을 터치했을 때 상세 정보를 보여주는 다이얼로그(팝업) 함수
  void _showStaffDetails(BuildContext context, Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          title: const Text(
            '교직원 상세 정보',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.person, '이름', staff["name"]),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.business, '부서', staff["department"]),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone, '전화', staff["phone"]),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.location_on,
                '위치',
                staff["location"].replaceAll('\n', ' '),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CallScreen(isStaff: staff["isStaff"] == true),
                  ),
                );
              },
              icon: const Icon(Icons.call, size: 18),
              label: const Text('전화걸기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('교직원 검색'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Radio<int>(value: 0, groupValue: 0, onChanged: (value) {}),
                const Text('전체'),
                Radio<int>(value: 1, groupValue: 0, onChanged: (value) {}),
                const Text('이름(부서)'),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                hintText: '이름 또는 부서 검색',
                suffixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: const Border(
                  top: BorderSide(color: Colors.grey),
                  bottom: BorderSide(color: Colors.grey),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '이름(부서)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '교내전화',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '사무실위치',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 48), // 즐겨찾기 별 컬럼 자리
                ],
              ),
            ),
            Expanded(
              child: _foundStaff.isNotEmpty
                  ? ListView.builder(
                      itemCount: _foundStaff.length,
                      itemBuilder: (context, index) {
                        final staff = _foundStaff[index];
                        return InkWell(
                          onTap: () => _showStaffDetails(context, staff),
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      Text(
                                        staff["name"],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        staff["department"],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CallScreen(
                                            isStaff: staff["isStaff"] == true,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        staff["phone"],
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      staff["location"],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                // 즐겨찾기 토글 버튼 - 별 아이콘
                                // 활성: 채워진 별(amber) / 비활성: 빈 별(grey)
                                IconButton(
                                  icon: Icon(
                                    staff["isFavorite"] == true
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: staff["isFavorite"] == true
                                        ? Colors.amber
                                        : Colors.grey,
                                  ),
                                  tooltip: staff["isFavorite"] == true
                                      ? '즐겨찾기 해제'
                                      : '즐겨찾기 추가',
                                  onPressed: () => _toggleFavorite(staff),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
