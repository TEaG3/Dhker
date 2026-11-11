import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
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

    await db.execute('''
      CREATE TABLE adhkar_categories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL
      )
    ''');

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

    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    try {
      final refsRaw = await rootBundle.loadString('assets/data/references.json');
      final refsData = jsonDecode(refsRaw)['references'] as List;
      for (var ref in refsData) {
        await db.insert('references', {
          'id': ref['id'],
          'book_name': ref['book_name'],
          'author': ref['author'] ?? '',
          'hadith_number': ref['hadith_number'] ?? '',
          'grade': ref['grade'] ?? '',
          'scholar': ref['scholar'] ?? '',
          'url': ref['url'] ?? '',
          'notes': ref['notes'] ?? '',
        });
      }

      final adhkarRaw = await rootBundle.loadString('assets/data/adhkar.json');
      final categories = jsonDecode(adhkarRaw)['categories'] as List;
      for (var cat in categories) {
        await db.insert('adhkar_categories', {
          'id': cat['id'],
          'title': cat['title'],
        });
        for (var item in cat['items']) {
          await db.insert('adhkar', {
            'id': item['id'],
            'category_id': cat['id'],
            'text': item['text'],
            'repeat_count': item['repeat'],
            'reference_id': item['reference_id'],
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('خطأ أثناء زرع البيانات: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('adhkar_categories');
  }

  Future<List<Map<String, dynamic>>> getAdhkarByCategory(String categoryId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, r.book_name, r.hadith_number, r.grade
      FROM adhkar a
      LEFT JOIN references r ON a.reference_id = r.id
      WHERE a.category_id = ?
    ''', [categoryId]);
  }
}
