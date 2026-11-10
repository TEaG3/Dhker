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
    String path = join(await getDatabasesPath(), 'dhikr.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. جدول المراجع الشرعية (References)
    await db.execute('''
      CREATE TABLE references (
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

    // 2. جدول الأذكار (Adhkar)
    await db.execute('''
      CREATE TABLE adhkar (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        text TEXT NOT NULL,
        repeat_count INTEGER NOT NULL,
        reference_id TEXT,
        FOREIGN KEY (reference_id) REFERENCES references (id)
      )
    ''');

    // 3. جدول الأحاديث (Hadiths) - للاستخدام المستقبلي
    await db.execute('''
      CREATE TABLE hadiths (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        reference_id TEXT,
        FOREIGN KEY (reference_id) REFERENCES references (id)
      )
    ''');
    
    // إدراج بيانات تجريبية (يمكنك لاحقاً استبدالها بقراءة من JSON)
    await db.insert('references', {
      'id': 'ref_001',
      'book_name': 'صحيح البخاري',
      'hadith_number': '6306',
      'grade': 'صحيح',
      'scholar': 'اتفاق الأمة',
    });

    await db.insert('adhkar', {
      'id': 'm1',
      'category_id': 'morning',
      'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ...',
      'repeat_count': 1,
      'reference_id': 'ref_001',
    });
  }

  // ==========================================
  // دوال الاستعلام (CRUD)
  // ==========================================

  // جلب الأذكار حسب الفئة (صباح، مساء...)
  Future<List<Map<String, dynamic>>> getAdhkarByCategory(String categoryId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, r.book_name, r.hadith_number, r.grade 
      FROM adhkar a
      LEFT JOIN references r ON a.reference_id = r.id
      WHERE a.category_id = ?
    ''', [categoryId]);
  }

  // جلب جميع المراجع
  Future<List<Map<String, dynamic>>> getAllReferences() async {
    final db = await database;
    return await db.query('references');
  }
}
