import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth.dart';
import 'db/database_helper.dart';
import 'main.dart';
import 'staff_model.dart';
import 'state/favorites.dart';

// 19개 초성 → 14개 기본 초성으로 정규화
const _leadingConsonants = [
  'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ',
  'ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
];
const _normalizeMap = {
  'ㄲ': 'ㄱ', 'ㄸ': 'ㄷ', 'ㅃ': 'ㅂ', 'ㅆ': 'ㅅ', 'ㅉ': 'ㅈ',
};

String _getInitialConsonant(String name) {
  if (name.isEmpty) return '#';
  final code = name.codeUnitAt(0);
  if (code >= 0xAC00 && code <= 0xD7A3) {
    return _leadingConsonants[(code - 0xAC00) ~/ (21 * 28)];
  }
  return name[0];
}

String _normalizeConsonant(String c) => _normalizeMap[c] ?? c;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Staff> _allStaff   = [];
  List<Staff> _foundStaff = [];
  bool _isLoading = true;
  int _searchMode = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 초성 인덱스용 상태 – GlobalKey 기반(정확한 스크롤)
  Map<String, List<Staff>> _groupedStaff       = {};
  List<String>             _availableConsonants = [];
  Map<String, GlobalKey>   _sectionKeys        = {};
  String?                  _activeConsonant;

  // 초성별 사전 계산된 스크롤 오프셋 (최초 1회 측정 후 저장)
  Map<String, double> _sectionOffsets = {};
  // 초기 측정 때만 크게(전 항목 레이아웃), 이후 정상값으로 줄여 리빌드 비용 최소화
  double _cacheExtent = 9999999;

  // 리스트 영역의 화면 상단 Y값을 구하기 위한 키
  final GlobalKey _listKey = GlobalKey();

  bool get _isSearching => _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAllStaff();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 위치에 따라 현재 섹션 초성을 자동 갱신
  // _sectionOffsets 사용 → RenderBox 조회 없이 순수 산술 비교
  void _onScroll() {
    if (_isSearching || _sectionOffsets.isEmpty) return;

    final pos = _scrollController.offset;
    String? best;
    double bestOffset = double.negativeInfinity;

    for (final consonant in _availableConsonants) {
      final offset = _sectionOffsets[consonant];
      if (offset == null) continue;
      // 현재 스크롤 위치를 막 지난 섹션 중 가장 마지막 것
      if (offset <= pos + 8 && offset > bestOffset) {
        bestOffset = offset;
        best = consonant;
      }
    }

    if (best != null && best != _activeConsonant) {
      setState(() => _activeConsonant = best);
    }
  }

  Future<void> _loadAllStaff() async {
    final staff = await DatabaseHelper.instance.getAllStaff();
    staff.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;

    final grouped    = <String, List<Staff>>{};
    final consonants = <String>[];
    final keys       = <String, GlobalKey>{};

    for (final s in staff) {
      final c = _normalizeConsonant(_getInitialConsonant(s.name));
      if (!grouped.containsKey(c)) {
        grouped[c] = [];
        consonants.add(c);
        keys[c] = GlobalKey();
      }
      grouped[c]!.add(s);
    }

    setState(() {
      _allStaff            = staff;
      _foundStaff          = staff;
      _groupedStaff        = grouped;
      _availableConsonants = consonants;
      _sectionKeys         = keys;
      _isLoading           = false;
    });

    // 첫 프레임 렌더 후 모든 섹션 오프셋 1회 측정·저장
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureOffsets());
  }

  // cacheExtent: 99999 상태에서 전체 항목이 레이아웃된 직후 실행
  // → 모든 섹션 헤더의 절대 스크롤 오프셋을 정확하게 계산
  void _measureOffsets() {
    if (!mounted) return;
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    final listTopY = listBox.localToGlobal(Offset.zero).dy;

    final offsets = <String, double>{};
    for (final consonant in _availableConsonants) {
      final box = _sectionKeys[consonant]?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      // scroll offset = 0 기준의 절대 콘텐츠 좌표
      final contentY = _scrollController.offset +
          box.localToGlobal(Offset.zero).dy - listTopY;
      offsets[consonant] = contentY.clamp(0.0, double.maxFinite);
    }

    // 측정 완료 → cacheExtent 정상화로 이후 리빌드 비용 최소화
    setState(() {
      _sectionOffsets = offsets;
      _cacheExtent    = 250;
    });
  }

  Future<void> _runFilter(String keyword) async {
    final results = keyword.isEmpty
        ? _allStaff
        : await DatabaseHelper.instance.searchStaff(keyword, _searchMode);
    if (!mounted) return;
    setState(() {
      _foundStaff      = results;
      _activeConsonant = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _scrollToConsonant(String consonant) {
    final target = _sectionOffsets[consonant];
    if (target == null || !_scrollController.hasClients) return;

    HapticFeedback.selectionClick();
    setState(() => _activeConsonant = consonant);

    // 사전 계산된 오프셋을 바로 사용 → 지연 없음
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ─── 전화/메일 ────────────────────────────────────────────────

  Future<void> _makePhoneCall(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
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
    if (mounted) setState(() {});
  }

  // ─── 상세 바텀시트 ───────────────────────────────────────────

  void _showStaffDetails(BuildContext context, Staff staff) {
    final auth  = AuthService.instance;
    final phone = auth.effectivePhone(staff.tel, staff.cellTel);
    final loc   = auth.effectiveLocation(staff.location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: cs.outlineVariant,
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
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff.name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface)),
                        if (auth.isStaff && staff.title.isNotEmpty)
                          Text(staff.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: kPrimary,
                                  fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 16),
              _detailRow(ctx, Icons.business_rounded, '부서', staff.department),
              if (loc.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailRow(ctx, Icons.location_on_rounded, '위치', loc),
              ],
              if (staff.tel.isNotEmpty && staff.tel != '0000') ...[
                const SizedBox(height: 12),
                _detailRow(ctx, Icons.phone_rounded, '교내전화', staff.tel),
              ],
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
    );
  }

  Widget _detailRow(
      BuildContext ctx, IconData icon, String label, String value) {
    final cs = Theme.of(ctx).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: kPrimary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 13, color: cs.onSurface)),
        ),
      ],
    );
  }

  // ─── 빌드 ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('교직원 검색')),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kPrimary),
                  const SizedBox(height: 16),
                  Text('교직원 정보를 불러오는 중...',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
            )
          : Column(
              children: [
                // ── 검색바 ──────────────────────────────────────
                Container(
                  color: cs.surfaceContainerLowest,
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
                          selectedBackgroundColor: cs.primaryContainer,
                          selectedForegroundColor: kPrimary,
                          foregroundColor: cs.onSurfaceVariant,
                          side: BorderSide(color: cs.outlineVariant),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: _runFilter,
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: '이름, 부서, 담당업무로 검색',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: kPrimary, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded,
                                      size: 18,
                                      color: cs.onSurfaceVariant),
                                  onPressed: () {
                                    _searchController.clear();
                                    _runFilter('');
                                  },
                                )
                              : null,
                          fillColor: cs.surface,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 결과 수 ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text('검색 결과',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_isSearching ? _foundStaff.length : _allStaff.length}명',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 목록 ────────────────────────────────────────
                Expanded(child: _buildListArea(context)),
              ],
            ),
    );
  }

  Widget _buildListArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isSearching) {
      if (_foundStaff.isEmpty) return _emptyState(cs);
      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _foundStaff.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _staffCard(ctx, _foundStaff[i]),
      );
    }

    if (_groupedStaff.isEmpty) return _emptyState(cs);

    // 전체 목록: GlobalKey 기반 섹션 헤더 + 우측 초성 인덱스
    // ListView(non-builder) → 위젯 재활용 없음 → GlobalKey 항상 유효
    final children = <Widget>[];
    for (final consonant in _availableConsonants) {
      children.add(
        Container(
          key: _sectionKeys[consonant],
          child: _buildSectionHeader(context, consonant),
        ),
      );
      for (final staff in _groupedStaff[consonant]!) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _staffCard(context, staff),
          ),
        );
      }
    }

    return Stack(
      key: _listKey,
      children: [
        ListView(
          controller: _scrollController,
          cacheExtent: _cacheExtent,
          padding: const EdgeInsets.fromLTRB(16, 0, 32, 24),
          children: children,
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _ConsonantIndexBar(
            consonants: _availableConsonants,
            active: _activeConsonant,
            onSelect: _scrollToConsonant,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('검색 결과가 없습니다',
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String consonant) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 24, 4),
      child: Row(
        children: [
          Container(
            width: 30, height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              consonant,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
        ],
      ),
    );
  }

  // ─── 교직원 카드 ─────────────────────────────────────────────

  Widget _staffCard(BuildContext context, Staff staff) {
    final cs   = Theme.of(context).colorScheme;
    final auth = AuthService.instance;
    final id   = staff.id;
    final isFav = id != null && favoriteStaffIds.contains(id);
    final phone = auth.effectivePhone(staff.tel, staff.cellTel);

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showStaffDetails(context, staff),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    color: kPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(staff.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        if (auth.isStaff && staff.title.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(staff.title,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: kPrimary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ],
                    ),
                    if (staff.department.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(staff.department,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(phone,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
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
                        isFav
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isFav ? Colors.amber : cs.outlineVariant,
                        size: 22,
                      ),
                      onPressed:
                          id == null ? null : () => _toggleFavorite(staff),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    SizedBox(
                      width: 36, height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.call_rounded,
                            color: kPrimary, size: 20),
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

// ─── 초성 인덱스 바 ────────────────────────────────────────────

class _ConsonantIndexBar extends StatefulWidget {
  final List<String> consonants;
  final String? active;
  final ValueChanged<String> onSelect;

  const _ConsonantIndexBar({
    required this.consonants,
    required this.active,
    required this.onSelect,
  });

  @override
  State<_ConsonantIndexBar> createState() => _ConsonantIndexBarState();
}

class _ConsonantIndexBarState extends State<_ConsonantIndexBar> {
  String? _dragging;

  void _handleTouch(double dy, double totalHeight) {
    if (widget.consonants.isEmpty) return;
    final itemH = totalHeight / widget.consonants.length;
    final index =
        (dy / itemH).floor().clamp(0, widget.consonants.length - 1);
    final c = widget.consonants[index];
    if (c != _dragging) {
      setState(() => _dragging = c);
      widget.onSelect(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _dragging ?? widget.active;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        return GestureDetector(
          onTapDown: (d) => _handleTouch(d.localPosition.dy, totalH),
          onTapUp: (_) => setState(() => _dragging = null),
          onPanUpdate: (d) => _handleTouch(d.localPosition.dy, totalH),
          onPanEnd: (_) => setState(() => _dragging = null),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              border: Border(
                left: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.consonants.map((c) {
                final isActive = c == active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: isActive ? 22 : 18,
                  height: isActive ? 22 : 18,
                  decoration: isActive
                      ? const BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  alignment: Alignment.center,
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: isActive ? 11 : 10,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isActive ? Colors.white : cs.onSurfaceVariant,
                      height: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
