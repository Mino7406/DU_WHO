import 'dart:async';
import 'dart:convert';

import 'package:du_who/auth.dart';
import 'package:du_who/services/ai_chat_service.dart';
import 'package:du_who/staff_model.dart';
import 'package:flutter_test/flutter_test.dart';

Staff staff({
  int id = 1,
  String name = '홍길동',
  String department = '학생지원팀',
  String title = '팀장',
  String tel = '053-850-1234',
  String cellTel = '010-1111-2222',
  String location = '본관 101호',
  String email = 'hong@daegu.ac.kr',
  String duty = '장학금',
}) => Staff(
  id: id,
  userId: 'u$id',
  name: name,
  department: department,
  title: title,
  tel: tel,
  cellTel: cellTel,
  location: location,
  email: email,
  chargeBusiness: duty,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('extractKeywords', () {
    test('조사와 질문 말을 떼고 핵심어만 남긴다', () {
      expect(extractKeywords('장학금 담당자가 누구야?'), ['장학금']);
      expect(extractKeywords('총무부 연락처 알려줘'), ['총무부']);
      expect(extractKeywords('학생지원팀에서 휴학 업무는 누가 해?'), ['학생지원팀', '휴학']);
      expect(extractKeywords('수강신청 관련 문의는 어느 부서야?'), ['수강신청']);
    });

    test('중복·한 글자는 버리고 최대 5개', () {
      expect(extractKeywords('장학금 장학금을 장학금이'), ['장학금']);
      expect(extractKeywords('a 가 나'), isEmpty);
      expect(extractKeywords('일번 이번 삼번 사번 오번 육번').length, 5);
    });

    test('키워드가 없으면 빈 목록', () {
      expect(extractKeywords('누구야?'), isEmpty);
      expect(extractKeywords('   '), isEmpty);
    });
  });

  test('rankStaff: 이름 일치 > 부서 > 담당업무 순, 안 걸리면 제외', () {
    final byDuty = staff(id: 1, name: '갑', department: '총무팀', duty: '장학금');
    final byDept = staff(id: 2, name: '을', department: '장학금지원팀', duty: '');
    final byName = staff(id: 3, name: '장학금', department: 'x', duty: '');
    final none = staff(
      id: 4,
      name: '병',
      department: '총무팀',
      duty: '',
      title: '',
    );
    expect(rankStaff([byDuty, none, byDept, byName], ['장학금']), [
      byName,
      byDept,
      byDuty,
    ]);
  });

  group('staffToContext', () {
    tearDown(AuthService.instance.logout);

    test('교직원: 직위·전체 위치 포함, 휴대폰은 보내지 않는다', () {
      final m = staffToContext(staff());
      expect(m['title'], '팀장');
      expect(m['location'], '본관 101호');
      expect(m['tel'], '053-850-1234');
      expect(m.values.any((v) => v.contains('010-1111-2222')), isFalse);
    });

    test('학생: 직위 제외, 위치는 건물명만', () {
      expect(AuthService.instance.login('22124206', '12345'), isTrue);
      expect(AuthService.instance.isStaff, isFalse);
      final m = staffToContext(staff());
      expect(m.containsKey('title'), isFalse);
      expect(m['location'], '본관');
    });

    test('빈 값·0000 전화는 넣지 않는다', () {
      final m = staffToContext(staff(tel: '0000', email: '', location: ''));
      expect(m.keys, isNot(contains('tel')));
      expect(m.keys, isNot(contains('email')));
      expect(m.keys, isNot(contains('location')));
    });
  });

  group('sendMessage', () {
    late List<Map<String, dynamic>> sent;
    Future<List<Staff>> search(String k) async =>
        k == '장학금' ? [staff()] : const [];

    AiChatService service(AiTransport transport) =>
        AiChatService(transport: transport, search: search);

    setUp(() => sent = []);

    test('검색 결과와 질문을 보내고 답변을 돌려준다', () async {
      final s = service((url, body, headers) async {
        sent.add(jsonDecode(body) as Map<String, dynamic>);
        return const AiHttpResponse(200, '{"reply":"홍길동 선생님께 문의하세요."}');
      });
      expect((await s.sendMessage('장학금 담당자가 누구야?')).text, '홍길동 선생님께 문의하세요.');
      expect(sent.single['question'], '장학금 담당자가 누구야?');
      expect((sent.single['staff'] as List).single['name'], '홍길동');
      expect(sent.single['history'], isEmpty);
      expect(jsonEncode(sent.single), isNot(contains('010-1111-2222')));
    });

    test('대화 기록에는 질문·답변 원문만, 최근 6개까지', () async {
      var n = 0;
      final s = service((url, body, headers) async {
        sent.add(jsonDecode(body) as Map<String, dynamic>);
        return AiHttpResponse(200, '{"reply":"답${n++}"}');
      });
      for (var i = 0; i < 5; i++) {
        (await s.sendMessage('장학금 질문$i')).text;
      }
      final history = sent.last['history'] as List;
      expect(history.length, AiChatService.maxHistory);
      expect(history.first, {'role': 'user', 'content': '장학금 질문1'});
      expect(history.last, {'role': 'assistant', 'content': '답3'});
      expect(jsonEncode(history), isNot(contains('홍길동')));

      s.resetChat();
      (await s.sendMessage('장학금')).text;
      expect(sent.last['history'], isEmpty);
    });

    test('서버 오류면 로컬 검색 결과로 안내하고 기록에 남기지 않는다', () async {
      final s = service((url, body, headers) async {
        sent.add(jsonDecode(body) as Map<String, dynamic>);
        return const AiHttpResponse(502, '{"error":"ai_failed"}');
      });
      final reply = (await s.sendMessage('장학금 담당')).text;
      expect(reply, contains('AI 서버가 잠시 응답하지 않습니다'));
      expect(reply, contains('홍길동 (학생지원팀) 053-850-1234'));
      (await s.sendMessage('장학금')).text;
      expect(sent.last['history'], isEmpty);
    });

    test('한도 초과·횟수 제한은 알맞은 문구로', () async {
      expect(
        await service(
          (u, b, h) async =>
              const AiHttpResponse(429, '{"error":"quota_exceeded"}'),
        ).sendMessage('x').then((a) => a.text),
        startsWith('오늘 AI 사용량이 모두 소진되었습니다.'),
      );
      expect(
        await service(
          (u, b, h) async =>
              const AiHttpResponse(429, '{"error":"rate_limited"}'),
        ).sendMessage('x').then((a) => a.text),
        startsWith('요청이 너무 잦습니다.'),
      );
    });

    test('타임아웃·깨진 응답도 예외 없이 안내문', () async {
      final timeout = service((u, b, h) async => throw TimeoutException('t'));
      expect(
        (await timeout.sendMessage('장학금')).text,
        startsWith('응답 시간이 초과되었습니다.'),
      );
      final broken = service(
        (u, b, h) async => const AiHttpResponse(200, 'not json'),
      );
      expect(
        (await broken.sendMessage('x')).text,
        startsWith('응답을 처리할 수 없습니다.'),
      );
    });
  });
}
