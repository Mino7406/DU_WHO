import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'staff_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Staff> _allStaff = [];
  List<Staff> _foundStaff = [];
  bool _isLoading = true;

  // 0: 전체, 1: 이름/부서
  int _searchMode = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffData() async {
    final String jsonString =
        await rootBundle.loadString('assets/staff_db.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> list = jsonData['memberSearchList'] ?? [];

    final staff = list
        .map((e) => Staff.fromJson(e as Map<String, dynamic>))
        .where((s) => s.name.isNotEmpty)
        .toList();

    setState(() {
      _allStaff = staff;
      _foundStaff = staff;
      _isLoading = false;
    });
  }

  void _runFilter(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _foundStaff = _allStaff;
      } else {
        if (_searchMode == 1) {
          // 이름/부서만 검색
          _foundStaff = _allStaff
              .where((s) =>
                  s.name.contains(keyword) ||
                  s.department.contains(keyword))
              .toList();
        } else {
          // 전체 필드 검색
          _foundStaff =
              _allStaff.where((s) => s.matchesQuery(keyword)).toList();
        }
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || cleaned == '0000') return;
    final Uri uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showStaffDetails(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.person, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${staff.name} ${staff.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(Icons.business, '부서', staff.department),
                if (staff.location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.location_on, '위치', staff.location),
                ],
                if (staff.tel.isNotEmpty && staff.tel != '0000') ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.phone, '교내전화', staff.tel),
                ],
                if (staff.cellTel.isNotEmpty &&
                    staff.cellTel != '000-0000-0000') ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.smartphone, '휴대폰', staff.cellTel),
                ],
                if (staff.email.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.email, '이메일', staff.email),
                ],
                if (staff.chargeBusiness.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.work, '담당업무', staff.chargeBusiness),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
            if (staff.email.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendEmail(staff.email);
                },
                icon: const Icon(Icons.email, size: 18),
                label: const Text('메일보내기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            if (staff.tel.isNotEmpty && staff.tel != '0000')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(staff.tel);
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('교직원 정보를 불러오는 중...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 검색 모드 라디오 버튼
                  Row(
                    children: [
                      RadioGroup<int>(
                        groupValue: _searchMode,
                        onChanged: (v) {
                          setState(() => _searchMode = v!);
                          _runFilter(_searchController.text);
                        },
                        child: Row(
                          children: const [
                            Radio<int>(value: 0),
                            Text('전체'),
                            Radio<int>(value: 1),
                            Text('이름(부서)'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '총 ${_foundStaff.length}명',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  // 검색창
                  TextField(
                    controller: _searchController,
                    onChanged: _runFilter,
                    decoration: InputDecoration(
                      hintText: '이름, 부서, 담당업무 검색',
                      suffixIcon:
                          const Icon(Icons.search, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide:
                            const BorderSide(color: Colors.green),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 헤더
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                            flex: 3,
                            child: Center(
                                child: Text('이름(부서/직함)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)))),
                        Expanded(
                            flex: 3,
                            child: Center(
                                child: Text('교내전화',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)))),
                        Expanded(
                            flex: 3,
                            child: Center(
                                child: Text('사무실위치',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)))),
                      ],
                    ),
                  ),
                  // 목록
                  Expanded(
                    child: _foundStaff.isNotEmpty
                        ? ListView.builder(
                            itemCount: _foundStaff.length,
                            itemBuilder: (context, index) {
                              final staff = _foundStaff[index];
                              return InkWell(
                                onTap: () =>
                                    _showStaffDetails(context, staff),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey,
                                          width: 0.5),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          children: [
                                            Text(staff.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 14)),
                                            Text(staff.department,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey),
                                                textAlign:
                                                    TextAlign.center),
                                            if (staff.title.isNotEmpty)
                                              Text(staff.title,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green),
                                                  textAlign:
                                                      TextAlign.center),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: staff.tel.isNotEmpty &&
                                                  staff.tel != '0000'
                                              ? TextButton(
                                                  onPressed: () =>
                                                      _makePhoneCall(
                                                          staff.tel),
                                                  style:
                                                      TextButton.styleFrom(
                                                    padding:
                                                        EdgeInsets.zero,
                                                    minimumSize:
                                                        Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    staff.tel,
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                      fontSize: 12,
                                                    ),
                                                    textAlign:
                                                        TextAlign.center,
                                                  ),
                                                )
                                              : const Text('-',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            staff.location.isNotEmpty
                                                ? staff.location
                                                : '-',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text('검색 결과가 없습니다.',
                                style: TextStyle(fontSize: 16)),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
