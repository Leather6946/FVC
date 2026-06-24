import 'package:flutter/material.dart';
import '../models/product.dart';
import '../database/database_helper.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _db = DatabaseHelper();
  List<Product> _products = [];
  bool _loading = true;

  final _nameCtrl = TextEditingController();
  final _processCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  int? _editId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _processCtrl.dispose();
    _rateCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getProducts();
    if (mounted) {
      setState(() {
        _products = list;
        _loading = false;
      });
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _processCtrl.clear();
    _rateCtrl.clear();
    _unitCtrl.text = '件';
    _editId = null;
  }

  Future<void> _showForm([Product? prod]) async {
    _resetForm();
    if (prod != null) {
      _editId = prod.id;
      _nameCtrl.text = prod.name;
      _processCtrl.text = prod.processName;
      _rateCtrl.text = prod.pieceRate.toString();
      _unitCtrl.text = prod.unit;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prod == null ? '添加工序' : '编辑工序'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '产品名称 *',
                  border: OutlineInputBorder(),
                  hintText: '如: 手提袋',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _processCtrl,
                decoration: const InputDecoration(
                  labelText: '工序名称 *',
                  border: OutlineInputBorder(),
                  hintText: '如: 车缝',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rateCtrl,
                decoration: const InputDecoration(
                  labelText: '单价(元) *',
                  border: OutlineInputBorder(),
                  hintText: '如: 2.50',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _unitCtrl,
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
        _nameCtrl.text.trim().isNotEmpty &&
        _processCtrl.text.trim().isNotEmpty &&
        _rateCtrl.text.trim().isNotEmpty) {
      final p = Product(
        id: _editId,
        name: _nameCtrl.text.trim(),
        processName: _processCtrl.text.trim(),
        pieceRate: double.tryParse(_rateCtrl.text.trim()) ?? 0,
        unit: _unitCtrl.text.trim().isEmpty ? '件' : _unitCtrl.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );
      if (prod == null) {
        await _db.insertProduct(p);
      } else {
        await _db.updateProduct(p);
      }
      _load();
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除工序「${p.name} - ${p.processName}」吗？'),
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
      await _db.deleteProduct(p.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工序管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text('暂无工序，点击右下角添加'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (_, i) {
                  final p = _products[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                        child: Text(
                          '¥',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${p.name} - ${p.processName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '单价: ¥${p.pieceRate.toStringAsFixed(2)}/${p.unit}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showForm(p),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => _delete(p),
                          ),
                        ],
                      ),
                      onTap: () => _showForm(p),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(),
      ),
    );
  }
}
