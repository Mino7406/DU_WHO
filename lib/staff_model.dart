class Staff {
  final String name;
  final String department;
  final String title;
  final String tel;
  final String cellTel;
  final String location;
  final String email;
  final String chargeBusiness;
  final String userId;

  Staff({
    required this.name,
    required this.department,
    required this.title,
    required this.tel,
    required this.cellTel,
    required this.location,
    required this.email,
    required this.chargeBusiness,
    required this.userId,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      name: json['user_nm'] ?? '',
      department: json['user_dept_name'] ?? '',
      title: json['title'] ?? '',
      tel: json['tel'] ?? '',
      cellTel: json['cell_tel'] ?? '',
      location: json['work_place_nm'] ?? '',
      email: json['email'] ?? '',
      chargeBusiness: json['charge_business'] ?? '',
      userId: json['user_id'] ?? '',
    );
  }

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return name.contains(q) ||
        department.toLowerCase().contains(q) ||
        title.toLowerCase().contains(q) ||
        chargeBusiness.toLowerCase().contains(q);
  }
}
