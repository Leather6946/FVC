import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/product.dart';
import '../models/production_record.dart';
import '../database/database_helper.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _db = DatabaseHelper();
  List<ProductionRecord> _records = [];
  List<Employee> _employees = [];
  List<Product> _products = [];
  bool _loading = true;

  int? _filterEmployeeId;
  String? _filterStartDate;
  String? _filterEndDate;

  int? _formEmployeeId;
  int? _formProductId;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _formDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initMonthRange();
    _load();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _initMonthRange() {
    final now = DateTime.now();
    _filterStartDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    _filterEndDate = DateFormat('yyyy-MM-dd').format(now);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final employees = await _db.getEmployees();
    final products = await _db.getProducts();
    final records = await _db.getRecords(
      employeeId: _filterEmployeeId,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );
    if (mounted) {
      setState(() {
        _employees = employees;
        _products = products;
        _records = records;
        _loading = false;
      });
    }
  }

  Future<void> _submitRecord() async {
    if (_formEmployeeId == null || _formProductId == null) {
      _showSnackBar('请选择员工和工序');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      _showSnackBar('请输入有效数量');
      return;
    }

    final now = DateTime.now();
    final record = ProductionRecord(
      employeeId: _formEmployeeId!,
      productId: _formProductId!,
      quantity: qty,
      recordDate: DateFormat('yyyy-MM-dd').format(_formDate),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: now.toIso8601String(),
    );

    await _db.insertRecord(record);
    _qtyCtrl.clear();
    _noteCtrl.clear();
    _formEmployeeId = null;
    _formProductId = null;

    if (mounted) {
      _showSnackBar('记录成功！');
      _load();
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _deleteRecord(int id) async {
    await _db.deleteRecord(id);
    _load();
    if (mounted) _showSnackBar('已删除');
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024),
      lastDate: now,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      final ds = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isStart) {
          _filterStartDate = ds;
        } else {
          _filterEndDate = ds;
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('计件录入')),
      body: Column(
        children: [
          // 录入表单
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('新增记录', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _formEmployeeId,
                          decoration: const InputDecoration(
                            labelText: '员工',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: _employees
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _formEmployeeId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _formProductId,
                          decoration: const InputDecoration(
                            labelText: '工序',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: _products
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name}-${p.processName}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _formProductId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: '数量 *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _formDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              locale: const Locale('zh', 'CN'),
                            );
                            if (picked != null) {
                              setState(() => _formDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '日期',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(_formDate),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitRecord,
                      icon: const Icon(Icons.save),
                      label: const Text('保存记录'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 筛选行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_filterStartDate ?? '开始日期'),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('~'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_filterEndDate ?? '结束日期'),
                    onPressed: () => _pickDate(false),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    setState(() {
                      _filterEmployeeId = null;
                    });
                    _load();
                  },
                  tooltip: '清除筛选',
                ),
              ],
            ),
          ),

          // 记录列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('暂无记录'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (_, i) {
                        final r = _records[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                '${r.quantity.toInt()}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              '${r.employeeName ?? "?"} - ${r.processName ?? "?"}',
                            ),
                            subtitle: Text(
                              '${r.recordDate}  x${r.quantity.toStringAsFixed(0)}${r.unit ?? ""}  = ¥${r.wage.toStringAsFixed(2)}${r.note != null ? "  (${r.note})" : ""}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteRecord(r.id!),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
