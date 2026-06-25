import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/process_model.dart';
import '../models/product_type.dart';
import '../models/production_record.dart';
import '../database/database_helper.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _db = DatabaseHelper();
  List<Employee> _employees = [];
  List<ProductType> _productTypes = [];
  List<ProcessModel> _allProcesses = [];

  int? _formEmployeeId;
  int? _formProductTypeId;
  int? _formProcessId;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _formDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    final employees = await _db.getEmployees();
    final types = await _db.getProductTypes();
    final processes = await _db.getProcesses();
    if (mounted) {
      setState(() {
        _employees = employees;
        _productTypes = types;
        _allProcesses = processes;
      });
    }
  }

  List<ProcessModel> get _filteredProcesses {
    if (_formProductTypeId == null) return [];
    return _allProcesses
        .where((p) => p.productTypeId == _formProductTypeId)
        .toList();
  }

  Future<void> _submitRecord() async {
    if (_formEmployeeId == null || _formProcessId == null) {
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
      processId: _formProcessId!,
      quantity: qty,
      recordDate: DateFormat('yyyy-MM-dd').format(_formDate),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: now.toIso8601String(),
    );

    await _db.insertRecord(record);
    _qtyCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _formEmployeeId = null;
      _formProductTypeId = null;
      _formProcessId = null;
      _formDate = DateTime.now();
    });

    if (mounted) {
      _showSnackBar('✅ 记录成功！');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('计件录入'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('新增记录',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('emp_$_formEmployeeId'),
                          initialValue: _formEmployeeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '员工 *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          items: _employees
                              .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _formEmployeeId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('ptype_$_formProductTypeId'),
                          initialValue: _formProductTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '产品类型 *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          items: _productTypes
                              .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _formProductTypeId = v;
                              _formProcessId = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('proc_$_formProcessId'),
                          initialValue: _formProcessId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '工序 *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          items: _filteredProcesses
                              .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _formProcessId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: '数量 *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
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
                                  horizontal: 8, vertical: 8),
                              isDense: true,
                            ),
                            child: Text(
                                DateFormat('yyyy-MM-dd').format(_formDate),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _submitRecord,
                      icon: const Icon(Icons.save),
                      label: const Text('保存记录',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
