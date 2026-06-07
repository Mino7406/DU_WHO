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
