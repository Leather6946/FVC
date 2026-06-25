import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
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
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
      final backupFile =
          File('${dir.path}/计件工资备份_$timestamp.db');
      await source.copy(backupFile.path);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: '计件工资数据备份 ($timestamp)',
      );
    } catch (e) {
      _showSnackBar('备份失败: $e');
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

                Text('操作',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _backup,
                    icon: const Icon(Icons.backup),
                    label: const Text('备份并分享数据库',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 24),

                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '备份功能会导出完整的数据库文件（.db），'
                            '包含所有员工、工序、生产记录和工资数据。\n\n'
                            '点击"备份并分享"后，可以通过微信、QQ、'
                            '邮件等方式保存到电脑或云盘。',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  color: Colors.amber.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.restore,
                            color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('需要恢复数据？',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                '如需从备份恢复数据，请通过导出功能保存好 .db 文件。'
                                '恢复操作需要重新安装应用并在首次启动前将备份文件放到指定目录，'
                                '或联系开发者获取协助。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
