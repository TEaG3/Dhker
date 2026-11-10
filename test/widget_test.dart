import 'dart:io';

import 'package:dhker/data/database/dhker_database.dart';
import 'package:dhker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('application starts with Android-first navigation', (tester) async {
    final directory = await Directory.systemTemp.createTemp('dhker-widget-');
    final database = await DhkerDatabase.open(directory: directory.path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await tester.pumpWidget(DhkerApp(database: database));
    await tester.pumpAndSettle();
    expect(find.text('المواقيت'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('القبلة'), findsOneWidget);
    expect(find.text('التسبيح'), findsOneWidget);
  });
}
