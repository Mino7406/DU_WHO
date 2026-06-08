import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../db/database_helper.dart';

class GroqService {
  static final GroqService instance = GroqService._();
  GroqService._();

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _systemPrompt =
      '당신은 대구대학교 교직원 안내 챗봇입니다. '
      '교직원 DB 데이터를 바탕으로 어떤 부서에서 어떤 업무를 담당하는지 친절하게 안내해주세요. '
      '모르는 내용은 모른다고 솔직하게 말하고, 항상 한국어로 답변하세요. '
      '답변은 간결하고 명확하게 해주세요.';

  final List<Map<String, String>> _history = [];

  Future<String> sendMessage(String userMessage) async {
    final context = await _buildContext(userMessage);
    final prompt = context.isEmpty
        ? userMessage
        : '【교직원 DB 참고 데이터】\n$context\n\n【질문】$userMessage';

    _history.add({'role': 'user', 'content': prompt});

    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ..._history,
    ];

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'model': _model, 'messages': messages}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _history.removeLast();
      throw Exception('응답 시간이 초과되었습니다.\n네트워크 연결 상태와 VPN을 확인해주세요.');
    } on SocketException {
      _history.removeLast();
      throw Exception('서버에 연결할 수 없습니다.\nVPN이 켜져 있으면 꺼주세요.\n(Groq API가 VPN 환경에서 차단될 수 있습니다.)');
    }

    if (response.statusCode != 200) {
      _history.removeLast();
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    try {
      final decoded = jsonDecode(response.body);
      final reply = decoded['choices'][0]['message']['content'] as String;
      _history.add({'role': 'assistant', 'content': reply});
      return reply;
    } catch (_) {
      _history.removeLast();
      throw Exception('응답을 처리할 수 없습니다. 다시 시도해주세요.');
    }
  }

  void resetChat() => _history.clear();

  Future<String> _buildContext(String query) async {
    final results = await DatabaseHelper.instance.searchStaff(query, 0);
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    for (final s in results.take(20)) {
      buffer.write('이름: ${s.name}');
      if (s.department.isNotEmpty) buffer.write(', 부서: ${s.department}');
      if (s.title.isNotEmpty) buffer.write(', 직함: ${s.title}');
      if (s.chargeBusiness.isNotEmpty) {
        buffer.write(', 담당업무: ${s.chargeBusiness}');
      }
      if (s.tel.isNotEmpty && s.tel != '0000') buffer.write(', 전화: ${s.tel}');
      if (s.email.isNotEmpty) buffer.write(', 이메일: ${s.email}');
      if (s.location.isNotEmpty) buffer.write(', 위치: ${s.location}');
      buffer.writeln();
    }
    return buffer.toString();
  }
}
