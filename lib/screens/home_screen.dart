import 'package:flutter/material.dart';
import 'employee_screen.dart';
import 'product_screen.dart';
import 'record_screen.dart';
import 'record_query_screen.dart';
import 'backup_screen.dart';
import 'wage_screen.dart';
import '../database/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _empCount = 0, _processCount = 0, _recCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DatabaseHelper();
    final ec = await db.getEmployeeCount();
    final pc = await db.getProcessCount();
    final rc = await db.getRecordCount();
    if (mounted) {
      setState(() {
        _empCount = ec;
        _processCount = pc;
        _recCount = rc;
      });
    }
  }

  void _nav(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('计件工资管理系统')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 累计统计
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people,
                    label: '员工',
                    value: '$_empCount',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.build,
                    label: '工序',
                    value: '$_processCount',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.assignment,
                    label: '记录',
                    value: '$_recCount',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('功能菜单', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.people_outline,
              title: '员工管理',
              subtitle: '添加工人、编辑信息、删除记录',
              color: Colors.blue,
              onTap: () => _nav(const EmployeeScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.settings_outlined,
              title: '工序管理',
              subtitle: '定义产品类型和工序、设置单价',
              color: Colors.orange,
              onTap: () => _nav(const ProductScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.edit_note,
              title: '计件录入',
              subtitle: '快速录入每日产量',
              color: Colors.green,
              onTap: () => _nav(const RecordScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.search,
              title: '计件查询',
              subtitle: '按员工、包袋种类、日期查询记录',
              color: Colors.teal,
              onTap: () => _nav(const RecordQueryScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.calculate_outlined,
              title: '工资计算',
              subtitle: '按月统计工资、查看明细',
              color: Colors.purple,
              onTap: () => _nav(const WageScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.backup_outlined,
              title: '数据备份',
              subtitle: '导出数据库到设备备份',
              color: Colors.grey,
              onTap: () => _nav(const BackupScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
