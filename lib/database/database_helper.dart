import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/department.dart';
import '../models/product_type.dart';
import '../models/process_model.dart';
import '../models/production_record.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final p = join(dbPath, 'piece_rate_wage.db');
    return await openDatabase(p, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  // ==================== Schema ====================

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      "CREATE TABLE employees (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, code TEXT, phone TEXT, department TEXT, department_id INTEGER, hire_date TEXT, created_at TEXT)",
    );
    await db.execute(
      "CREATE TABLE departments (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT)",
    );
    await db.execute(
      "CREATE TABLE product_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT)",
    );
    await db.execute(
      "CREATE TABLE processes (id INTEGER PRIMARY KEY AUTOINCREMENT, product_type_id INTEGER NOT NULL, name TEXT NOT NULL, piece_rate REAL NOT NULL, unit TEXT DEFAULT '件', created_at TEXT, FOREIGN KEY (product_type_id) REFERENCES product_types(id) ON DELETE CASCADE)",
    );
    await db.execute(
      "CREATE TABLE production_records (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, process_id INTEGER NOT NULL, quantity REAL NOT NULL, record_date TEXT NOT NULL, note TEXT, created_at TEXT, FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE, FOREIGN KEY (process_id) REFERENCES processes(id) ON DELETE CASCADE)",
    );
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. 创建新表
      await db.execute(
          "CREATE TABLE IF NOT EXISTS departments (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT)");
      await db.execute(
          "CREATE TABLE IF NOT EXISTS product_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT)");
      await db.execute(
          "CREATE TABLE IF NOT EXISTS processes (id INTEGER PRIMARY KEY AUTOINCREMENT, product_type_id INTEGER NOT NULL, name TEXT NOT NULL, piece_rate REAL NOT NULL, unit TEXT DEFAULT '件', created_at TEXT, FOREIGN KEY (product_type_id) REFERENCES product_types(id) ON DELETE CASCADE)");

      // 2. employees 加 department_id 列
      try {
        await db.execute("ALTER TABLE employees ADD COLUMN department_id INTEGER");
      } catch (_) {}

      // 3. 从旧 department 字段创建部门
      await db.execute(
          "INSERT OR IGNORE INTO departments (name, created_at) SELECT DISTINCT department, datetime('now') FROM employees WHERE department IS NOT NULL AND department != ''");

      // 4. 关联员工到部门
      await db.execute(
          "UPDATE employees SET department_id = (SELECT id FROM departments WHERE departments.name = employees.department)");

      // 5. 从旧 products 表迁移产品类型
      await db.execute(
          "INSERT OR IGNORE INTO product_types (name, created_at) SELECT DISTINCT name, datetime('now') FROM products");

      // 6. 从旧 products 表迁移工序
      await db.execute(
          "INSERT INTO processes (product_type_id, name, piece_rate, unit, created_at) SELECT pt.id, p.process_name, p.piece_rate, p.unit, p.created_at FROM products p JOIN product_types pt ON pt.name = p.name");

      // 7. production_records 加 process_id 列
      try {
        await db.execute("ALTER TABLE production_records ADD COLUMN process_id INTEGER");
      } catch (_) {}

      // 8. 迁移旧 product_id → process_id
      await db.execute(
          "UPDATE production_records SET process_id = (SELECT pr2.id FROM processes pr2 JOIN products p ON p.id = production_records.product_id JOIN product_types pt ON pt.name = p.name WHERE pr2.product_type_id = pt.id AND pr2.name = p.process_name LIMIT 1)");
    }
  }

  // ==================== Sample Data ====================

  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 部门
    final deptIds = <int>[
      await db.insert('departments', {'name': '车缝组', 'created_at': now}),
      await db.insert('departments', {'name': '包装组', 'created_at': now}),
      await db.insert('departments', {'name': '质检组', 'created_at': now}),
    ];

    // 员工
    final empIds = <int>[
      await db.insert('employees', {
        'name': '张三', 'code': 'EMP001', 'phone': '13800001111',
        'department': '车缝组', 'department_id': deptIds[0],
        'hire_date': '2024-01-15', 'created_at': now,
      }),
      await db.insert('employees', {
        'name': '李四', 'code': 'EMP002', 'phone': '13800002222',
        'department': '车缝组', 'department_id': deptIds[0],
        'hire_date': '2024-03-01', 'created_at': now,
      }),
      await db.insert('employees', {
        'name': '王五', 'code': 'EMP003', 'phone': '13800003333',
        'department': '包装组', 'department_id': deptIds[1],
        'hire_date': '2024-02-20', 'created_at': now,
      }),
      await db.insert('employees', {
        'name': '赵六', 'code': 'EMP004', 'phone': '13800004444',
        'department': '质检组', 'department_id': deptIds[2],
        'hire_date': '2024-04-10', 'created_at': now,
      }),
    ];
    final e1 = empIds[0], e2 = empIds[1], e3 = empIds[2];

    // 产品类型
    final ptIds = <int>[
      await db.insert('product_types', {'name': '手提袋', 'created_at': now}),
      await db.insert('product_types', {'name': '电脑包', 'created_at': now}),
      await db.insert('product_types', {'name': '包装', 'created_at': now}),
    ];

    // 工序（按产品类型分组）
    final procIds = <int>[
      await db.insert('processes', {
        'product_type_id': ptIds[0], 'name': '车缝', 'piece_rate': 2.50, 'unit': '件', 'created_at': now,
      }),
      await db.insert('processes', {
        'product_type_id': ptIds[0], 'name': '上拉链', 'piece_rate': 1.50, 'unit': '件', 'created_at': now,
      }),
      await db.insert('processes', {
        'product_type_id': ptIds[1], 'name': '车缝', 'piece_rate': 3.00, 'unit': '件', 'created_at': now,
      }),
      await db.insert('processes', {
        'product_type_id': ptIds[1], 'name': '上拉链', 'piece_rate': 2.00, 'unit': '件', 'created_at': now,
      }),
      await db.insert('processes', {
        'product_type_id': ptIds[2], 'name': '打包', 'piece_rate': 0.50, 'unit': '件', 'created_at': now,
      }),
    ];
    final p1 = procIds[0], p2 = procIds[1], p3 = procIds[2], p4 = procIds[3], p5 = procIds[4];

    // 生产记录
    final today = DateTime.now();
    for (int day = 1; day <= 20; day++) {
      final d = DateTime(today.year, today.month, day);
      final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (day <= 18) {
        for (final rec in [
          {'employee_id': e1, 'process_id': p1, 'quantity': 80.0 + (day % 40)},
          {'employee_id': e1, 'process_id': p2, 'quantity': 60.0 + (day % 30)},
          {'employee_id': e2, 'process_id': p3, 'quantity': 50.0 + (day % 30)},
          {'employee_id': e2, 'process_id': p4, 'quantity': 40.0 + (day % 20)},
        ]) {
          await db.insert('production_records', {
            'employee_id': rec['employee_id'],
            'process_id': rec['process_id'],
            'quantity': rec['quantity'],
            'record_date': ds,
            'created_at': now,
          });
        }
      }
      if (day <= 18 && day % 2 == 0) {
        await db.insert('production_records', {
          'employee_id': e3, 'process_id': p5,
          'quantity': 200.0 + (day * 10),
          'record_date': ds, 'created_at': now,
        });
      }
    }
  }

  // ==================== Departments ====================

  Future<List<Department>> getDepartments() async {
    final maps = await (await database).query('departments', orderBy: 'id ASC');
    return maps.map((m) => Department.fromMap(m)).toList();
  }

  Future<int> insertDepartment(Department d) async =>
      (await database).insert('departments', d.toMap());

  Future<int> updateDepartment(Department d) async => (await database).update(
        'departments', d.toMap(), where: 'id = ?', whereArgs: [d.id]);

  Future<int> deleteDepartment(int id) async =>
      (await database).delete('departments', where: 'id = ?', whereArgs: [id]);

  /// 获取部门员工数
  Future<int> getDepartmentEmployeeCount(int deptId) async =>
      Sqflite.firstIntValue(await (await database).rawQuery(
          'SELECT COUNT(*) FROM employees WHERE department_id = ?', [deptId])) ?? 0;

  // ==================== Employees ====================

  Future<List<Employee>> getEmployees() async {
    final maps = await (await database).rawQuery(
      "SELECT e.*, d.name AS department_name FROM employees e LEFT JOIN departments d ON e.department_id = d.id ORDER BY e.id ASC");
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<Employee?> getEmployee(int id) async {
    final maps = await (await database).rawQuery(
      "SELECT e.*, d.name AS department_name FROM employees e LEFT JOIN departments d ON e.department_id = d.id WHERE e.id = ?", [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<int> insertEmployee(Employee e) async =>
      (await database).insert('employees', e.toMap());

  Future<int> updateEmployee(Employee e) async => (await database).update(
        'employees', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  Future<int> deleteEmployee(int id) async =>
      (await database).delete('employees', where: 'id = ?', whereArgs: [id]);

  Future<List<Employee>> searchEmployees(String keyword) async {
    final maps = await (await database).rawQuery(
      "SELECT e.*, d.name AS department_name FROM employees e LEFT JOIN departments d ON e.department_id = d.id WHERE e.name LIKE ? OR e.code LIKE ? ORDER BY e.id ASC",
      ['%$keyword%', '%$keyword%']);
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<List<Employee>> getEmployeesByDepartment(int deptId) async {
    final maps = await (await database).rawQuery(
      "SELECT e.*, d.name AS department_name FROM employees e LEFT JOIN departments d ON e.department_id = d.id WHERE e.department_id = ? ORDER BY e.id ASC", [deptId]);
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  // ==================== Product Types ====================

  Future<List<ProductType>> getProductTypes() async {
    final maps = await (await database).rawQuery(
      "SELECT pt.*, (SELECT COUNT(*) FROM processes WHERE product_type_id = pt.id) AS process_count FROM product_types pt ORDER BY pt.id ASC");
    return maps.map((m) => ProductType.fromMap(m)).toList();
  }

  Future<int> insertProductType(ProductType pt) async =>
      (await database).insert('product_types', pt.toMap());

  Future<int> updateProductType(ProductType pt) async => (await database).update(
        'product_types', pt.toMap(), where: 'id = ?', whereArgs: [pt.id]);

  Future<int> deleteProductType(int id) async {
    final db = await database;
    await db.delete('processes', where: 'product_type_id = ?', whereArgs: [id]);
    return await db.delete('product_types', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Processes ====================

  Future<List<ProcessModel>> getProcesses({int? productTypeId}) async {
    final conds = <String>[];
    final args = <dynamic>[];
    if (productTypeId != null) {
      conds.add('p.product_type_id = ?');
      args.add(productTypeId);
    }
    final ws = conds.isNotEmpty ? 'WHERE ${conds.join(' AND ')}' : '';
    final maps = await (await database).rawQuery(
      "SELECT p.*, pt.name AS product_type_name FROM processes p LEFT JOIN product_types pt ON p.product_type_id = pt.id $ws ORDER BY p.id ASC",
      args);
    return maps.map((m) => ProcessModel.fromMap(m)).toList();
  }

  Future<ProcessModel?> getProcess(int id) async {
    final maps = await (await database).rawQuery(
      "SELECT p.*, pt.name AS product_type_name FROM processes p LEFT JOIN product_types pt ON p.product_type_id = pt.id WHERE p.id = ?", [id]);
    if (maps.isEmpty) return null;
    return ProcessModel.fromMap(maps.first);
  }

  Future<int> insertProcess(ProcessModel p) async =>
      (await database).insert('processes', p.toMap());

  Future<int> updateProcess(ProcessModel p) async => (await database).update(
        'processes', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<int> deleteProcess(int id) async =>
      (await database).delete('processes', where: 'id = ?', whereArgs: [id]);

  Future<List<ProcessModel>> searchProcesses(String keyword) async {
    final maps = await (await database).rawQuery(
      "SELECT p.*, pt.name AS product_type_name FROM processes p LEFT JOIN product_types pt ON p.product_type_id = pt.id WHERE p.name LIKE ? OR pt.name LIKE ? ORDER BY p.id ASC",
      ['%$keyword%', '%$keyword%']);
    return maps.map((m) => ProcessModel.fromMap(m)).toList();
  }

  // ==================== Records ====================

  Future<List<ProductionRecord>> getRecords({
    int? employeeId,
    int? processId,
    int? productTypeId,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;
    final conds = <String>[];
    final args = <dynamic>[];
    if (employeeId != null) {
      conds.add('pr.employee_id = ?');
      args.add(employeeId);
    }
    if (processId != null) {
      conds.add('pr.process_id = ?');
      args.add(processId);
    }
    if (productTypeId != null) {
      conds.add('p.product_type_id = ?');
      args.add(productTypeId);
    }
    if (startDate != null) {
      conds.add('pr.record_date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      conds.add('pr.record_date <= ?');
      args.add(endDate);
    }
    final ws = conds.isNotEmpty ? 'WHERE ${conds.join(' AND ')}' : '';
    final sql =
        "SELECT pr.*, e.name AS employee_name, p.name AS process_name, p.piece_rate, p.unit, pt.name AS product_type_name FROM production_records pr LEFT JOIN employees e ON pr.employee_id = e.id LEFT JOIN processes p ON pr.process_id = p.id LEFT JOIN product_types pt ON p.product_type_id = pt.id $ws ORDER BY pr.record_date DESC, pr.id DESC";
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => ProductionRecord.fromMap(m)).toList();
  }

  Future<int> insertRecord(ProductionRecord r) async =>
      (await database).insert('production_records', r.toMap());

  Future<int> updateRecord(ProductionRecord r) async => (await database).update(
        'production_records', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<int> deleteRecord(int id) async =>
      (await database).delete('production_records', where: 'id = ?', whereArgs: [id]);

  // ==================== Stats / Reports ====================

  Future<int> getRecordCount() async =>
      Sqflite.firstIntValue(await (await database).rawQuery(
          'SELECT COUNT(*) AS cnt FROM production_records')) ?? 0;

  Future<int> getEmployeeCount() async =>
      Sqflite.firstIntValue(await (await database).rawQuery(
          'SELECT COUNT(*) AS cnt FROM employees')) ?? 0;

  Future<int> getProcessCount() async =>
      Sqflite.firstIntValue(await (await database).rawQuery(
          'SELECT COUNT(*) AS cnt FROM processes')) ?? 0;

  Future<int> getProductTypeCount() async =>
      Sqflite.firstIntValue(await (await database).rawQuery(
          'SELECT COUNT(*) AS cnt FROM product_types')) ?? 0;

  Future<Map<String, dynamic>> getTodayStats() async {
    final today = DateTime.now();
    final ds = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final r = await (await database).rawQuery(
      "SELECT COUNT(*) AS cnt, COALESCE(SUM(pr.quantity * p.piece_rate), 0) AS wage FROM production_records pr LEFT JOIN processes p ON pr.process_id = p.id WHERE pr.record_date = ?", [ds]);
    return r.first;
  }

  Future<List<Map<String, dynamic>>> getWageSummary(
    String startDate,
    String endDate,
  ) async {
    return (await database).rawQuery(
      "SELECT e.id AS employee_id, e.name AS employee_name, d.name AS department, SUM(pr.quantity) AS total_quantity, SUM(pr.quantity * p.piece_rate) AS total_wage FROM production_records pr LEFT JOIN employees e ON pr.employee_id = e.id LEFT JOIN processes p ON pr.process_id = p.id LEFT JOIN departments d ON e.department_id = d.id WHERE pr.record_date BETWEEN ? AND ? GROUP BY e.id ORDER BY total_wage DESC",
      [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getEmployeeWageDetail(
    int employeeId,
    String startDate,
    String endDate,
  ) async {
    return (await database).rawQuery(
      "SELECT p.id AS process_id, pt.name AS product_name, p.name AS process_name, p.piece_rate, p.unit, SUM(pr.quantity) AS total_quantity, SUM(pr.quantity * p.piece_rate) AS total_wage FROM production_records pr LEFT JOIN processes p ON pr.process_id = p.id LEFT JOIN product_types pt ON p.product_type_id = pt.id WHERE pr.employee_id = ? AND pr.record_date BETWEEN ? AND ? GROUP BY p.id ORDER BY p.id ASC",
      [employeeId, startDate, endDate]);
  }

  /// 关闭数据库连接（用于恢复数据前）
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
