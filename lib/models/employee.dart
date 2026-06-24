class Employee {
  final int? id;
  final String name;
  final String? code;
  final String? phone;
  final String? department;
  final int? departmentId;
  final String? departmentName;
  final String? hireDate;
  final String? createdAt;

  Employee({
    this.id,
    required this.name,
    this.code,
    this.phone,
    this.department,
    this.departmentId,
    this.departmentName,
    this.hireDate,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'phone': phone,
        'department': department,
        'department_id': departmentId,
        'hire_date': hireDate,
        'created_at': createdAt,
      };

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        code: map['code'] as String?,
        phone: map['phone'] as String?,
        department: map['department'] as String?,
        departmentId: map['department_id'] as int?,
        departmentName: map['department_name'] as String?,
        hireDate: map['hire_date'] as String?,
        createdAt: map['created_at'] as String?,
      );
}
