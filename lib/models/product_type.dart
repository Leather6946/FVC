class ProductType {
  final int? id;
  final String name;
  final String? createdAt;
  final int? processCount;

  ProductType({this.id, required this.name, this.createdAt, this.processCount});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory ProductType.fromMap(Map<String, dynamic> map) => ProductType(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        createdAt: map['created_at'] as String?,
        processCount: map['process_count'] as int?,
      );
}
