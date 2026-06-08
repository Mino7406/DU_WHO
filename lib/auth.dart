import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum UserRole { student, staff }

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  UserRole _role = UserRole.student;

  UserRole get role => _role;
  bool get isStaff => _role == UserRole.staff;

  static const _studentIds = {'22124206', '22124073', '22124248', '22124549'};

  bool login(String id, String password) {
    if (password != '12345') return false;
    if (_studentIds.contains(id)) {
      _role = UserRole.student;
      return true;
    }
    if (id == '32152') {
      _role = UserRole.staff;
      return true;
    }
    return false;
  }

  void logout() {
    _role = UserRole.student;
  }

  // ─── 자동 로그인 세션 ─────────────────────────────────────────

  // 세션 파일에서 역할을 복원 → 성공 시 true
  Future<bool> restoreSession() async {
    try {
      final file = await _sessionFile();
      if (!await file.exists()) return false;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _role = (data['role'] as String?) == 'staff'
          ? UserRole.staff
          : UserRole.student;
      return true;
    } catch (_) {
      return false;
    }
  }

  // 로그인 성공 후 "로그인 상태 유지"가 켜진 경우 호출
  Future<void> saveSession(String id) async {
    try {
      final file = await _sessionFile();
      await file.writeAsString(jsonEncode({
        'id': id,
        'role': isStaff ? 'staff' : 'student',
      }));
    } catch (_) {}
  }

  // 로그아웃 시 세션 삭제
  Future<void> clearSession() async {
    try {
      final file = await _sessionFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File> _sessionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'session.json'));
  }

  // ─── 권한별 필드 접근 ─────────────────────────────────────────

  // 학생: 교내전화(tel)만 표시, 개인 휴대전화(cellTel) 비표시
  String effectivePhone(String tel, String cellTel) {
    if (isStaff) return tel.isNotEmpty && tel != '0000' ? tel : cellTel;
    return tel.isNotEmpty && tel != '0000' ? tel : '';
  }

  // 학생: 위치 요약(건물명만), 교직원: 전체
  String effectiveLocation(String location) {
    if (isStaff) return location;
    final parts = location.trim().split(RegExp(r'\s+'));
    final summary = parts
        .takeWhile((p) => !p.contains(RegExp(r'\d')))
        .join(' ');
    return summary.isEmpty
        ? (parts.isNotEmpty ? parts.first : location)
        : summary;
  }
}
