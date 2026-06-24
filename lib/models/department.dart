class Department {
  final int? id;
  final String name;
  final String? createdAt;

  Department({this.id, required this.name, this.createdAt});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory Department.fromMap(Map<String, dynamic> map) => Department(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        createdAt: map['created_at'] as String?,
      );
}
