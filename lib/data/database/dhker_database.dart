import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite storage for the Dhker Android-first app.
class DhkerDatabase {
  DhkerDatabase._({required this.content, required this.user});

  static const int _contentVersion = 1;
  static const int _userVersion = 1;

  final Database content;
  final Database user;

  static Future<DhkerDatabase> open({String? directory}) async {
    final dbDirectory = directory ?? await getDatabasesPath();
    await Directory(dbDirectory).create(recursive: true);

    final contentDb = await openDatabase(
      p.join(dbDirectory, 'dhker_content.db'),
      version: _contentVersion,
      onConfigure: _enableForeignKeys,
      onCreate: _createContentSchema,
    );
    final userDb = await openDatabase(
      p.join(dbDirectory, 'dhker_user.db'),
      version: _userVersion,
      onConfigure: _enableForeignKeys,
      onCreate: _createUserSchema,
    );

    return DhkerDatabase._(content: contentDb, user: userDb);
  }

  static Future<void> _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _createContentSchema(Database db, int version) async {
    final statements = <String>[
      '''CREATE TABLE content_categories (
        id TEXT PRIMARY KEY,
        title_ar TEXT NOT NULL,
        title_en TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        icon_name TEXT,
        is_daily INTEGER NOT NULL DEFAULT 0 CHECK (is_daily IN (0, 1))
      )''',
      '''CREATE TABLE content_sources (
        id TEXT PRIMARY KEY,
        name_ar TEXT NOT NULL,
        source_url TEXT,
        license_name TEXT,
        license_url TEXT,
        attribution TEXT,
        license_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (license_status IN ('pending', 'approved', 'rejected')),
        reviewed_by TEXT,
        reviewed_at TEXT,
        notes TEXT
      )''',
      '''CREATE TABLE adhkar (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES content_categories(id),
        sort_order INTEGER NOT NULL DEFAULT 0,
        text_ar TEXT NOT NULL,
        text_normalized TEXT NOT NULL,
        repeat_count INTEGER NOT NULL DEFAULT 1 CHECK (repeat_count > 0),
        virtue_ar TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE adhkar_sources (
        adhkar_id TEXT NOT NULL REFERENCES adhkar(id) ON DELETE CASCADE,
        source_id TEXT NOT NULL REFERENCES content_sources(id),
        citation TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
        PRIMARY KEY (adhkar_id, source_id)
      )''',
      '''CREATE TABLE hadiths (
        id TEXT PRIMARY KEY,
        collection_name TEXT NOT NULL,
        hadith_number TEXT NOT NULL,
        text_ar TEXT,
        grade TEXT,
        grader TEXT,
        source_url TEXT,
        reviewed_by TEXT,
        reviewed_at TEXT,
        review_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (review_status IN ('pending', 'approved', 'rejected'))
      )''',
      '''CREATE TABLE adhkar_hadiths (
        adhkar_id TEXT NOT NULL REFERENCES adhkar(id) ON DELETE CASCADE,
        hadith_id TEXT NOT NULL REFERENCES hadiths(id),
        is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
        PRIMARY KEY (adhkar_id, hadith_id)
      )''',
      '''CREATE TABLE adhan_recordings (
        id TEXT PRIMARY KEY,
        title_ar TEXT NOT NULL,
        reciter_ar TEXT,
        asset_path TEXT,
        source_name TEXT NOT NULL,
        source_url TEXT,
        license_name TEXT,
        license_reference TEXT,
        license_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (license_status IN ('pending', 'approved', 'rejected')),
        sha256 TEXT,
        duration_seconds INTEGER,
        includes_fajr_phrase INTEGER NOT NULL DEFAULT 0
          CHECK (includes_fajr_phrase IN (0, 1)),
        reviewed_by TEXT,
        reviewed_at TEXT
      )''',
      '''CREATE TABLE content_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''',
      'CREATE INDEX idx_adhkar_category_order ON adhkar(category_id, sort_order)',
      'CREATE INDEX idx_adhkar_normalized ON adhkar(text_normalized)',
      'CREATE INDEX idx_hadiths_collection_number ON hadiths(collection_name, hadith_number)',
    ];

    for (final statement in statements) {
      await db.execute(statement);
    }

    final batch = db.batch();
    for (final category in _initialCategories) {
      batch.insert('content_categories', category);
    }
    batch.insert('content_metadata', {
      'key': 'schema_version',
      'value': version.toString(),
    });
    batch.insert('content_metadata', {
      'key': 'content_status',
      'value': 'categories_only_pending_reviewed_content',
    });
    await batch.commit(noResult: true);
  }

  static const List<Map<String, Object?>> _initialCategories = [
    {'id': 'morning', 'title_ar': 'أذكار الصباح', 'title_en': 'Morning', 'sort_order': 10, 'icon_name': 'wb_sunny', 'is_daily': 1},
    {'id': 'evening', 'title_ar': 'أذكار المساء', 'title_en': 'Evening', 'sort_order': 20, 'icon_name': 'nights_stay', 'is_daily': 1},
    {'id': 'after_prayer', 'title_ar': 'أذكار بعد الصلاة', 'title_en': 'After prayer', 'sort_order': 30, 'icon_name': 'mosque', 'is_daily': 0},
    {'id': 'sleep', 'title_ar': 'أذكار النوم', 'title_en': 'Before sleep', 'sort_order': 40, 'icon_name': 'bedtime', 'is_daily': 0},
    {'id': 'waking', 'title_ar': 'أذكار الاستيقاظ', 'title_en': 'Upon waking', 'sort_order': 50, 'icon_name': 'alarm', 'is_daily': 0},
    {'id': 'mosque', 'title_ar': 'أذكار المسجد', 'title_en': 'Mosque', 'sort_order': 60, 'icon_name': 'mosque', 'is_daily': 0},
    {'id': 'travel', 'title_ar': 'أذكار السفر', 'title_en': 'Travel', 'sort_order': 70, 'icon_name': 'flight', 'is_daily': 0},
    {'id': 'general', 'title_ar': 'أذكار متنوعة', 'title_en': 'General', 'sort_order': 80, 'icon_name': 'auto_awesome', 'is_daily': 0},
  ];

  static Future<void> _createUserSchema(Database db, int version) async {
    final statements = <String>[
      '''CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE saved_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label_ar TEXT NOT NULL,
        city_id TEXT,
        latitude REAL NOT NULL CHECK (latitude BETWEEN -90 AND 90),
        longitude REAL NOT NULL CHECK (longitude BETWEEN -180 AND 180),
        timezone TEXT NOT NULL,
        calculation_method_id INTEGER NOT NULL,
        asr_madhab TEXT NOT NULL DEFAULT 'shafi'
          CHECK (asr_madhab IN ('shafi', 'hanafi')),
        is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
        created_at TEXT NOT NULL
      )''',
      '''CREATE UNIQUE INDEX idx_saved_locations_single_default
        ON saved_locations(is_default) WHERE is_default = 1''',
      '''CREATE TABLE prayer_times_cache (
        location_id INTEGER NOT NULL REFERENCES saved_locations(id) ON DELETE CASCADE,
        date_local TEXT NOT NULL,
        timezone TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        calculation_method_id INTEGER NOT NULL,
        calculated_at_utc TEXT NOT NULL,
        PRIMARY KEY (location_id, date_local)
      )''',
      '''CREATE TABLE adhkar_progress (
        adhkar_id TEXT NOT NULL,
        local_date TEXT NOT NULL,
        category_id TEXT NOT NULL,
        done_count INTEGER NOT NULL DEFAULT 0 CHECK (done_count >= 0),
        target_count INTEGER NOT NULL CHECK (target_count > 0),
        completed_at_utc TEXT,
        updated_at_utc TEXT NOT NULL,
        PRIMARY KEY (adhkar_id, local_date)
      )''',
      '''CREATE TABLE tasbih_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label_ar TEXT NOT NULL,
        target_count INTEGER NOT NULL CHECK (target_count > 0),
        count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
        started_at_utc TEXT NOT NULL,
        ended_at_utc TEXT
      )''',
      '''CREATE TABLE tasbih_daily_totals (
        local_date TEXT PRIMARY KEY,
        total_count INTEGER NOT NULL DEFAULT 0 CHECK (total_count >= 0),
        session_count INTEGER NOT NULL DEFAULT 0 CHECK (session_count >= 0),
        updated_at_utc TEXT NOT NULL
      )''',
      '''CREATE TABLE quran_bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL CHECK (surah_number BETWEEN 1 AND 114),
        ayah_number INTEGER NOT NULL CHECK (ayah_number > 0),
        note TEXT,
        created_at_utc TEXT NOT NULL
      )''',
      '''CREATE TABLE quran_reading_position (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        surah_number INTEGER NOT NULL CHECK (surah_number BETWEEN 1 AND 114),
        ayah_number INTEGER NOT NULL CHECK (ayah_number > 0),
        page_number INTEGER CHECK (page_number IS NULL OR page_number > 0),
        updated_at_utc TEXT NOT NULL
      )''',
      '''CREATE TABLE adhan_preferences (
        prayer_key TEXT PRIMARY KEY CHECK
          (prayer_key IN ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')),
        enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
        recording_id TEXT,
        reminder_minutes INTEGER NOT NULL DEFAULT 0 CHECK (reminder_minutes >= 0),
        vibrate INTEGER NOT NULL DEFAULT 1 CHECK (vibrate IN (0, 1))
      )''',
      '''CREATE TABLE notification_schedules (
        notification_key TEXT PRIMARY KEY,
        prayer_key TEXT,
        location_id INTEGER REFERENCES saved_locations(id) ON DELETE SET NULL,
        scheduled_at_utc TEXT NOT NULL,
        kind TEXT NOT NULL CHECK
          (kind IN ('adhan', 'pre_adhan', 'adhkar', 'custom')),
        state TEXT NOT NULL DEFAULT 'scheduled' CHECK
          (state IN ('scheduled', 'fired', 'cancelled')),
        created_at_utc TEXT NOT NULL
      )''',
      '''CREATE TABLE downloaded_media (
        media_id TEXT PRIMARY KEY,
        kind TEXT NOT NULL CHECK (kind IN ('quran', 'adhan')),
        local_path TEXT NOT NULL,
        sha256 TEXT,
        size_bytes INTEGER CHECK (size_bytes IS NULL OR size_bytes >= 0),
        downloaded_at_utc TEXT NOT NULL
      )''',
      'CREATE INDEX idx_prayer_cache_date ON prayer_times_cache(date_local)',
      'CREATE INDEX idx_adhkar_progress_date ON adhkar_progress(local_date, category_id)',
      'CREATE INDEX idx_tasbih_started ON tasbih_sessions(started_at_utc)',
      'CREATE INDEX idx_notifications_time_state ON notification_schedules(scheduled_at_utc, state)',
    ];

    for (final statement in statements) {
      await db.execute(statement);
    }

    final batch = db.batch();
    for (final prayer in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      batch.insert('adhan_preferences', {'prayer_key': prayer});
    }
    batch.insert('app_settings', {
      'key': 'schema_version',
      'value': version.toString(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> getCategories() => content.query(
        'content_categories',
        orderBy: 'sort_order ASC',
      );

  Future<List<Map<String, Object?>>> getAdhkarForCategory(String categoryId) =>
      content.query(
        'adhkar',
        where: 'category_id = ? AND is_active = 1',
        whereArgs: [categoryId],
        orderBy: 'sort_order ASC',
      );

  Future<List<Map<String, Object?>>> searchAdhkar(String query) async {
    final term = query.trim();
    if (term.isEmpty) return [];
    return content.query(
      'adhkar',
      where: 'is_active = 1 AND text_normalized LIKE ?',
      whereArgs: ['%$term%'],
      orderBy: 'category_id ASC, sort_order ASC',
    );
  }

  Future<String?> getSetting(String key) async {
    final rows = await user.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await user.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAdhkarProgress({
    required String adhkarId,
    required String localDate,
    required String categoryId,
    required int doneCount,
    required int targetCount,
  }) async {
    if (targetCount <= 0) {
      throw ArgumentError.value(targetCount, 'targetCount', 'Must be greater than zero.');
    }
    final safeCount = doneCount.clamp(0, targetCount).toInt();
    final now = DateTime.now().toUtc().toIso8601String();
    await user.insert(
      'adhkar_progress',
      {
        'adhkar_id': adhkarId,
        'local_date': localDate,
        'category_id': categoryId,
        'done_count': safeCount,
        'target_count': targetCount,
        'completed_at_utc': safeCount >= targetCount ? now : null,
        'updated_at_utc': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getAdhkarProgressCount({
    required String adhkarId,
    required String localDate,
  }) async {
    final rows = await user.query(
      'adhkar_progress',
      columns: ['done_count'],
      where: 'adhkar_id = ? AND local_date = ?',
      whereArgs: [adhkarId, localDate],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['done_count'] as int;
  }

  Future<void> close() async {
    await content.close();
    await user.close();
  }
}
