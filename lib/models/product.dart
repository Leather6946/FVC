class Product {
  final int? id;
  final String name;
  final String processName;
  final double pieceRate;
  final String unit;
  final String? createdAt;

  Product({
    this.id,
    required this.name,
    required this.processName,
    required this.pieceRate,
    this.unit = '件',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'process_name': processName,
      'piece_rate': pieceRate,
      'unit': unit,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      processName: map['process_name'] as String? ?? '',
      pieceRate: (map['piece_rate'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? '件',
      createdAt: map['created_at'] as String?,
    );
  }

  String get displayName =>
      '$name - $processName (¥${pieceRate.toStringAsFixed(2)}/$unit)';
}
