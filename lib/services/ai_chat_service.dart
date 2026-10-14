import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../auth.dart';
import '../db/database_helper.dart';
import '../staff_model.dart';

/// 서버가 돌려준 응답. 통신 계층을 갈아끼워 테스트할 수 있게 값만 담는다.
class AiHttpResponse {
  final int status;
  final String body;
  const AiHttpResponse(this.status, this.body);
}

// 실제 통신을 하는 함수의 모양. 테스트에서는 가짜 함수로 바꿔 끼운다
typedef AiTransport =
    Future<AiHttpResponse> Function(
      Uri url,
      String jsonBody,
      Map<String, String> headers,
    );

// 키워드 하나로 교직원을 찾는 함수의 모양. 기본은 로컬 SQLite 검색
typedef StaffSearch = Future<List<Staff>> Function(String keyword);

/// 챗봇 답변. [staff] 는 답변 근거로 보낸 교직원(화면에서 바로 눌러 전화·상세)
class AiAnswer {
  final String text;
  final List<Staff> staff;

  /// false 면 서버를 못 써서 로컬 검색 결과로 만든 안내문
  final bool fromAi;
  const AiAnswer(this.text, this.staff, {required this.fromAi});
}

/// 교직원 안내 챗봇. 질문에서 키워드를 뽑아 로컬 DB를 검색하고, 그 결과와 최근 대화를
/// Cloudflare Workers AI 서버(worker/)로 보내 답변을 받는다.
/// 서버를 쓸 수 없으면 예외 대신 로컬 검색 결과로 만든 안내문을 돌려준다.
class AiChatService {
  static final AiChatService instance = AiChatService();

  // 챗봇 서버 주소(Cloudflare Workers). worker/ 를 배포한 주소와 맞춘다
  static final defaultEndpoint = Uri.parse(
    'https://du-who-ai.notimemo-ai.workers.dev/chat',
  );

  /// 서버로 보내는 최근 대화 개수(질문·답변 합계). worker MAX_HISTORY 와 같다
  static const maxHistory = 6;

  /// 서버가 받는 질문 최대 길이(worker MAX_QUESTION_LENGTH)
  static const maxQuestionLength = 300;

  /// 서버로 보내는 검색 결과 최대 인원(worker MAX_STAFF)
  static const maxStaff = 15;

  // 서버가 이 시간 안에 답하지 않으면 로컬 검색 결과로 대신한다
  static const timeout = Duration(seconds: 20);

  final Uri endpoint;
  final AiTransport _transport;
  final StaffSearch _search;

  // 서버로 보내는 대화 기록. DB 검색 결과는 넣지 않고 질문·답변 원문만 둔다
  final List<Map<String, String>> _history = [];

  AiChatService({Uri? endpoint, AiTransport? transport, StaffSearch? search})
    : endpoint = endpoint ?? defaultEndpoint,
      _transport = transport ?? _httpTransport,
      _search =
          search ??
          ((k) => DatabaseHelper.instance.searchStaff(
            k,
            0,
            includeTitle: AuthService.instance.isStaff,
          ));

  void resetChat() => _history.clear();

  /// 질문을 보내고 화면에 보여줄 답변과 근거 교직원을 돌려준다. 어떤 실패든 예외를 던지지 않는다.
  Future<AiAnswer> sendMessage(String userMessage) async {
    final question = userMessage.trim();
    final clipped = question.length > maxQuestionLength
        ? question.substring(0, maxQuestionLength)
        : question;
    final staff = await findRelevantStaff(clipped);

    String? failure;
    try {
      final body = jsonEncode({
        'question': clipped,
        'history': _history,
        'staff': staff.map(staffToContext).toList(),
      });
      final response = await _transport(endpoint, body, {
        'X-Device-Id': await _deviceId(),
      }).timeout(timeout);

      if (response.status == 200) {
        final reply = _parseReply(response.body);
        if (reply != null) {
          _remember(clipped, reply);
          return AiAnswer(reply, staff, fromAi: true);
        }
        failure = '응답을 처리할 수 없습니다.';
      } else {
        failure = _messageForError(response);
      }
    } on TimeoutException {
      failure = '응답 시간이 초과되었습니다.';
    } on SocketException {
      failure = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
    } on HandshakeException {
      failure = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
    } on http.ClientException {
      failure = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
    } catch (_) {
      failure = '응답을 처리할 수 없습니다.';
    }
    // 실패한 질문은 기록에 남기지 않는다(다음 질문의 맥락을 흐리지 않게)
    return AiAnswer(fallbackReply(failure, staff), staff, fromAi: false);
  }

  /// 질문 키워드로 교직원을 찾아 관련도 순으로 [maxStaff]명까지 돌려준다.
  Future<List<Staff>> findRelevantStaff(String question) async {
    final keywords = extractKeywords(question);
    if (keywords.isEmpty) return const [];
    final byKey = <String, Staff>{};
    for (final k in keywords) {
      for (final s in await _search(k)) {
        byKey['${s.id ?? s.userId}:${s.name}'] = s;
      }
    }
    return rankStaff(byKey.values.toList(), keywords).take(maxStaff).toList();
  }

  void _remember(String question, String reply) {
    _history
      ..add({'role': 'user', 'content': question})
      ..add({'role': 'assistant', 'content': reply});
    if (_history.length > maxHistory) {
      _history.removeRange(0, _history.length - maxHistory);
    }
  }

  String? _parseReply(String body) {
    try {
      final json = jsonDecode(body);
      final reply = json is Map ? json['reply'] : null;
      return reply is String && reply.trim().isNotEmpty ? reply.trim() : null;
    } catch (_) {
      return null;
    }
  }

  // 서버가 보낸 오류 코드를 사용자에게 보여줄 문구로 바꾼다
  String _messageForError(AiHttpResponse response) {
    if (response.status == 429) {
      try {
        final code = (jsonDecode(response.body) as Map)['error'];
        if (code == 'quota_exceeded') return '오늘 AI 사용량이 모두 소진되었습니다.';
      } catch (_) {
        // 본문을 못 읽으면 일반적인 횟수 제한으로 본다.
      }
      return '요청이 너무 잦습니다. 잠시 후 다시 시도해주세요.';
    }
    // 404: 서버 주소에 워커가 없음(배포 전·주소 변경)
    if (response.status == 404) return 'AI 서버를 찾을 수 없습니다. 잠시 후 다시 시도해주세요.';
    if (response.status >= 500) return 'AI 서버가 잠시 응답하지 않습니다.';
    return 'AI 요청을 처리하지 못했습니다. (오류 ${response.status})';
  }

  // 설치마다 한 번 만드는 무작위 id. 서버의 횟수 제한 키로만 쓴다
  static String? _cachedDeviceId;
  static Future<String> _deviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'device_id.txt'));
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) return _cachedDeviceId = saved;
      }
      final rnd = Random.secure();
      final id = List.generate(
        16,
        (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await file.writeAsString(id);
      return _cachedDeviceId = id;
    } catch (_) {
      return _cachedDeviceId = '';
    }
  }

  // 실제로 서버에 JSON을 POST로 보내는 기본 통신 함수
  static Future<AiHttpResponse> _httpTransport(
    Uri url,
    String jsonBody,
    Map<String, String> headers,
  ) async {
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=utf-8', ...headers},
      body: utf8.encode(jsonBody),
    );
    return AiHttpResponse(resp.statusCode, utf8.decode(resp.bodyBytes));
  }
}

// ─── 순수 함수 (테스트 대상) ───────────────────────────────────────

// 키워드 끝에 붙는 조사·어미. 긴 것부터 떼어낸다
const _particles = [
  '에서는',
  '에게서',
  '으로는',
  '한테서',
  '이에요',
  '입니다',
  '에서',
  '에게',
  '한테',
  '으로',
  '부터',
  '까지',
  '이랑',
  '이나',
  '이야',
  '인가',
  '이요',
  '께서',
  '은',
  '는',
  '이',
  '가',
  '을',
  '를',
  '에',
  '의',
  '와',
  '과',
  '도',
  '로',
  '랑',
  '요',
  '야',
];

// 질문에 흔히 붙지만 검색에는 도움이 안 되는 말
const _stopwords = {
  '누구',
  '누가',
  '누군',
  '어디',
  '어디서',
  '어떻게',
  '어느',
  '무엇',
  '무슨',
  '뭐',
  '뭔가',
  '알려줘',
  '알려주세요',
  '알려',
  '주세요',
  '해줘',
  '해주세요',
  '있어',
  '있나',
  '있나요',
  '있는',
  '담당자',
  '담당',
  '담당하는',
  '연락처',
  '전화번호',
  '번호',
  '전화',
  '이메일',
  '메일',
  '위치',
  '궁금',
  '궁금해',
  '궁금해요',
  '문의',
  '하고',
  '싶어',
  '싶은데',
  '싶어요',
  '대한',
  '관련',
  '하는',
  '사람',
  '분',
  '좀',
  '그',
  '저',
  '제',
  '우리',
  '대구대',
  '대구대학교',
  '학교',
  '교직원',
  '업무',
  '부서',
  '문의해',
  '문의하',
  '연락해',
  '알고',
  '맡은',
  '맡고',
  '어디야',
  '누구야',
  '뭐야',
  '인가요',
  '나요',
  '건가요',
};

/// 질문을 검색 키워드로 바꾼다. "장학금 담당자가 누구야?" → ["장학금"]
List<String> extractKeywords(String question) {
  final tokens = question
      .split(RegExp(r'[^0-9A-Za-z가-힣]+'))
      .where((t) => t.isNotEmpty);
  final out = <String>[];
  for (var t in tokens) {
    if (_stopwords.contains(t)) continue;
    for (final suffix in _particles) {
      if (t.endsWith(suffix) && t.length - suffix.length >= 2) {
        t = t.substring(0, t.length - suffix.length);
        break;
      }
    }
    if (t.length < 2 || _stopwords.contains(t) || out.contains(t)) continue;
    out.add(t);
    if (out.length == 5) break;
  }
  return out;
}

/// 키워드가 걸린 위치로 점수를 매겨 관련도 순으로 정렬한다(이름 > 부서 > 담당업무 > 직함).
List<Staff> rankStaff(List<Staff> candidates, List<String> keywords) {
  int score(Staff s) {
    var total = 0;
    for (final k in keywords) {
      if (s.name == k) {
        total += 10;
      } else if (s.name.contains(k)) {
        total += 5;
      }
      if (s.department.contains(k)) total += 3;
      if (s.chargeBusiness.contains(k)) total += 2;
      if (s.title.contains(k)) total += 1;
    }
    return total;
  }

  final scored = [for (final s in candidates) (staff: s, score: score(s))]
    ..sort((a, b) => b.score - a.score);
  return [
    for (final e in scored)
      if (e.score > 0) e.staff,
  ];
}

/// 서버로 보낼 교직원 정보. 역할에 따라 거르고, 개인 휴대폰 번호는 보내지 않는다.
Map<String, String> staffToContext(Staff s, {AuthService? auth}) {
  final a = auth ?? AuthService.instance;
  final tel = s.tel.isNotEmpty && s.tel != '0000' ? s.tel : '';
  final location = s.location.isEmpty ? '' : a.effectiveLocation(s.location);
  return {
    'name': s.name,
    if (s.department.isNotEmpty) 'department': s.department,
    if (a.isStaff && s.title.isNotEmpty) 'title': s.title,
    if (s.chargeBusiness.isNotEmpty) 'duty': s.chargeBusiness,
    if (tel.isNotEmpty) 'tel': tel,
    if (s.email.isNotEmpty) 'email': s.email,
    if (location.isNotEmpty) 'location': location,
  };
}

/// AI 서버를 못 쓸 때 보여줄 안내. 로컬 검색 결과가 있으면 함께 보여준다.
String fallbackReply(String reason, List<Staff> staff) {
  final b = StringBuffer(reason);
  if (staff.isEmpty) {
    b.write('\n\n"교직원 검색"에서 부서명이나 업무 키워드로 찾아보세요.');
    return b.toString();
  }
  b.write('\n\n대신 교직원 DB에서 찾은 결과입니다.');
  for (final s in staff.take(5)) {
    b.write('\n• ${s.name}');
    if (s.department.isNotEmpty) b.write(' (${s.department})');
    if (s.tel.isNotEmpty && s.tel != '0000') b.write(' ${s.tel}');
  }
  return b.toString();
}
