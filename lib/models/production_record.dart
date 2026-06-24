class ProductionRecord {
  final int? id;
  final int employeeId;
  final int productId;
  final double quantity;
  final String recordDate;
  final String? note;
  final String? createdAt;

  // Joined fields
  final String? employeeName;
  final String? productName;
  final String? processName;
  final double? pieceRate;
  final String? unit;

  ProductionRecord({
    this.id,
    required this.employeeId,
    required this.productId,
    required this.quantity,
    required this.recordDate,
    this.note,
    this.createdAt,
    this.employeeName,
    this.productName,
    this.processName,
    this.pieceRate,
    this.unit,
  });

  double get wage => quantity * (pieceRate ?? 0);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'product_id': productId,
      'quantity': quantity,
      'record_date': recordDate,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory ProductionRecord.fromMap(Map<String, dynamic> map) {
    return ProductionRecord(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      recordDate: map['record_date'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String?,
      employeeName: map['employee_name'] as String?,
      productName: map['product_name'] as String?,
      processName: map['process_name'] as String?,
      pieceRate: (map['piece_rate'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
    );
  }
}
