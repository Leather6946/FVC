import 'package:flutter/material.dart';
import 'employee_screen.dart';
import 'product_screen.dart';
import 'record_screen.dart';
import 'wage_screen.dart';
import '../database/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _empCount = 0, _processCount = 0, _recCount = 0;
  int _todayCount = 0;
  double _todayWage = 0;

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
    final ts = await db.getTodayStats();
    if (mounted) {
      setState(() {
        _empCount = ec;
        _processCount = pc;
        _recCount = rc;
        _todayCount = (ts['cnt'] as int?) ?? 0;
        _todayWage = (ts['wage'] as num?)?.toDouble() ?? 0;
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
      appBar: AppBar(title: const Text('包袋厂计件工资管理系统')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 今日概况
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日概况',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TodayItem(
                          label: '记录数',
                          value: '$_todayCount 条',
                          icon: Icons.today,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 24),
                        _TodayItem(
                          label: '工资合计',
                          value: '¥${_todayWage.toStringAsFixed(2)}',
                          icon: Icons.monetization_on,
                          color: Colors.amber.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
              subtitle: '记录每日产量、查看生产明细',
              color: Colors.green,
              onTap: () => _nav(const RecordScreen()),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.calculate_outlined,
              title: '工资计算',
              subtitle: '按月统计工资、查看明细',
              color: Colors.purple,
              onTap: () => _nav(const WageScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TodayItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ],
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
