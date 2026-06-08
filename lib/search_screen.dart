import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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

// 평탄화된 리스트 아이템: consonant != null → 섹션 헤더, staff != null → 카드
typedef _ListItem = ({String? consonant, Staff? staff});

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
  final ScrollController _searchScrollController = ScrollController();

  // 초성 인덱스용 상태
  List<String>    _availableConsonants = [];
  List<_ListItem> _flatItems           = [];

  // 초성별 flat 아이템 인덱스 (높이 추정 불필요 – 인덱스 기반 점프)
  Map<String, int> _sectionItemIndexes = {};

  // scrollable_positioned_list 컨트롤러
  final ItemScrollController    _itemScrollController    = ItemScrollController();
  final ItemPositionsListener   _itemPositionsListener   = ItemPositionsListener.create();

  // ValueNotifier로 setState 없이 인덱스바만 갱신
  final ValueNotifier<String?> _activeConsonant = ValueNotifier(null);

  bool get _isSearching => _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    _loadAllStaff();
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    _searchController.dispose();
    _searchScrollController.dispose();
    _activeConsonant.dispose();
    super.dispose();
  }

  // 현재 보이는 아이템 목록으로 활성 초성 갱신
  void _onItemPositionsChanged() {
    if (_isSearching || _sectionItemIndexes.isEmpty) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // 뷰포트 상단에 가장 가까운 아이템 인덱스
    final topIndex = positions
        .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b)
        .index;

    // topIndex 이하인 섹션 헤더 중 가장 큰 인덱스의 초성 = 현재 섹션
    String? best;
    for (final c in _availableConsonants) {
      final idx = _sectionItemIndexes[c];
      if (idx != null && idx <= topIndex) best = c;
    }

    if (best != null && best != _activeConsonant.value) {
      _activeConsonant.value = best;
    }
  }

  Future<void> _loadAllStaff() async {
    final staff = await DatabaseHelper.instance.getAllStaff();
    staff.sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;

    final grouped    = <String, List<Staff>>{};
    final consonants = <String>[];

    for (final s in staff) {
      final c = _normalizeConsonant(_getInitialConsonant(s.name));
      if (!grouped.containsKey(c)) {
        grouped[c] = [];
        consonants.add(c);
      }
      grouped[c]!.add(s);
    }

    // 평탄 리스트 + 섹션 헤더의 flat 인덱스 기록
    final flat    = <_ListItem>[];
    final indexes = <String, int>{};
    for (final c in consonants) {
      indexes[c] = flat.length;
      flat.add((consonant: c, staff: null));
      for (final s in grouped[c]!) {
        flat.add((consonant: null, staff: s));
      }
    }

    setState(() {
      _allStaff             = staff;
      _foundStaff           = staff;
      _availableConsonants  = consonants;
      _flatItems            = flat;
      _sectionItemIndexes   = indexes;
      _isLoading            = false;
    });
  }

  Future<void> _runFilter(String keyword) async {
    final results = keyword.isEmpty
        ? _allStaff
        : await DatabaseHelper.instance.searchStaff(keyword, _searchMode);
    if (!mounted) return;
    setState(() => _foundStaff = results);
    _activeConsonant.value = null;
    if (_searchScrollController.hasClients) _searchScrollController.jumpTo(0);
    if (!_isSearching && _itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: 0);
    }
  }

  void _scrollToConsonant(String consonant) {
    final index = _sectionItemIndexes[consonant];
    if (index == null || !_itemScrollController.isAttached) return;

    HapticFeedback.selectionClick();
    _activeConsonant.value = consonant;
    _itemScrollController.jumpTo(index: index);
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
        controller: _searchScrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _foundStaff.length,
        separatorBuilder: (context, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _staffCard(ctx, _foundStaff[i]),
      );
    }

    if (_flatItems.isEmpty) return _emptyState(cs);

    // ScrollablePositionedList → 인덱스 기반 점프 (높이 추정 불필요)
    // ValueListenableBuilder → 스크롤 시 인덱스바만 갱신 (전체 리빌드 없음)
    return Stack(
      children: [
        ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(16, 0, 32, 24),
          itemCount: _flatItems.length,
          itemBuilder: (ctx, i) {
            final item = _flatItems[i];
            if (item.consonant != null) {
              return _buildSectionHeader(ctx, item.consonant!);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _staffCard(ctx, item.staff!),
            );
          },
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: ValueListenableBuilder<String?>(
            valueListenable: _activeConsonant,
            builder: (context, active, _) => _ConsonantIndexBar(
              consonants: _availableConsonants,
              active: active,
              onSelect: _scrollToConsonant,
            ),
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
