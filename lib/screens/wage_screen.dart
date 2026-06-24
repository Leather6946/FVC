import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class WageScreen extends StatefulWidget {
  const WageScreen({super.key});

  @override
  State<WageScreen> createState() => _WageScreenState();
}

class _WageScreenState extends State<WageScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _summary = [];
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();
  final Map<int, List<Map<String, dynamic>>> _details = {};
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _monthStart {
    return '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01';
  }

  String get _monthEnd {
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    return DateFormat('yyyy-MM-dd').format(lastDay);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _db.getWageSummary(_monthStart, _monthEnd);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  Future<void> _loadDetail(int employeeId) async {
    if (_details.containsKey(employeeId)) {
      setState(() {
        _expandedId = _expandedId == employeeId ? null : employeeId;
      });
      return;
    }
    final detail = await _db.getEmployeeWageDetail(
      employeeId,
      _monthStart,
      _monthEnd,
    );
    setState(() {
      _details[employeeId] = detail;
      _expandedId = employeeId;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
      helpText: '选择月份',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _details.clear();
        _expandedId = null;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy年MM月');
    double totalWage = 0;
    for (final s in _summary) {
      totalWage += (s['total_wage'] as num?)?.toDouble() ?? 0;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('工资计算')),
      body: Column(
        children: [
          // 月份选择与总计
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.date_range),
                    label: Text(fmt.format(_selectedMonth)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '合计: ¥${totalWage.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 工资列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _summary.isEmpty
                ? const Center(child: Text('该月暂无生产记录'))
                : ListView.builder(
                    itemCount: _summary.length,
                    itemBuilder: (_, i) {
                      final s = _summary[i];
                      final eid = s['employee_id'] as int;
                      final name = s['employee_name'] as String? ?? '?';
                      final dept = s['department'] as String? ?? '';
                      final qty =
                          (s['total_quantity'] as num?)?.toDouble() ?? 0;
                      final wage = (s['total_wage'] as num?)?.toDouble() ?? 0;
                      final isExpanded = _expandedId == eid;
                      final detail = _details[eid];

                      final deptPrefix = dept.isNotEmpty ? '$dept | ' : '';
                      final subtitleStr =
                          '$deptPrefix总件数: ${qty.toStringAsFixed(0)} | 总工资: ¥${wage.toStringAsFixed(2)}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.purple.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  '¥',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(subtitleStr),
                              trailing: IconButton(
                                icon: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onPressed: () => _loadDetail(eid),
                              ),
                            ),
                            if (isExpanded && detail != null)
                              ...detail.map((d) {
                                final dn = d['product_name'] as String? ?? '';
                                final pn = d['process_name'] as String? ?? '';
                                final rate =
                                    (d['piece_rate'] as num?)?.toDouble() ?? 0;
                                final dqty =
                                    (d['total_quantity'] as num?)?.toDouble() ??
                                    0;
                                final dwage =
                                    (d['total_wage'] as num?)?.toDouble() ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 56,
                                    right: 16,
                                    bottom: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '$dn-$pn',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'x${dqty.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '¥${rate.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '¥${dwage.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
