class ProcessModel {
  final int? id;
  final int productTypeId;
  final String name;
  final double pieceRate;
  final String unit;
  final String? createdAt;

  // joined
  final String? productTypeName;

  ProcessModel({
    this.id,
    required this.productTypeId,
    required this.name,
    required this.pieceRate,
    this.unit = '件',
    this.createdAt,
    this.productTypeName,
  });

  String get displayName =>
      '${productTypeName ?? "?"} - $name (¥${pieceRate.toStringAsFixed(2)}/$unit)';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_type_id': productTypeId,
        'name': name,
        'piece_rate': pieceRate,
        'unit': unit,
        'created_at': createdAt,
      };

  factory ProcessModel.fromMap(Map<String, dynamic> map) => ProcessModel(
        id: map['id'] as int?,
        productTypeId: map['product_type_id'] as int,
        name: map['name'] as String? ?? '',
        pieceRate: (map['piece_rate'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit'] as String? ?? '件',
        createdAt: map['created_at'] as String?,
        productTypeName: map['product_type_name'] as String?,
      );
}
