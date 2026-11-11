import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _databaseVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'dhikr.db');
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createReferencesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS source_references (
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
  }

  Future<void> _createAdhkarTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS adhkar_categories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS adhkar (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        text TEXT NOT NULL,
        repeat_count INTEGER NOT NULL,
        reference_id TEXT,
        FOREIGN KEY (category_id) REFERENCES adhkar_categories (id),
        FOREIGN KEY (reference_id) REFERENCES source_references (id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createReferencesTable(db);
    await _createAdhkarTables(db);
    await _seedDatabase(db);
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      final oldTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['references'],
      );
      final newTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['source_references'],
      );

      if (oldTable.isNotEmpty && newTable.isEmpty) {
        // Quote the legacy reserved identifier so SQLite can rename it safely.
        await db.execute(
          'ALTER TABLE "references" RENAME TO source_references',
        );
      } else if (newTable.isEmpty) {
        await _createReferencesTable(db);
      }

      await _createAdhkarTables(db);
    }
  }

  Future<void> _seedDatabase(Database db) async {
    final refsRaw = await rootBundle.loadString('assets/data/references.json');
    final refsData = jsonDecode(refsRaw)['references'] as List;
    for (final ref in refsData) {
      await db.insert(
        'source_references',
        {
          'id': ref['id'],
          'book_name': ref['book_name'],
          'author': ref['author'] ?? '',
          'hadith_number': ref['hadith_number'] ?? '',
          'grade': ref['grade'] ?? '',
          'scholar': ref['scholar'] ?? '',
          'url': ref['url'] ?? '',
          'notes': ref['notes'] ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final adhkarRaw = await rootBundle.loadString('assets/data/adhkar.json');
    final categories = jsonDecode(adhkarRaw)['categories'] as List;
    for (final category in categories) {
      await db.insert(
        'adhkar_categories',
        {
          'id': category['id'],
          'title': category['title'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final item in category['items']) {
        await db.insert(
          'adhkar',
          {
            'id': item['id'],
            'category_id': category['id'],
            'text': item['text'],
            'repeat_count': item['repeat'],
            'reference_id': item['reference_id'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('adhkar_categories');
  }

  Future<List<Map<String, dynamic>>> getAdhkarByCategory(
    String categoryId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT a.*, r.book_name, r.hadith_number, r.grade
      FROM adhkar a
      LEFT JOIN source_references r ON a.reference_id = r.id
      WHERE a.category_id = ?
      ''',
      [categoryId],
    );
  }
}
