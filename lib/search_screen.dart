import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db/database_helper.dart';
import 'staff_model.dart';
import 'state/favorites.dart';
import 'main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Staff> _allStaff = [];
  List<Staff> _foundStaff = [];
  bool _isLoading = true;
  int _searchMode = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStaff() async {
    final staff = await DatabaseHelper.instance.getAllStaff();
    if (!mounted) return;
    setState(() {
      _allStaff = staff;
      _foundStaff = staff;
      _isLoading = false;
    });
  }

  Future<void> _runFilter(String keyword) async {
    final results = keyword.isEmpty
        ? _allStaff
        : await DatabaseHelper.instance.searchStaff(keyword, _searchMode);
    if (!mounted) return;
    setState(() => _foundStaff = results);
  }

  Future<void> _toggleFavorite(Staff staff) async {
    final id = staff.id;
    if (id == null) return;
    await toggleFavorite(id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || cleaned == '0000') return;
    final Uri uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showStaffDetails(BuildContext context, Staff staff) {
    final phone = staff.tel.isNotEmpty && staff.tel != '0000'
        ? staff.tel
        : staff.cellTel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
        title: const Text('교직원 검색'),
        backgroundColor: Colors.white,
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x18000000),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kPrimary),
                  const SizedBox(height: 16),
                  Text(
                    '교직원 정보를 불러오는 중...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text('전체'),
                            icon: Icon(Icons.list_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('이름·부서'),
                            icon: Icon(Icons.person_search_rounded, size: 16),
                          ),
                        ],
                        selected: {_searchMode},
                        onSelectionChanged: (s) {
                          setState(() => _searchMode = s.first);
                          _runFilter(_searchController.text);
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: kPrimaryLight,
                          selectedForegroundColor: kPrimary,
                          foregroundColor: kTextSecondary,
                          side: const BorderSide(color: kDivider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: _runFilter,
                        style: const TextStyle(fontSize: 14, color: kTextPrimary),
                        decoration: InputDecoration(
                          hintText: '이름, 부서, 담당업무로 검색',
                          hintStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: kTextSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    _runFilter('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: kSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text(
                        '검색 결과',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_foundStaff.length}명',
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _foundStaff.isNotEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _foundStaff.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _staffCard(_foundStaff[index]),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _staffCard(Staff staff) {
    final id = staff.id;
    final isFav = id != null && favoriteStaffIds.contains(id);
    final phone = staff.tel.isNotEmpty && staff.tel != '0000'
        ? staff.tel
        : staff.cellTel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showStaffDetails(context, staff),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kDivider),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          staff.name,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                        ),
                        if (staff.title.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPrimaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              staff.title,
                              style: const TextStyle(
                                fontSize: 11, color: kPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (staff.department.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        staff.department,
                        style: const TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: IconButton(
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav ? Colors.amber : Colors.grey[350],
                        size: 22,
                      ),
                      onPressed: id == null ? null : () => _toggleFavorite(staff),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    SizedBox(
                      width: 36, height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.call_rounded, color: kPrimary, size: 20),
                        onPressed: () => _makePhoneCall(phone),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
