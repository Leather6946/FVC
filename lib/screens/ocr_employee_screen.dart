import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../database/database_helper.dart';
import '../models/employee.dart';

/// 混合模式：拍照 / 粘贴文本 → OCR → 人工确认 → 批量入库
class OcrEmployeeScreen extends StatefulWidget {
  const OcrEmployeeScreen({super.key});

  @override
  State<OcrEmployeeScreen> createState() => _OcrEmployeeScreenState();
}

class _OcrEmployeeScreenState extends State<OcrEmployeeScreen> {
  final _picker = ImagePicker();
  final _db = DatabaseHelper();

  XFile? _photo;
  String _rawText = '';
  List<_ParsedEmployee> _parsed = [];
  bool _processing = false;
  String? _error;
  final _pasteCtrl = TextEditingController();

  @override
  void dispose() {
    _pasteCtrl.dispose();
    for (final p in _parsed) {
      p.nameCtrl.dispose();
      p.codeCtrl.dispose();
      p.phoneCtrl.dispose();
      p.deptCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (photo != null) await _processPhoto(photo);
    } catch (e) {
      _setError('拍照失败: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo != null) await _processPhoto(photo);
    } catch (e) {
      _setError('选取图片失败: $e');
    }
  }

  Future<void> _processPhoto(XFile photo) async {
    setState(() {
      _photo = photo;
      _processing = true;
      _error = null;
      _rawText = '';
    });

    try {
      final text = await OcrService.recognizeText(photo);
      _processText(text);
    } catch (e) {
      _setError('OCR 识别失败: $e\n\n请尝试手动粘贴文本。');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showPasteDialog() {
    _pasteCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴员工名单'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: _pasteCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '将员工名单粘贴到这里\n格式示例:\n张三  EMP001  车缝组\n李四  13800002222  包装组',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final text = _pasteCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _photo = null;
                  _rawText = text;
                });
                _processText(text);
              }
            },
            child: const Text('解析'),
          ),
        ],
      ),
    );
  }

  void _processText(String text) {
    // 1. 先解析文本（纯函数，不会触发 rebuild）
    final parsed = OcrService.parseEmployees(text);
    // 2. 收集旧的 controller 待后续清理
    final oldList = List<_ParsedEmployee>.from(_parsed);
    // 3. 一次性更新状态
    setState(() {
      _rawText = text;
      _error = null;
      _parsed = parsed.map((m) => _ParsedEmployee.fromMap(m)).toList();
      if (parsed.isEmpty && text.trim().isNotEmpty) {
        _error = '未能从文本中解析出员工信息。\n'
            '请确保每行格式为：姓名 [工号] [电话] [部门]\n'
            '或点击「手动输入」逐条添加。';
      }
    });
    // 4. 等 rebuild 完成后再释放旧 controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in oldList) {
        p.nameCtrl.dispose();
        p.codeCtrl.dispose();
        p.phoneCtrl.dispose();
        p.deptCtrl.dispose();
      }
    });
  }

  Future<void> _saveAll() async {
    final validEmployees = <Employee>[];
    final errors = <String>[];

    for (int i = 0; i < _parsed.length; i++) {
      final p = _parsed[i];
      final name = p.nameCtrl.text.trim();
      if (name.isEmpty) {
        errors.add('第 ${i + 1} 行：姓名为空，已跳过');
        continue;
      }
      validEmployees.add(Employee(
        name: name,
        code: p.codeCtrl.text.trim().isEmpty
            ? null : p.codeCtrl.text.trim(),
        phone: p.phoneCtrl.text.trim().isEmpty
            ? null : p.phoneCtrl.text.trim(),
        department: p.deptCtrl.text.trim().isEmpty
            ? null : p.deptCtrl.text.trim(),
        hireDate: DateTime.now().toIso8601String().split('T')[0],
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    if (validEmployees.isEmpty) {
      _showSnackBar('没有有效的员工数据可保存');
      return;
    }

    int saved = 0;
    for (final emp in validEmployees) {
      await _db.insertEmployee(emp);
      saved++;
    }

    if (mounted) {
      _showSnackBar('成功保存 $saved 名员工'
          '${errors.isNotEmpty ? "（${errors.length} 条跳过）" : ""}');
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _setError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  void _removeItem(int index) {
    final p = _parsed[index];
    p.nameCtrl.dispose();
    p.codeCtrl.dispose();
    p.phoneCtrl.dispose();
    p.deptCtrl.dispose();
    setState(() => _parsed.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照添加员工'),
        actions: [
          if (_parsed.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              label: Text('保存 (${_parsed.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildActionBar(theme),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: const Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ActionChip(
              icon: Icons.camera_alt,
              label: '拍照',
              onTap: _takePhoto,
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.photo_library,
              label: '相册',
              onTap: _pickFromGallery,
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.content_paste,
              label: '粘贴文本',
              onTap: _showPasteDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_processing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在 OCR 识别...'),
          ],
        ),
      );
    }

    if (_error != null && _parsed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showPasteDialog,
                icon: const Icon(Icons.content_paste),
                label: const Text('粘贴文本试试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_parsed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '拍照识别员工名单',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支持格式：姓名 工号 电话 部门\n'
              '例如：张三 EMP001 13800001111 车缝组',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍照识别'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showPasteDialog,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('粘贴文本'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_photo != null || _rawText.isNotEmpty)
          _buildPreviewArea(theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '识别到 ${_parsed.length} 名员工',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _parsed.length,
            itemBuilder: (_, i) => _buildEmployeeCard(i, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(_photo!.path),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 60, height: 60,
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          if (_photo != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              _rawText.length > 120
                  ? '${_rawText.substring(0, 120)}...'
                  : _rawText,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 18),
            tooltip: '查看完整文本',
            onPressed: () => _showRawTextDialog(),
          ),
        ],
      ),
    );
  }

  void _showRawTextDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OCR 原始文本'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(_rawText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(int index, ThemeData theme) {
    final p = _parsed[index];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: p.nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '姓名 *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: p.codeCtrl,
                    decoration: const InputDecoration(
                      labelText: '工号',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: p.phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: '电话',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: p.deptCtrl,
              decoration: const InputDecoration(
                labelText: '部门',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ParsedEmployee {
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController deptCtrl;

  _ParsedEmployee({
    required this.nameCtrl,
    required this.codeCtrl,
    required this.phoneCtrl,
    required this.deptCtrl,
  });

  factory _ParsedEmployee.fromMap(Map<String, String> map) {
    return _ParsedEmployee(
      nameCtrl: TextEditingController(text: map['name'] ?? ''),
      codeCtrl: TextEditingController(text: map['code'] ?? ''),
      phoneCtrl: TextEditingController(text: map['phone'] ?? ''),
      deptCtrl: TextEditingController(text: map['department'] ?? ''),
    );
  }
}
