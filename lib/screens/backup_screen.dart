import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;
  int _employeeCount = 0;
  int _recordCount = 0;
  int _processCount = 0;
  String _dbSize = '';
  List<FileSystemEntity> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final dbPath = await getDatabasesPath();
      final file = File('$dbPath/piece_rate_wage.db');
      final size = file.existsSync() ? file.lengthSync() : 0;

      final ec = await _db.getEmployeeCount();
      final rc = await _db.getRecordCount();
      final pc = await _db.getProcessCount();

      if (mounted) {
        setState(() {
          _employeeCount = ec;
          _recordCount = rc;
          _processCount = pc;
          _dbSize = _formatSize(size);
        });
      }
    } catch (e) {
      // ignore
    }
    await _loadBackupFiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBackupFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().where((f) =>
          f is File && f.path.endsWith('.db')).toList();
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      if (mounted) {
        setState(() => _backupFiles = files);
      }
    } catch (e) {
      // ignore
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _backup() async {
    try {
      _showSnackBar('正在备份...');

      final dbPath = await getDatabasesPath();
      final source = File('$dbPath/piece_rate_wage.db');

      if (!source.existsSync()) {
        _showSnackBar('数据库文件不存在');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = '计件工资备份_$timestamp.db';
      final backupFile = File('${dir.path}/$backupName');
      await source.copy(backupFile.path);

      // 保存到系统 Downloads
      const channel = MethodChannel('com.bagfactory.piece_rate_wage/file');
      await channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': backupFile.path,
      });

      await _loadBackupFiles();

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: '计件工资数据备份 ($timestamp)',
      );
    } catch (e) {
      _showSnackBar('备份失败: $e');
    }
  }

  Future<void> _restore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        _showSnackBar('无法读取所选文件');
        return;
      }

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入数据'),
          content: Text(
            '将用所选备份文件替换当前所有数据！\n\n'
            '当前数据将被覆盖且不可恢复。\n'
            '建议先备份当前数据库。\n\n'
            '确定要继续吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      _showSnackBar('正在导入数据...');

      await _db.closeDatabase();

      final dbPath = await getDatabasesPath();
      final targetFile = File('$dbPath/piece_rate_wage.db');

      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }

      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(targetFile.path);

      try {
        await _db.database;
      } catch (e) {
        if (targetFile.existsSync()) targetFile.deleteSync();
        _showSnackBar('文件无效或数据库损坏，导入失败');
        return;
      }

      await _loadStats();

      if (mounted) {
        _showSnackBar('数据导入成功！');
      }
    } catch (e) {
      _showSnackBar('导入失败: $e');
    }
  }

  Future<void> _shareBackupFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '计件工资数据备份',
      );
    } catch (e) {
      _showSnackBar('分享失败: $e');
    }
  }

  Future<void> _deleteBackupFile(File file) async {
    final name = file.path.split('\\').last.split('/').last;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备份文件'),
        content: Text('确定要删除\n"$name"\n吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        file.deleteSync();
        await _loadBackupFiles();
        if (mounted) _showSnackBar('已删除');
      } catch (e) {
        _showSnackBar('删除失败: $e');
      }
    }
  }

  Future<void> _clearDatabase() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据'),
        content: Text(
          '将删除所有员工、工序、生产记录！\n\n'
          '此操作不可恢复，建议先备份数据库。\n\n'
          '确定要清空吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      _showSnackBar('正在清空...');
      final db = await _db.database;

      await db.delete('production_records');
      await db.delete('processes');
      await db.delete('product_types');
      await db.delete('employees');
      await db.delete('departments');

      await _loadStats();
      if (mounted) _showSnackBar('所有数据已清空');
    } catch (e) {
      _showSnackBar('清空失败: $e');
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
      appBar: AppBar(title: const Text('数据备份')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('当前数据库状态',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        const Divider(),
                        _InfoRow(
                            icon: Icons.person_outline,
                            label: '员工数',
                            value: '$_employeeCount 人'),
                        const SizedBox(height: 6),
                        _InfoRow(
                            icon: Icons.build_outlined,
                            label: '工序数',
                            value: '$_processCount 个'),
                        const SizedBox(height: 6),
                        _InfoRow(
                            icon: Icons.assignment_outlined,
                            label: '生产记录',
                            value: '$_recordCount 条'),
                        const SizedBox(height: 6),
                        _InfoRow(
                            icon: Icons.disc_full_outlined,
                            label: '数据库大小',
                            value: _dbSize),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _clearDatabase,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('清空所有数据',
                        style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.tonalIcon(
                    onPressed: _backup,
                    icon: const Icon(Icons.backup),
                    label: const Text('备份并分享数据库',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('从备份文件导入数据',
                        style: TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    '备份文件直接保存到手机「下载」文件夹，可通过文件管理器查看',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // 备份文件列表
                Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('备份文件管理',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
                const SizedBox(height: 12),

                if (_backupFiles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_off_outlined,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              '暂无备份文件',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '点击上方"备份并分享"创建备份',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(_backupFiles.length, (i) {
                    final f = _backupFiles[i] as File;
                    final name = f.path.split('\\').last.split('/').last;
                    final size = f.lengthSync();
                    final modified = f.statSync().modified;
                    final dateStr =
                        DateFormat('yyyy-MM-dd HH:mm').format(modified);
                    return Card(
                      key: ValueKey(f.path),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.green.withValues(alpha: 0.1),
                          child: const Icon(Icons.backup,
                              color: Colors.green, size: 20),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$dateStr  |  ${_formatSize(size)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'share') _shareBackupFile(f);
                            if (val == 'delete') _deleteBackupFile(f);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share, size: 18),
                                  SizedBox(width: 8),
                                  Text('分享'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('删除',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _shareBackupFile(f),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            )),
      ],
    );
  }
}
