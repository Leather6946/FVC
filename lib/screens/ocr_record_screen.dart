import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/ocr_service.dart';
import '../database/database_helper.dart';
import '../models/employee.dart';
import '../models/process_model.dart';
import '../models/production_record.dart';

/// 混合模式：拍照 / 粘贴文本 -> OCR -> 人工确认 -> 批量入库（计件记录）
class OcrRecordScreen extends StatefulWidget {
  const OcrRecordScreen({super.key});

  @override
  State<OcrRecordScreen> createState() => _OcrRecordScreenState();
}

class _OcrRecordScreenState extends State<OcrRecordScreen> {
  final _picker = ImagePicker();
  final _db = DatabaseHelper();

  List<Employee> _employees = [];
  List<ProcessModel> _processes = [];
  bool _dataLoaded = false;

  XFile? _photo;
  String _rawText = '';
  List<_ParsedRecord> _parsed = [];
  bool _processing = false;
  String? _error;
  final _pasteCtrl = TextEditingController();
  final DateTime _defaultDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    for (final p in _parsed) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final employees = await _db.getEmployees();
    final processes = await _db.getProcesses();
    if (mounted) {
      setState(() {
        _employees = employees;
        _processes = processes;
        _dataLoaded = true;
      });
    }
  }

  // ==================== 输入方式 ====================

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
        title: const Text('粘贴计件记录'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: _pasteCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '将计件记录粘贴到这里\n'
                  '格式示例:\n'
                  '张三 车缝 150\n'
                  '李四 包装 200\n'
                  '王五 车缝 180',
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

  // ==================== 文本解析 ====================

  void _processText(String text) {
    final oldList = List<_ParsedRecord>.from(_parsed);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final parsed = <_ParsedRecord>[];

    for (final line in lines) {
      final record = _parseLine(line);
      if (record != null) parsed.add(record);
    }

    setState(() {
      _rawText = text;
      _error = null;
      _parsed = parsed;
      if (parsed.isEmpty && text.trim().isNotEmpty) {
        _error = '未能解析出计件记录。\n'
            '每行格式：姓名 工序 数量 [日期]\n'
            '例如：张三 车缝 150';
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in oldList) {
        p.dispose();
      }
    });
  }

  _ParsedRecord? _parseLine(String line) {
    // 清洗：去除非中文、非字母数字、非空白字符
    String cleaned = line.replaceAll(
        RegExp(r'[^一-龥a-zA-Z0-9\s\-\.\/\,]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[,，]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;

    final tokens = cleaned.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    String? nameGuess;
    String? processGuess;
    double? qty;
    String? dateStr;

    // Pass 1: 逐个 token 分类
    for (final token in tokens) {
      // 日期
      if (dateStr == null) {
        // yyyy-MM-dd / yyyy/MM/dd
        final m1 =
            RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(token);
        if (m1 != null) {
          dateStr =
              '${m1.group(1)}-${m1.group(2)!.padLeft(2, '0')}-${m1.group(3)!.padLeft(2, '0')}';
          continue;
        }
        // MM-dd / MM/dd
        final m2 = RegExp(r'^(\d{1,2})[-/](\d{1,2})$').firstMatch(token);
        if (m2 != null) {
          dateStr =
              '${DateTime.now().year}-${m2.group(1)!.padLeft(2, '0')}-${m2.group(2)!.padLeft(2, '0')}';
          continue;
        }
      }

      // 数量（数字，忽略件/个等后缀）
      if (qty == null) {
        final qtyMatch = RegExp(r'^(\d+(\.\d+)?)').firstMatch(token);
        if (qtyMatch != null) {
          qty = double.parse(qtyMatch.group(1)!);
          continue;
        }
      }

      // 员工姓名
      if (nameGuess == null && _isLikelyName(token)) {
        for (final emp in _employees) {
          if (token == emp.name) {
            nameGuess = emp.name;
            break;
          }
        }
        if (nameGuess == null) {
          for (final emp in _employees) {
            if (token.contains(emp.name)) {
              nameGuess = emp.name;
              break;
            }
          }
        }
      }

      // 工序/产品名
      if (processGuess == null && token.length >= 2) {
        for (final proc in _processes) {
          final keywords = [proc.name, proc.productTypeName ?? ''];
          for (final kw in keywords) {
            if (token == kw || token.contains(kw)) {
              processGuess = proc.name;
              break;
            }
          }
          if (processGuess != null) break;
        }
      }
    }

    // Pass 2: 用整行再搜一遍
    if (nameGuess == null) {
      for (final emp in _employees) {
        if (line.contains(emp.name)) {
          nameGuess = emp.name;
          break;
        }
      }
    }
    if (processGuess == null) {
      for (final proc in _processes) {
        if (line.contains(proc.name) || line.contains(proc.productTypeName ?? '')) {
          processGuess = proc.name;
          break;
        }
      }
    }

    // 跳过表头行
    if (nameGuess == null && qty == null) return null;

    // 匹配 DB 实体
    Employee? matchedEmp;
    if (nameGuess != null) {
      for (final emp in _employees) {
        if (emp.name == nameGuess) {
          matchedEmp = emp;
          break;
        }
      }
    }
    ProcessModel? matchedProc;
    if (processGuess != null) {
      for (final p in _processes) {
        if (p.name == processGuess || p.productTypeName == processGuess) {
          matchedProc = p;
          break;
        }
      }
    }

    final dateText = dateStr ?? DateFormat('yyyy-MM-dd').format(_defaultDate);

    return _ParsedRecord(
      employeeCtrl: TextEditingController(text: nameGuess ?? ''),
      productCtrl: TextEditingController(
          text: matchedProc?.displayName ?? processGuess ?? ''),
      qtyCtrl: TextEditingController(text: qty?.toStringAsFixed(0) ?? ''),
      dateCtrl: TextEditingController(text: dateText),
      selectedEmployeeId: matchedEmp?.id,
      selectedProcessId: matchedProc?.id,
    );
  }

  bool _isLikelyName(String s) {
    if (s.length < 2 || s.length > 6) return false;
    return s.contains(RegExp(r'[一-龥]'));
  }

  // ==================== 批量保存 ====================

  Future<void> _saveAll() async {
    final validRecords = <ProductionRecord>[];
    final errors = <String>[];

    for (int i = 0; i < _parsed.length; i++) {
      final p = _parsed[i];

      if (p.selectedEmployeeId == null) {
        errors.add('第 ${i + 1} 行：未选择员工');
        continue;
      }
      if (p.selectedProcessId == null) {
        errors.add('第 ${i + 1} 行：未选择工序');
        continue;
      }
      final qty = double.tryParse(p.qtyCtrl.text.trim());
      if (qty == null || qty <= 0) {
        errors.add('第 ${i + 1} 行：数量无效');
        continue;
      }
      String date = p.dateCtrl.text.trim();
      if (date.isEmpty) {
        date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      validRecords.add(ProductionRecord(
        employeeId: p.selectedEmployeeId!,
        processId: p.selectedProcessId!,
        quantity: qty,
        recordDate: date,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    if (validRecords.isEmpty) {
      _showSnackBar('没有有效的记录可保存');
      return;
    }

    int saved = 0;
    try {
      for (final rec in validRecords) {
        await _db.insertRecord(rec);
        saved++;
      }
    } catch (e) {
      _showSnackBar('保存失败: $e');
      return;
    }

    if (mounted) {
      _showSnackBar('成功保存 $saved 条记录'
          '${errors.isNotEmpty ? "（${errors.length} 条跳过）" : ""}');
      Navigator.pop(context, true);
    }
  }

  // ==================== 辅助方法 ====================

  void _removeItem(int index) {
    final p = _parsed[index];
    p.dispose();
    setState(() => _parsed.removeAt(index));
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

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照计件录入'),
        actions: [
          if (_parsed.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              label: Text('保存 (${_parsed.length})'),
            ),
        ],
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
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

    // 缺少员工或工序数据
    if (_employees.isEmpty || _processes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, size: 48, color: Colors.orange.shade300),
              const SizedBox(height: 12),
              Text(
                _employees.isEmpty && _processes.isEmpty
                    ? '请先在「员工管理」和「工序管理」中添加数据'
                    : _employees.isEmpty
                        ? '请先在「员工管理」中添加员工'
                        : '请先在「工序管理」中添加工序',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
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
            Icon(Icons.document_scanner_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '拍照识别计件记录',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '支持格式：姓名 工序 数量 [日期]\n'
              '例如：张三 车缝 150',
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

    // 有解析结果
    return Column(
      children: [
        if (_photo != null || _rawText.isNotEmpty) _buildPreviewArea(theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '识别到 ${_parsed.length} 条记录',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _parsed.length,
            itemBuilder: (_, i) => _buildRecordCard(i, theme),
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
                  width: 60,
                  height: 60,
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
          child: SingleChildScrollView(child: SelectableText(_rawText)),
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

  Widget _buildRecordCard(int index, ThemeData theme) {
    final p = _parsed[index];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            // Row 1: 序号 + 员工下拉 + 删除
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
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('emp_${index}_${p.selectedEmployeeId}'),
                    initialValue: p.selectedEmployeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '员工 *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    hint: Text(
                      p.employeeCtrl.text.isEmpty
                          ? '选择员工'
                          : p.employeeCtrl.text,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _employees
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child:
                                  Text(e.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        p.selectedEmployeeId = v;
                        if (v != null) {
                          p.employeeCtrl.text =
                              _employees.firstWhere((e) => e.id == v).name;
                        }
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: 工序下拉 + 数量
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('proc_${index}_${p.selectedProcessId}'),
                    initialValue: p.selectedProcessId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '工序 *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    hint: Text(
                      p.productCtrl.text.isEmpty
                          ? '选择工序'
                          : p.productCtrl.text,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _processes
                        .map((proc) => DropdownMenuItem(
                              value: proc.id,
                              child: Text(proc.displayName,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        p.selectedProcessId = v;
                        if (v != null) {
                          p.productCtrl.text =
                              _processes.firstWhere((pr) => pr.id == v).displayName;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: p.qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 3: 日期（点击弹出 DatePicker）
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final current =
                          DateTime.tryParse(p.dateCtrl.text) ?? _defaultDate;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: current,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        locale: const Locale('zh', 'CN'),
                      );
                      if (picked != null) {
                        setState(() {
                          p.dateCtrl.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '日期',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(p.dateCtrl.text,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 共用小组件 ====================

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

// ==================== 数据结构 ====================

class _ParsedRecord {
  final TextEditingController employeeCtrl;
  final TextEditingController productCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController dateCtrl;

  int? selectedEmployeeId;
  int? selectedProcessId;

  _ParsedRecord({
    required this.employeeCtrl,
    required this.productCtrl,
    required this.qtyCtrl,
    required this.dateCtrl,
    this.selectedEmployeeId,
    this.selectedProcessId,
  });

  void dispose() {
    employeeCtrl.dispose();
    productCtrl.dispose();
    qtyCtrl.dispose();
    dateCtrl.dispose();
  }
}