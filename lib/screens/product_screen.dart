import 'package:flutter/material.dart';
import '../models/product_type.dart';
import '../models/process_model.dart';
import '../database/database_helper.dart';

/// 工序管理 — 以产品类型分组，每个类型下有不同的工序
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _db = DatabaseHelper();
  List<ProductType> _types = [];
  Map<int, List<ProcessModel>> _processes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final types = await _db.getProductTypes();
    final procMap = <int, List<ProcessModel>>{};
    for (final t in types) {
      if (t.id != null) {
        procMap[t.id!] = await _db.getProcesses(productTypeId: t.id);
      }
    }
    if (mounted) {
      setState(() {
        _types = types;
        _processes = procMap;
        _loading = false;
      });
    }
  }

  // ========== 产品类型 CRUD ==========

  Future<void> _showTypeForm([ProductType? type]) async {
    final ctrl = TextEditingController(text: type?.name ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == null ? '添加产品类型' : '编辑产品类型'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '产品名称 *',
            border: OutlineInputBorder(),
            hintText: '如: 手提袋',
          ),
          autofocus: true,
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
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      if (type == null) {
        await _db.insertProductType(
            ProductType(name: ctrl.text.trim(), createdAt: DateTime.now().toIso8601String()));
      } else {
        await _db.updateProductType(ProductType(id: type.id, name: ctrl.text.trim()));
      }
      _load();
    }
    ctrl.dispose();
  }

  Future<void> _deleteType(ProductType type) async {
    if (type.id == null) return;
    final procs = _processes[type.id] ?? [];
    final msg = procs.isNotEmpty
        ? '产品类型「${type.name}」下有 ${procs.length} 个工序，确定一并删除？'
        : '确定删除产品类型「${type.name}」？';
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
      await _db.deleteProductType(type.id!);
      _load();
    }
  }

  // ========== 工序 CRUD ==========

  Future<void> _showProcessForm(ProductType parentType, [ProcessModel? proc]) async {
    final nameCtrl = TextEditingController(text: proc?.name ?? '');
    final rateCtrl = TextEditingController(
        text: proc != null ? proc.pieceRate.toString() : '');
    final unitCtrl = TextEditingController(text: proc?.unit ?? '件');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(proc == null ? '添加工序' : '编辑工序'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('产品类型: ${parentType.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '工序名称 *',
                  border: OutlineInputBorder(),
                  hintText: '如: 车缝',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateCtrl,
                decoration: const InputDecoration(
                  labelText: '单价(元) *',
                  border: OutlineInputBorder(),
                  hintText: '如: 2.50',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: '单位',
                  border: OutlineInputBorder(),
                  hintText: '件',
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

    if (saved == true &&
        nameCtrl.text.trim().isNotEmpty &&
        rateCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      final data = ProcessModel(
        id: proc?.id,
        productTypeId: parentType.id!,
        name: nameCtrl.text.trim(),
        pieceRate: double.tryParse(rateCtrl.text.trim()) ?? 0,
        unit: unitCtrl.text.trim().isEmpty ? '件' : unitCtrl.text.trim(),
        createdAt: proc?.createdAt ?? now,
      );
      if (proc == null) {
        await _db.insertProcess(data);
      } else {
        await _db.updateProcess(data);
      }
      _load();
    }
    nameCtrl.dispose();
    rateCtrl.dispose();
    unitCtrl.dispose();
  }

  Future<void> _deleteProcess(ProcessModel proc) async {
    if (proc.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除工序「${proc.displayName}」？'),
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
      await _db.deleteProcess(proc.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('工序管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _types.isEmpty
              ? const Center(child: Text('暂无产品类型，点击右下角添加'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _types.length,
                    itemBuilder: (_, i) => _buildTypeCard(_types[i], theme),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showTypeForm(),
      ),
    );
  }

  Widget _buildTypeCard(ProductType type, ThemeData theme) {
    final procs = _processes[type.id] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child: Text(
            '${procs.length}',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          type.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${procs.length} 个工序'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showTypeForm(type),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteType(type),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          // 添加工序按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showProcessForm(type),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加此类型工序', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
          // 工序列表
          ...procs.map((proc) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 48, right: 8),
                title: Text(proc.name),
                subtitle: Text(
                    '¥${proc.pieceRate.toStringAsFixed(2)}/${proc.unit}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _showProcessForm(type, proc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => _deleteProcess(proc),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
