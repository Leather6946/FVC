class ProductionRecord {
  final int? id;
  final int employeeId;
  final int processId;
  final double quantity;
  final String recordDate;
  final String? note;
  final String? createdAt;

  // Joined fields
  final String? employeeName;
  final String? productTypeName;
  final String? processName;
  final double? pieceRate;
  final String? unit;

  ProductionRecord({
    this.id,
    required this.employeeId,
    required this.processId,
    required this.quantity,
    required this.recordDate,
    this.note,
    this.createdAt,
    this.employeeName,
    this.productTypeName,
    this.processName,
    this.pieceRate,
    this.unit,
  });

  double get wage => quantity * (pieceRate ?? 0);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'employee_id': employeeId,
        'process_id': processId,
        'quantity': quantity,
        'record_date': recordDate,
        'note': note,
        'created_at': createdAt,
      };

  factory ProductionRecord.fromMap(Map<String, dynamic> map) =>
      ProductionRecord(
        id: map['id'] as int?,
        employeeId: map['employee_id'] as int,
        processId: map['process_id'] as int,
        quantity: (map['quantity'] as num).toDouble(),
        recordDate: map['record_date'] as String,
        note: map['note'] as String?,
        createdAt: map['created_at'] as String?,
        employeeName: map['employee_name'] as String?,
        productTypeName: map['product_type_name'] as String?,
        processName: map['process_name'] as String?,
        pieceRate: (map['piece_rate'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
      );
}
