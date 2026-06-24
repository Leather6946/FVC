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
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  final Map<int, List<Map<String, dynamic>>> _details = {};
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _startStr => DateFormat('yyyy-MM-dd').format(_startDate);
  String get _endStr => DateFormat('yyyy-MM-dd').format(_endDate);

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _db.getWageSummary(_startStr, _endStr);
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
      _startStr,
      _endStr,
    );
    setState(() {
      _details[employeeId] = detail;
      _expandedId = employeeId;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _details.clear();
        _expandedId = null;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double totalWage = 0;
    for (final s in _summary) {
      totalWage += (s['total_wage'] as num?)?.toDouble() ?? 0;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('工资计算')),
      body: Column(
        children: [
          // 日期范围选择与总计
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _startStr,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('~', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _endStr,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
