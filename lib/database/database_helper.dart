import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/product.dart';
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
    return await openDatabase(p, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      "CREATE TABLE employees (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, code TEXT, phone TEXT, department TEXT, hire_date TEXT, created_at TEXT)",
    );
    await db.execute(
      "CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, process_name TEXT NOT NULL, piece_rate REAL NOT NULL, unit TEXT DEFAULT '件', created_at TEXT)",
    );
    await db.execute(
      "CREATE TABLE production_records (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL, record_date TEXT NOT NULL, note TEXT, created_at TEXT, FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE, FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE)",
    );
    await _insertSampleData(db);
  }

  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();
    final e1 = await db.insert('employees', {
      'name': '张三',
      'code': 'EMP001',
      'phone': '13800001111',
      'department': '车缝组',
      'hire_date': '2024-01-15',
      'created_at': now,
    });
    final e2 = await db.insert('employees', {
      'name': '李四',
      'code': 'EMP002',
      'phone': '13800002222',
      'department': '车缝组',
      'hire_date': '2024-03-01',
      'created_at': now,
    });
    final e3 = await db.insert('employees', {
      'name': '王五',
      'code': 'EMP003',
      'phone': '13800003333',
      'department': '包装组',
      'hire_date': '2024-02-20',
      'created_at': now,
    });
    await db.insert('employees', {
      'name': '赵六',
      'code': 'EMP004',
      'phone': '13800004444',
      'department': '质检组',
      'hire_date': '2024-04-10',
      'created_at': now,
    });

    final p1 = await db.insert('products', {
      'name': '手提袋',
      'process_name': '车缝',
      'piece_rate': 2.50,
      'unit': '件',
      'created_at': now,
    });
    final p2 = await db.insert('products', {
      'name': '手提袋',
      'process_name': '上拉链',
      'piece_rate': 1.50,
      'unit': '件',
      'created_at': now,
    });
    final p3 = await db.insert('products', {
      'name': '电脑包',
      'process_name': '车缝',
      'piece_rate': 3.00,
      'unit': '件',
      'created_at': now,
    });
    final p4 = await db.insert('products', {
      'name': '电脑包',
      'process_name': '上拉链',
      'piece_rate': 2.00,
      'unit': '件',
      'created_at': now,
    });
    await db.insert('products', {
      'name': '包装',
      'process_name': '打包',
      'piece_rate': 0.50,
      'unit': '件',
      'created_at': now,
    });

    final today = DateTime.now();
    for (int day = 1; day <= 20; day++) {
      final d = DateTime(today.year, today.month, day);
      final ds =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (day <= 18) {
        await db.insert('production_records', {
          'employee_id': e1,
          'product_id': p1,
          'quantity': (80 + (day % 40)).toDouble(),
          'record_date': ds,
          'created_at': now,
        });
        await db.insert('production_records', {
          'employee_id': e1,
          'product_id': p2,
          'quantity': (60 + (day % 30)).toDouble(),
          'record_date': ds,
          'created_at': now,
        });
        await db.insert('production_records', {
          'employee_id': e2,
          'product_id': p3,
          'quantity': (50 + (day % 30)).toDouble(),
          'record_date': ds,
          'created_at': now,
        });
        await db.insert('production_records', {
          'employee_id': e2,
          'product_id': p4,
          'quantity': (40 + (day % 20)).toDouble(),
          'record_date': ds,
          'created_at': now,
        });
      }
      if (day <= 18 && day % 2 == 0) {
        await db.insert('production_records', {
          'employee_id': e3,
          'product_id': 5,
          'quantity': (200 + (day * 10)).toDouble(),
          'record_date': ds,
          'created_at': now,
        });
      }
    }
  }

  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'id ASC');
    return maps.map((m) => Employee.fromMap(m)).toList();
  }

  Future<Employee?> getEmployee(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<int> insertEmployee(Employee e) async {
    final db = await database;
    return await db.insert('employees', e.toMap());
  }

  Future<int> updateEmployee(Employee e) async {
    final db = await database;
    return await db.update(
      'employees',
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'id ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> insertProduct(Product p) async {
    final db = await database;
    return await db.insert('products', p.toMap());
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return await db.update(
      'products',
      p.toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProductionRecord>> getRecords({
    int? employeeId,
    int? productId,
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
    if (productId != null) {
      conds.add('pr.product_id = ?');
      args.add(productId);
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
        "SELECT pr.*, e.name AS employee_name, p.name AS product_name, p.process_name, p.piece_rate, p.unit FROM production_records pr LEFT JOIN employees e ON pr.employee_id = e.id LEFT JOIN products p ON pr.product_id = p.id $ws ORDER BY pr.record_date DESC, pr.id DESC";
    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => ProductionRecord.fromMap(m)).toList();
  }

  Future<int> insertRecord(ProductionRecord r) async {
    final db = await database;
    return await db.insert('production_records', r.toMap());
  }

  Future<int> updateRecord(ProductionRecord r) async {
    final db = await database;
    return await db.update(
      'production_records',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete(
      'production_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getWageSummary(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT e.id AS employee_id, e.name AS employee_name, e.department, SUM(pr.quantity) AS total_quantity, SUM(pr.quantity * p.piece_rate) AS total_wage FROM production_records pr LEFT JOIN employees e ON pr.employee_id = e.id LEFT JOIN products p ON pr.product_id = p.id WHERE pr.record_date BETWEEN ? AND ? GROUP BY e.id ORDER BY total_wage DESC",
      [startDate, endDate],
    );
  }

  Future<List<Map<String, dynamic>>> getEmployeeWageDetail(
    int employeeId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.rawQuery(
      "SELECT p.id AS product_id, p.name AS product_name, p.process_name, p.piece_rate, p.unit, SUM(pr.quantity) AS total_quantity, SUM(pr.quantity * p.piece_rate) AS total_wage FROM production_records pr LEFT JOIN products p ON pr.product_id = p.id WHERE pr.employee_id = ? AND pr.record_date BETWEEN ? AND ? GROUP BY p.id ORDER BY p.id ASC",
      [employeeId, startDate, endDate],
    );
  }

  Future<int> getRecordCount() async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM production_records',
    );
    return r.first['cnt'] as int;
  }

  Future<int> getEmployeeCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS cnt FROM employees');
    return r.first['cnt'] as int;
  }

  Future<int> getProductCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS cnt FROM products');
    return r.first['cnt'] as int;
  }
}
