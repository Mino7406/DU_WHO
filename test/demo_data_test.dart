import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 저장소에 올리는 assets/staff_db.json 이 가상 인물만 담고 있는지 검사한다.
// 실제 교직원 데이터(개인정보)를 넣으면 이 테스트가 실패해서 커밋 전에 알아챌 수 있다.
void main() {
  final members =
      (jsonDecode(File('assets/staff_db.json').readAsStringSync())
              as Map<String, dynamic>)['memberSearchList']
          as List;

  test('교직원 데이터가 비어 있지 않다', () {
    expect(members, isNotEmpty);
  });

  test('모든 교직원이 가상 인물 규칙을 따른다', () {
    final tel = RegExp(r'^053-000-\d{4}$');
    final cell = RegExp(r'^010-0000-\d{4}$');
    for (final m in members.cast<Map<String, dynamic>>()) {
      final id = m['user_id'] as String? ?? '';
      expect(id, startsWith('demo'), reason: '가상 아이디가 아님: $id');
      for (final (key, pattern) in [('tel', tel), ('cell_tel', cell)]) {
        final v = m[key] as String? ?? '';
        if (v.isNotEmpty) {
          expect(pattern.hasMatch(v), isTrue, reason: '$id 의 $key 가 가상 번호가 아님: $v');
        }
      }
      final email = m['email'] as String? ?? '';
      if (email.isNotEmpty) {
        expect(email, endsWith('@example.com'), reason: '$id 의 메일이 가상 주소가 아님');
      }
    }
  });
}
