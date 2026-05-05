import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // 전체 교직원 임시 데이터 (Mock Data)
  final List<Map<String, dynamic>> _allStaff = [
    {
      "name": "김지연",
      "department": "컴퓨터정보공학부",
      "phone": "053-850-6571",
      "location": "IT·공과대학\n(D17) 000호",
      "isStaff": true,
    },
    {
      "name": "박순진",
      "department": "총장실",
      "phone": "053-850-1234",
      "location": "본관\n1층",
      "isStaff": true,
    },
    {
      "name": "홍길동",
      "department": "행정실",
      "phone": "053-850-9999",
      "location": "본관\n2층",
      "isStaff": true,
    },
  ];

  List<Map<String, dynamic>> _foundStaff = [];

  @override
  void initState() {
    super.initState();
    _foundStaff = _allStaff;
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allStaff;
    } else {
      results = _allStaff
          .where((staff) =>
              staff["name"].toString().contains(enteredKeyword) ||
              staff["department"].toString().contains(enteredKeyword))
          .toList();
    }

    setState(() {
      _foundStaff = results;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('전화 연결을 지원하지 않는 기기이거나 오류가 발생했습니다: $phoneNumber');
    }
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
            mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 높이 차지
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.person, '이름', staff["name"]),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.business, '부서', staff["department"]),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone, '전화', staff["phone"]),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_on, '위치', staff["location"].replaceAll('\n', ' ')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 창 닫기
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫고
                _makePhoneCall(staff["phone"]); // 전화 다이얼러 호출
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

  // 상세 정보 팝업 내의 텍스트 배치를 돕는 헬퍼 위젯
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
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ),
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
                  Expanded(flex: 2, child: Center(child: Text('이름(부서)', style: TextStyle(fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text('교내전화', style: TextStyle(fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text('사무실위치', style: TextStyle(fontWeight: FontWeight.bold)))),
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
                          onTap: () => _showStaffDetails(context, staff), // 가상 통화 화면 대신 팝업 호출
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey, width: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      Text(staff["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(staff["department"], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () => _makePhoneCall(staff["phone"]),
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
                                  child: Center(child: Text(staff["location"], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 16)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}