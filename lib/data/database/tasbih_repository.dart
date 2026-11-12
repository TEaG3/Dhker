import 'dhker_database.dart';

/// Stores tasbih sessions and keeps a local daily count.
class TasbihRepository {
  TasbihRepository(this._database);

  final DhkerDatabase _database;

  Future<int> startSession({required String label, int target = 33}) async {
    if (target <= 0) throw ArgumentError.value(target, 'target');
    return _database.user.insert('tasbih_sessions', {
      'label_ar': label,
      'target_count': target,
      'count': 0,
      'started_at_utc': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> increment(int sessionId) => _database.user.transaction((txn) async {
        final changed = await txn.rawUpdate(
          '''UPDATE tasbih_sessions
             SET count = count + 1
             WHERE id = ? AND ended_at_utc IS NULL''',
          [sessionId],
        );
        if (changed != 1) throw StateError('جلسة التسبيح غير نشطة.');
        final rows = await txn.query(
          'tasbih_sessions',
          columns: ['count'],
          where: 'id = ?',
          whereArgs: [sessionId],
          limit: 1,
        );
        final count = rows.single['count'] as int;
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.rawInsert(
          '''INSERT INTO tasbih_daily_totals
             (local_date, total_count, session_count, updated_at_utc)
             VALUES (?, 1, 0, ?)
             ON CONFLICT(local_date) DO UPDATE SET
               total_count = total_count + 1,
               updated_at_utc = excluded.updated_at_utc''',
          [_localDate(DateTime.now()), now],
        );
        return count;
      });

  Future<void> finish(int sessionId) async {
    await _database.user.update(
      'tasbih_sessions',
      {'ended_at_utc': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND ended_at_utc IS NULL',
      whereArgs: [sessionId],
    );
  }

  static String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
