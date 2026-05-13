class Staff {
  final int? id;
  final String userId;
  final String name;
  final String department;
  final String title;
  final String tel;
  final String cellTel;
  final String location;
  final String email;
  final String chargeBusiness;

  Staff({
    this.id,
    required this.userId,
    required this.name,
    required this.department,
    required this.title,
    required this.tel,
    required this.cellTel,
    required this.location,
    required this.email,
    required this.chargeBusiness,
  });

  // 학교 포털 JSON (memberSearchList 항목) → Staff. 시드 단계에서만 사용.
  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      userId: json['user_id'] ?? '',
      name: json['user_nm'] ?? '',
      department: json['user_dept_name'] ?? '',
      title: json['title'] ?? '',
      tel: json['tel'] ?? '',
      cellTel: json['cell_tel'] ?? '',
      location: json['work_place_nm'] ?? '',
      email: json['email'] ?? '',
      chargeBusiness: json['charge_business'] ?? '',
    );
  }

  factory Staff.fromMap(Map<String, Object?> m) {
    return Staff(
      id: m['id'] as int?,
      userId: (m['user_id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      department: (m['department'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      tel: (m['tel'] as String?) ?? '',
      cellTel: (m['cell_tel'] as String?) ?? '',
      location: (m['location'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      chargeBusiness: (m['charge_business'] as String?) ?? '',
    );
  }

  // id 는 AUTOINCREMENT 라 INSERT 시 포함하지 않음
  Map<String, Object?> toMap() => {
        'user_id': userId,
        'name': name,
        'department': department,
        'title': title,
        'tel': tel,
        'cell_tel': cellTel,
        'location': location,
        'email': email,
        'charge_business': chargeBusiness,
      };

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return name.contains(q) ||
        department.toLowerCase().contains(q) ||
        title.toLowerCase().contains(q) ||
        chargeBusiness.toLowerCase().contains(q);
  }
}
