import '../staff_model.dart';

// 한글 초성 19자. 음절 코드에서 (code - 0xAC00) ~/ 588 번째가 초성이다
const _choseong = [
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];
final _choseongSet = _choseong.toSet();
final _nonDigit = RegExp(r'\D');
final _spaces = RegExp(r'\s+');
final _phoneChars = RegExp(r'^[\d\s+\-]+$');

/// 글자열의 초성만 뽑는다. 한글 음절이 아닌 글자는 그대로 둔다. "김민호" → "ㄱㅁㅎ"
String toChoseong(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0xAC00 && r <= 0xD7A3) {
      b.write(_choseong[(r - 0xAC00) ~/ 588]);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// 공백을 빼고 모두 초성(ㄱ~ㅎ)이면 초성 검색으로 본다. 한 글자(ㄱ)는 너무 넓어 제외
bool isChoseongQuery(String q) {
  final t = q.replaceAll(' ', '');
  return t.length >= 2 && t.split('').every(_choseongSet.contains);
}

/// 숫자 3자리 이상(하이픈·공백·+ 허용)이면 전화번호 검색
bool isPhoneQuery(String q) =>
    _phoneChars.hasMatch(q) && q.replaceAll(_nonDigit, '').length >= 3;

String _digits(String s) => s.replaceAll(_nonDigit, '');

/// 메모리에 올린 교직원 목록에서 찾는다. 관련도 순으로 돌려준다.
/// - 숫자만 입력(0573, 850-1234): 전화번호 일치 > 끝자리 > 포함. [includeCell]이면 휴대폰도 본다
/// - 초성만 입력(ㄱㅁㅎ): 이름 초성이 같음 > 그걸로 시작 > 포함
/// - 그 밖: 이름·부서·(직위)·담당업무에 포함. 공백으로 나눈 낱말은 모두 걸려야 한다(AND)
/// - [namesOnly]: 이름·부서만 본다 / [includeTitle]: false 면 직위로 찾지 않는다(학생)
/// 점수: 이름 일치 > 이름 시작 > 이름 포함 > 부서 > 담당업무 > 직위
List<Staff> searchLocal(
  List<Staff> all,
  String query, {
  bool namesOnly = false,
  bool includeTitle = true,
  bool includeCell = false,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  if (isPhoneQuery(q)) {
    final dq = _digits(q);
    final hits = <(Staff, int)>[];
    for (final s in all) {
      var score = 0;
      for (final n in [_digits(s.tel), if (includeCell) _digits(s.cellTel)]) {
        if (n.isEmpty || n == '0000') continue;
        if (n == dq) {
          score = 3;
        } else if (n.endsWith(dq) && score < 2) {
          score = 2;
        } else if (n.contains(dq) && score < 1) {
          score = 1;
        }
      }
      if (score > 0) hits.add((s, score));
    }
    return _sorted(hits);
  }

  if (isChoseongQuery(q)) {
    final cq = q.replaceAll(' ', '');
    final hits = <(Staff, int)>[];
    for (final s in all) {
      final c = toChoseong(s.name);
      if (c == cq) {
        hits.add((s, 3));
      } else if (c.startsWith(cq)) {
        hits.add((s, 2));
      } else if (c.contains(cq)) {
        hits.add((s, 1));
      }
    }
    return _sorted(hits);
  }

  final words = q.split(_spaces);
  final hits = <(Staff, int)>[];
  for (final s in all) {
    final name = s.name.toLowerCase();
    final dept = s.department.toLowerCase();
    final duty = namesOnly ? '' : s.chargeBusiness.toLowerCase();
    final title = namesOnly || !includeTitle ? '' : s.title.toLowerCase();
    var total = 0;
    var allMatched = true;
    for (final w in words) {
      var score = 0;
      if (name == w) {
        score = 100;
      } else if (name.startsWith(w)) {
        score = 60;
      } else if (name.contains(w)) {
        score = 40;
      }
      if (dept.contains(w)) score += dept == w ? 30 : 20;
      if (duty.contains(w)) score += 10;
      if (title.contains(w)) score += 5;
      if (score == 0) {
        allMatched = false;
        break;
      }
      total += score;
    }
    if (allMatched) hits.add((s, total));
  }
  return _sorted(hits);
}

List<Staff> _sorted(List<(Staff, int)> hits) {
  hits.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$1.name.compareTo(b.$1.name);
  });
  return [for (final h in hits) h.$1];
}

/// [text] 에서 [query] 낱말이 걸린 구간(시작, 끝). 강조 표시용.
/// 초성 검색이면 이름의 초성 구간, 전화번호 검색이면 숫자가 걸린 구간
List<(int, int)> matchRanges(String text, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty || text.isEmpty) return const [];
  if (isPhoneQuery(q)) {
    final dq = _digits(q);
    // 하이픈이 섞인 글자열에서 숫자만 따라가며 위치를 찾는다
    final digitPos = <int>[];
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) digitPos.add(i);
    }
    final i = String.fromCharCodes([
      for (final p in digitPos) text.codeUnitAt(p),
    ]).lastIndexOf(dq);
    if (i < 0) return const [];
    return [(digitPos[i], digitPos[i + dq.length - 1] + 1)];
  }
  if (isChoseongQuery(q)) {
    final cq = q.replaceAll(' ', '');
    final i = toChoseong(text).indexOf(cq);
    return i < 0 ? const [] : [(i, i + cq.length)];
  }
  final lower = text.toLowerCase();
  final ranges = <(int, int)>[];
  for (final w in q.split(_spaces)) {
    final i = lower.indexOf(w);
    if (i >= 0) ranges.add((i, i + w.length));
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  return ranges;
}

/// 부서 이름과 인원. 부서 탭 목록용
class DepartmentInfo {
  final String name;
  final List<Staff> members;
  const DepartmentInfo(this.name, this.members);
}

/// 교직원을 부서별로 묶는다. 부서 이름순, 부서 안은 이름순. 부서가 비어 있으면 '기타'
List<DepartmentInfo> groupByDepartment(List<Staff> all) {
  final map = <String, List<Staff>>{};
  for (final s in all) {
    final d = s.department.trim().isEmpty ? '기타' : s.department.trim();
    (map[d] ??= []).add(s);
  }
  final list = [
    for (final e in map.entries)
      DepartmentInfo(e.key, e.value..sort((a, b) => a.name.compareTo(b.name))),
  ]..sort((a, b) => a.name.compareTo(b.name));
  return list;
}
