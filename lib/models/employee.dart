class Employee {
  final int? id;
  final String name;
  final String? code;
  final String? phone;
  final String? department;
  final String? hireDate;
  final String? createdAt;

  Employee({
    this.id,
    required this.name,
    this.code,
    this.phone,
    this.department,
    this.hireDate,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'code': code,
      'phone': phone,
      'department': department,
      'hire_date': hireDate,
      'created_at': createdAt,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      code: map['code'] as String?,
      phone: map['phone'] as String?,
      department: map['department'] as String?,
      hireDate: map['hire_date'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
