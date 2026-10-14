import 'dart:async';

import 'package:flutter/material.dart';

import '../auth.dart';
import '../services/ai_chat_service.dart';
import '../staff_model.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../utils/staff_search.dart';
import '../widgets/ai_exchange.dart';
import '../widgets/app_widgets.dart';
import '../widgets/caller_id_card.dart';
import '../widgets/staff_tile.dart';

/// 찾기 탭 = 교직원 검색 + AI 안내 한 화면.
/// 입력하면 아래에 검색 결과가 바로 나오고(초성 검색 가능), ✨ 또는 키보드의 검색으로 보내면
/// AI 답변이 같은 화면에 나온다. 입력이 비어 있으면 예시 질문과 최근 본 교직원을 보여준다.
class FindTab extends StatefulWidget {
  const FindTab({super.key});

  @override
  State<FindTab> createState() => FindTabState();
}

class FindTabState extends State<FindTab> {
  // 입력이 비어 있을 때 보여주는 예시 질문
  static const _examples = ['장학금 담당자가 누구야?', '기숙사 연락처 알려줘', '수강신청 문의는 어디로?'];

  // 결과가 너무 많을 때 한 번에 그리는 개수(스크롤하면 더 보기)
  static const _pageSize = 60;

  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  Timer? _debounce;
  int _searchMode = 0; // 0: 전체, 1: 이름·부서
  String _shownQuery = '';
  List<Staff> _results = const [];
  int _visible = _pageSize;

  final List<AiExchange> _exchanges = [];
  bool _asking = false;

  String get _query => _input.text.trim();
  bool get hasConversation => _exchanges.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 화면은 새 대화로 시작하므로 서버로 보내는 대화 기록도 비운다
    AiChatService.instance.resetChat();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 탭을 다시 누르면 입력창으로 올라가 포커스를 준다
  void focusInput() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _focus.requestFocus();
  }

  // ─── 검색 (메모리 검색이라 빠르다. 입력이 멈추면 바로 실행) ──────────────

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _runSearch);
    setState(() {}); // ✕·✨ 버튼 상태
  }

  void _runSearch() {
    final q = _query;
    var found = q.isEmpty
        ? const <Staff>[]
        : searchLocal(
            AppData.instance.all,
            q,
            namesOnly: _searchMode == 1,
            includeTitle: AuthService.instance.isStaff,
            includeCell: AuthService.instance.isStaff,
          );
    // 문장으로 입력하면(예: "장학금 담당자가 누구야") 키워드로 다시 찾는다
    if (found.isEmpty && q.contains(' ')) {
      final keywords = extractKeywords(q);
      if (keywords.isNotEmpty) {
        found = searchLocal(
          AppData.instance.all,
          keywords.first,
          includeTitle: AuthService.instance.isStaff,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _shownQuery = q;
      _results = found;
      _visible = _pageSize;
    });
  }

  void _onScroll() {
    if (_visible >= _results.length) return;
    if (_scroll.position.extentAfter < 600) {
      setState(() => _visible += _pageSize);
    }
  }

  void _clearInput() {
    _input.clear();
    _runSearch();
  }

  void _setMode(int mode) {
    if (_searchMode == mode) return;
    setState(() => _searchMode = mode);
    _runSearch();
  }

  // ─── AI ─────────────────────────────────────────────────────

  Future<void> ask([String? text]) async {
    final q = (text ?? _query).trim();
    if (q.isEmpty || _asking) return;
    _focus.unfocus();
    _input.clear();
    _runSearch();
    final exchange = AiExchange(q);
    setState(() {
      _exchanges.add(exchange);
      _asking = true;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    final answer = await AiChatService.instance.sendMessage(q);
    if (!mounted) return;
    setState(() {
      exchange.answer = answer;
      _asking = false;
    });
  }

  void clearChat() {
    AiChatService.instance.resetChat();
    setState(_exchanges.clear);
  }

  // ─── 화면 ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) => CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroTitle('누구에게 \n물어보면 될까요?'),
                  SizedBox(height: 6),
                  HeroSubtitle('이름·부서·업무로 찾거나 ✨로 AI에게 물어보세요.'),
                  SizedBox(height: 2),
                  DataNotice(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(child: _buildInputArea()),
          ),
          if (_exchanges.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(child: _buildAiSection()),
            ),
          ..._buildListSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final hasText = _query.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchInputCard(
          controller: _input,
          focusNode: _focus,
          onChanged: _onQueryChanged,
          onSubmitted: (_) => ask(),
          onClear: _clearInput,
          onAsk: hasText && !_asking ? ask : null,
          asking: _asking,
        ),
        const SizedBox(height: 10),
        if (hasText)
          Row(
            children: [
              ModeChip(
                label: '전체',
                selected: _searchMode == 0,
                onTap: () => _setMode(0),
              ),
              const SizedBox(width: 6),
              ModeChip(
                label: '이름·부서',
                selected: _searchMode == 1,
                onTap: () => _setMode(1),
              ),
              const Spacer(),
              if (isChoseongQuery(_query) || isPhoneQuery(_query))
                Text(
                  isPhoneQuery(_query) ? '전화번호 검색' : '초성 검색',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent(context),
                  ),
                ),
            ],
          )
        else if (_exchanges.isEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _examples)
                ActionChip(
                  avatar: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.accent(context),
                  ),
                  label: Text(q),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text(context),
                  ),
                  backgroundColor: AppColors.surface(context),
                  side: BorderSide(color: AppColors.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => ask(q),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildAiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'AI 안내',
          trailing: TextButton.icon(
            onPressed: _asking ? null : clearChat,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('대화 지우기'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.sub(context),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        // 최신 질문이 위에 오도록 거꾸로(입력창 바로 아래에서 답을 확인)
        for (final e in _exchanges.reversed) ...[
          AiExchangeView(exchange: e),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  List<Widget> _buildListSlivers() {
    const headerPadding = EdgeInsets.fromLTRB(20, 22, 20, 0);
    if (_shownQuery.isNotEmpty) {
      final shown = _results.take(_visible).toList();
      return [
        SliverPadding(
          padding: headerPadding,
          sliver: SliverToBoxAdapter(
            child: SectionHeader('검색 결과', count: _results.length),
          ),
        ),
        if (_results.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: EmptyCard(
                icon: Icons.search_off_rounded,
                title: '검색 결과가 없습니다',
                subtitle: '질문으로 입력하고 ✨를 누르면 AI가 찾아드려요',
                action: FilledButton.icon(
                  onPressed: _asking ? null : ask,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('AI에게 물어보기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          staffSliver(shown, highlight: _shownQuery),
      ];
    }

    final recents = AppData.instance.recents;
    return [
      if (recents.isNotEmpty) ...[
        SliverPadding(
          padding: headerPadding,
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              '최근 본 교직원',
              trailing: TextButton(
                onPressed: AppData.instance.clearRecents,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sub(context),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('지우기'),
              ),
            ),
          ),
        ),
        staffSliver(recents.take(5).toList()),
      ],
      SliverPadding(
        padding: headerPadding,
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('이렇게 써 보세요'),
              _buildTips(),
              const SizedBox(height: 12),
              // BETA: 걸려온 학교 번호 알림 켜기/끄기·권한·미리보기
              const CallerIdBetaCard(),
            ],
          ),
        ),
      ),
    ];
  }

  // 처음 쓰는 사람을 위한 사용 팁
  Widget _buildTips() {
    Widget tip(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientIconBox(icon, size: 34, iconSize: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.sub(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          tip(Icons.translate_rounded, '초성으로 찾기', 'ㄱㅁㅎ 처럼 이름 초성만 입력해도 찾아요'),
          tip(
            Icons.auto_awesome_rounded,
            'AI에게 묻기',
            '"휴학 신청은 어디에 문의해?"처럼 물어보고 ✨를 누르세요',
          ),
          tip(
            Icons.call_received_rounded,
            '걸려온 전화 확인',
            '모르는 번호면 0573 처럼 번호 일부를 입력해 누구인지 찾아보세요',
          ),
        ],
      ),
    );
  }
}

/// 교직원 카드 목록(Sliver). 찾기·즐겨찾기·부서 화면 공용
Widget staffSliver(
  List<Staff> list, {
  String highlight = '',
  bool showDepartmentLink = true,
}) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => StaffTile(
        staff: list[i],
        highlight: highlight,
        showDepartmentLink: showDepartmentLink,
      ),
    ),
  );
}

/// 입력 카드(알림메모 InputCard 와 같은 모양). 포커스되면 테두리·그림자가 브랜드 색으로 바뀐다
class SearchInputCard extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  /// null 이면 ✨ 버튼 비활성(입력이 없거나 답을 기다리는 중)
  final VoidCallback? onAsk;
  final bool asking;

  const SearchInputCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onAsk,
    required this.asking,
  });

  @override
  State<SearchInputCard> createState() => _SearchInputCardState();
}

class _SearchInputCardState extends State<SearchInputCard> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = AppColors.accent(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focused ? accent.withAlpha(190) : AppColors.border(context),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.deepGreen.withAlpha(45),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ]
            : (isDark
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.deepGreen.withAlpha(16),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '교직원 검색 · AI 질문',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('home-input'),
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    color: AppColors.text(context),
                  ),
                  decoration: InputDecoration(
                    hintText: '이름, 부서, 업무 또는 질문',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF3D4A45)
                          : const Color(0xFFBCC6C1),
                      fontSize: 17,
                    ),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(2, 12, 8, 8),
                  ),
                ),
              ),
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  key: const Key('home-clear'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.danger,
                  tooltip: '지우기',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClear,
                ),
              const SizedBox(width: 2),
              Tooltip(
                message: 'AI에게 묻기',
                child: GestureDetector(
                  key: const Key('home-ask'),
                  onTap: widget.onAsk,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.onAsk == null && !widget.asking ? 0.35 : 1,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradientDiagonal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: widget.asking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 검색 범위 선택 칩(전체 / 이름·부서)
class ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: AppColors.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.sub(context),
          ),
        ),
      ),
    );
  }
}
