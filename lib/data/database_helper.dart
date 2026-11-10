import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    String path = join(await getDatabasesPath(), 'dhker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. جدول التصنيفات (مثل: أذكار الصباح، أذكار النوم)
    await db.execute('''
      CREATE TABLE adhkar_categories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL
      )
    ''');

    // 2. جدول المراجع (المصادر الشرعية)
    await db.execute('''
      CREATE TABLE references_table (
        id TEXT PRIMARY KEY,
        book_name TEXT NOT NULL,
        author TEXT,
        hadith_number TEXT,
        grade TEXT,
        scholar TEXT,
        url TEXT,
        notes TEXT
      )
    ''');

    // 3. جدول الأذكار (يرتبط بالتصنيف وبالمرجع)
    await db.execute('''
      CREATE TABLE adhkar_items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        text TEXT NOT NULL,
        repeat_count INTEGER DEFAULT 1,
        reference_id TEXT,
        FOREIGN KEY (category_id) REFERENCES adhkar_categories (id),
        FOREIGN KEY (reference_id) REFERENCES references_table (id)
      )
    ''');
  }

  // دالة لإدخال مرجع جديد
  Future<int> insertReference(Map<String, dynamic> reference) async {
    final db = await database;
    return await db.insert('references_table', reference, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // دالة لإدخال تصنيف أذكار
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('adhkar_categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // دالة لإدخال ذكر
  Future<int> insertAdhkarItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('adhkar_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // دالة لجلب جميع الأذكار مع مراجعها (JOIN)
  Future<List<Map<String, dynamic>>> getAdhkarWithReferences() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, r.book_name, r.hadith_number, r.grade 
      FROM adhkar_items a
      LEFT JOIN references_table r ON a.reference_id = r.id
    ''');
  }
}
