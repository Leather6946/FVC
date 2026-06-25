import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/product_type.dart';
import '../models/production_record.dart';
import '../database/database_helper.dart';

/// 计件查询 — 按员工、包袋种类、日期筛选查看记录
class RecordQueryScreen extends StatefulWidget {
  const RecordQueryScreen({super.key});

  @override
  State<RecordQueryScreen> createState() => _RecordQueryScreenState();
}

class _RecordQueryScreenState extends State<RecordQueryScreen> {
  final _db = DatabaseHelper();
  List<ProductionRecord> _records = [];
  List<Employee> _employees = [];
  List<ProductType> _productTypes = [];
  bool _loading = true;

  int? _filterEmployeeId;
  int? _filterProductTypeId;
  String? _filterStartDate;
  String? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _initMonthRange();
    _load();
  }

  void _initMonthRange() {
    final now = DateTime.now();
    _filterStartDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    _filterEndDate = DateFormat('yyyy-MM-dd').format(now);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final employees = await _db.getEmployees();
    final types = await _db.getProductTypes();
    final records = await _db.getRecords(
      employeeId: _filterEmployeeId,
      productTypeId: _filterProductTypeId,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );
    if (mounted) {
      setState(() {
        _employees = employees;
        _productTypes = types;
        _records = records;
        _loading = false;
      });
    }
  }

  Future<void> _editRecord(ProductionRecord record) async {
    String qty = record.quantity.toStringAsFixed(0);
    String note = record.note ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑记录'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${record.employeeName} - ${record.processName}  (${record.recordDate})',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                controller: TextEditingController(text: qty),
                onChanged: (v) => qty = v,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: note),
                onChanged: (v) => note = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newQty = double.tryParse(qty.trim());
      if (newQty == null || newQty <= 0) {
        _showSnackBar('请输入有效数量');
        return;
      }
      await _db.updateRecord(
        ProductionRecord(
          id: record.id,
          employeeId: record.employeeId,
          processId: record.processId,
          quantity: newQty,
          recordDate: record.recordDate,
          note: note.trim().isEmpty ? null : note.trim(),
        ),
      );
      _load();
      if (mounted) _showSnackBar('已更新');
    }
  }

  Future<void> _deleteRecord(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除此记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteRecord(id);
      _load();
      if (mounted) _showSnackBar('已删除');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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
      appBar: AppBar(
        title: const Text('计件查询'),
      ),
      body: Column(
        children: [
          // 筛选行
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('筛选条件', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('f_emp_$_filterEmployeeId'),
                        initialValue: _filterEmployeeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '员工',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('全部员工')),
                          ..._employees.map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterEmployeeId = v);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('f_ptype_$_filterProductTypeId'),
                        initialValue: _filterProductTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '包袋种类',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('全部种类')),
                          ..._productTypes.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterProductTypeId = v);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 20),
                      onPressed: () {
                        setState(() {
                          _filterEmployeeId = null;
                          _filterProductTypeId = null;
                          _initMonthRange();
                        });
                        _load();
                      },
                      tooltip: '清除筛选',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_filterStartDate ?? '开始日期',
                            style: const TextStyle(fontSize: 12)),
                        onPressed: () => _pickDate(true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('~', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_filterEndDate ?? '结束日期',
                            style: const TextStyle(fontSize: 12)),
                        onPressed: () => _pickDate(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // 统计摘要
          if (!_loading && _records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.summarize, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('共 ${_records.length} 条记录',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const Spacer(),
                  Text('合计 ¥${_records.fold<double>(0, (s, r) => s + r.wage).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          itemCount: _records.length,
                          itemBuilder: (_, i) {
                            final r = _records[i];
                            final displayName =
                                '${r.productTypeName ?? ""}${r.productTypeName != null ? " - " : ""}${r.processName ?? "?"}';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
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
                                  '${r.employeeName ?? "?"} - $displayName',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${r.recordDate}  x${r.quantity.toStringAsFixed(0)}${r.unit ?? ""}  = ¥${r.wage.toStringAsFixed(2)}${r.note != null ? "  (${r.note})" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _editRecord(r),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editRecord(r),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteRecord(r.id!),
                                    ),
                                  ],
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
