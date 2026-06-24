import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/department.dart';
import '../database/database_helper.dart';
import 'ocr_employee_screen.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _db = DatabaseHelper();
  List<Employee> _employees = [];
  List<Department> _departments = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  int? _editId;
  int? _formDeptId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? keyword}) async {
    setState(() => _loading = true);
    final list = (keyword != null && keyword.isNotEmpty)
        ? await _db.searchEmployees(keyword)
        : await _db.getEmployees();
    final depts = await _db.getDepartments();
    if (mounted) {
      setState(() {
        _employees = list;
        _departments = depts;
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _codeCtrl.clear();
    _phoneCtrl.clear();
    _editId = null;
    _formDeptId = null;
  }

  // ========== 部门管理 ==========

  void _manageDepartments() {
    // 简单对话框：查看/添加部门
    showDialog(
      context: context,
      builder: (ctx) => _DepartmentManageDialog(
        db: _db,
        departments: _departments,
        onChanged: _load,
      ),
    );
  }

  // ========== 员工表单 ==========

  Future<void> _showForm([Employee? emp]) async {
    _resetForm();
    if (emp != null) {
      _editId = emp.id;
      _nameCtrl.text = emp.name;
      _codeCtrl.text = emp.code ?? '';
      _phoneCtrl.text = emp.phone ?? '';
      _formDeptId = emp.departmentId;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                DropdownButtonFormField<int>(
                  key: ValueKey('dept_$_formDeptId'),
                  initialValue: _formDeptId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '部门',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('无部门')),
                    ..._departments
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            )),
                  ],
                  onChanged: (v) => setDialogState(() => _formDeptId = v),
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
      ),
    );

    if (saved == true && _nameCtrl.text.trim().isNotEmpty) {
      // 找部门名
      String? deptName;
      if (_formDeptId != null) {
        final dept = _departments.where((d) => d.id == _formDeptId).firstOrNull;
        deptName = dept?.name;
      }
      final e = Employee(
        id: _editId,
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        department: deptName,
        departmentId: _formDeptId,
        hireDate: DateTime.now().toIso8601String().split('T')[0],
        createdAt: DateTime.now().toIso8601String(),
      );
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

  Future<void> _openOcr() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OcrEmployeeScreen()),
    );
    if (changed == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('员工管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: '部门管理',
            onPressed: _manageDepartments,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '拍照添加员工',
            onPressed: _openOcr,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索姓名或工号...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
              ),
              onChanged: (v) => _load(keyword: v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('暂无员工，点击右下角添加'))
                    : RefreshIndicator(
                        onRefresh: () => _load(keyword: _searchCtrl.text),
                        child: ListView.builder(
                          itemCount: _employees.length,
                          itemBuilder: (_, i) {
                            final e = _employees[i];
                            final deptName =
                                e.departmentName ?? e.department ?? '-';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Text(
                                    e.name.isNotEmpty ? e.name[0] : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '工号: ${e.code ?? "-"}  部门: $deptName',
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () => _showForm(),
      ),
    );
  }
}

/// 部门管理对话框
class _DepartmentManageDialog extends StatefulWidget {
  final DatabaseHelper db;
  final List<Department> departments;
  final VoidCallback onChanged;

  const _DepartmentManageDialog({
    required this.db,
    required this.departments,
    required this.onChanged,
  });

  @override
  State<_DepartmentManageDialog> createState() =>
      _DepartmentManageDialogState();
}

class _DepartmentManageDialogState extends State<_DepartmentManageDialog> {
  late List<Department> _depts;

  @override
  void initState() {
    super.initState();
    _depts = List.from(widget.departments);
  }

  Future<void> _addDept() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加部门'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '部门名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.db.insertDepartment(
        Department(name: name, createdAt: DateTime.now().toIso8601String()),
      );
      final updated = await widget.db.getDepartments();
      setState(() => _depts = updated);
      widget.onChanged();
    }
    ctrl.dispose();
  }

  Future<void> _deleteDept(Department d) async {
    final count = await widget.db.getDepartmentEmployeeCount(d.id!);
    final msg = count > 0
        ? '部门「${d.name}」下有 $count 名员工，确定删除？'
        : '确定删除部门「${d.name}」？';
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(msg),
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
      await widget.db.deleteDepartment(d.id!);
      final updated = await widget.db.getDepartments();
      setState(() => _depts = updated);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('部门管理'),
      content: SizedBox(
        width: double.maxFinite,
        child: _depts.isEmpty
            ? const Text('暂无部门，点击下方添加')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _depts.length,
                itemBuilder: (_, i) {
                  final d = _depts[i];
                  return ListTile(
                    dense: true,
                    title: Text(d.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => _deleteDept(d),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton.icon(
          onPressed: _addDept,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加部门'),
        ),
      ],
    );
  }
}
