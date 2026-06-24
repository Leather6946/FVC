import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../database/database_helper.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _db = DatabaseHelper();
  List<Employee> _employees = [];
  bool _loading = true;

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  int? _editId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getEmployees();
    if (mounted) {
      setState(() {
        _employees = list;
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _codeCtrl.clear();
    _phoneCtrl.clear();
    _deptCtrl.clear();
    _editId = null;
  }

  Future<void> _showForm([Employee? emp]) async {
    _resetForm();
    if (emp != null) {
      _editId = emp.id;
      _nameCtrl.text = emp.name;
      _codeCtrl.text = emp.code ?? '';
      _phoneCtrl.text = emp.phone ?? '';
      _deptCtrl.text = emp.department ?? '';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(emp == null ? '添加员工' : '编辑员工'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '姓名 *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: '工号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: '电话',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _deptCtrl,
                decoration: const InputDecoration(
                  labelText: '部门',
                  border: OutlineInputBorder(),
                ),
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

    if (saved == true && _nameCtrl.text.trim().isNotEmpty) {
      final e = Employee(
        id: _editId,
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        department: _deptCtrl.text.trim().isEmpty
            ? null
            : _deptCtrl.text.trim(),
        hireDate: DateTime.now().toIso8601String().split('T')[0],
        createdAt: DateTime.now().toIso8601String(),
      );
      if (_editId != null) {
        e.id; // force id access
      }
      if (emp == null) {
        await _db.insertEmployee(e);
      } else {
        await _db.updateEmployee(e);
      }
      _load();
    }
  }

  Future<void> _delete(Employee emp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除员工「${emp.name}」吗？'),
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
      await _db.deleteEmployee(emp.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('员工管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
          ? const Center(child: Text('暂无员工，点击右下角添加'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (_, i) {
                  final e = _employees[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          e.name.isNotEmpty ? e.name[0] : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        e.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '工号: ${e.code ?? "-"}  部门: ${e.department ?? "-"}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showForm(e),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => _delete(e),
                          ),
                        ],
                      ),
                      onTap: () => _showForm(e),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () => _showForm(),
      ),
    );
  }
}
