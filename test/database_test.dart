import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dhker/data/database/dhker_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('creates content and user schemas with starter categories', () async {
    final directory = await Directory.systemTemp.createTemp('dhker-db-');
    final database = await DhkerDatabase.open(directory: directory.path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final categories = await database.getCategories();
    expect(categories, hasLength(8));
    expect(categories.first['id'], 'morning');
    expect(await database.getSetting('schema_version'), '1');
    expect(await database.getAdhkarForCategory('morning'), isEmpty);
  });

  test('persists settings and daily adhkar progress', () async {
    final directory = await Directory.systemTemp.createTemp('dhker-db-');
    final database = await DhkerDatabase.open(directory: directory.path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await database.setSetting('city_id', 'baghdad');
    expect(await database.getSetting('city_id'), 'baghdad');

    await database.saveAdhkarProgress(
      adhkarId: 'test-entry',
      localDate: '2026-11-10',
      categoryId: 'morning',
      doneCount: 2,
      targetCount: 3,
    );
    expect(
      await database.getAdhkarProgressCount(
        adhkarId: 'test-entry',
        localDate: '2026-11-10',
      ),
      2,
    );
  });

  test('rejects invalid counter targets', () async {
    final directory = await Directory.systemTemp.createTemp('dhker-db-');
    final database = await DhkerDatabase.open(directory: directory.path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    expect(
      () => database.saveAdhkarProgress(
        adhkarId: 'test-entry',
        localDate: '2026-11-10',
        categoryId: 'morning',
        doneCount: 0,
        targetCount: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
