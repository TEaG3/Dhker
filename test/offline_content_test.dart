import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline content bundle', () {
    test('city catalog contains valid coordinates and Baghdad default', () async {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final cities = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

      expect(cities, isNotEmpty);
      expect(cities.any((city) => city['id'] == 'baghdad'), isTrue);

      for (final city in cities) {
        expect(city['id'], isA<String>());
        expect(city['name'], isA<String>());
        expect(city['lat'], isA<num>());
        expect(city['lng'], isA<num>());
        expect((city['lat'] as num).toDouble(), inInclusiveRange(-90, 90));
        expect((city['lng'] as num).toDouble(), inInclusiveRange(-180, 180));
      }
    });

    test('adhkar categories and repeat counts are populated', () async {
      final raw = await rootBundle.loadString('assets/data/adhkar.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final categories = (data['categories'] as List)
          .cast<Map<String, dynamic>>();

      expect(categories, isNotEmpty);
      for (final category in categories) {
        expect(category['id'], isA<String>());
        expect(category['title'], isA<String>());
        final items = (category['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items, isNotEmpty);
        for (final item in items) {
          expect(item['text'], isA<String>());
          expect((item['text'] as String).trim(), isNotEmpty);
          expect(item['repeat'], isA<int>());
          expect(item['repeat'] as int, greaterThan(0));
          expect(item['reference_id'], isA<String>());
        }
      }
    });

    test('adhkar references include every referenced source id', () async {
      final adhkarRaw = await rootBundle.loadString('assets/data/adhkar.json');
      final refsRaw = await rootBundle.loadString('assets/data/references.json');
      final categories =
          (jsonDecode(adhkarRaw)['categories'] as List).cast<Map<String, dynamic>>();
      final refs = (jsonDecode(refsRaw)['references'] as List)
          .cast<Map<String, dynamic>>();
      final refIds = refs.map((ref) => ref['id']).toSet();

      for (final category in categories) {
        for (final item in (category['items'] as List)) {
          expect(refIds, contains(item['reference_id']));
        }
      }
    });

    test('both downloaded adhan files are valid non-empty Ogg assets', () async {\n      for (final name in ['adhan_default.ogg', 'adhan_fajr.ogg']) {\n        final data = await rootBundle.load('assets/adhan/$name');\n        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);\n        expect(bytes.length, greaterThan(10000));\n        expect(String.fromCharCodes(bytes.take(4)), 'OggS');\n      }\n    });\n\n    test('adhan asset manifest documents the two offline recordings', () async {
      final raw = await rootBundle.loadString('assets/adhan/README.md');
      expect(raw, contains('adhan_default.ogg'));
      expect(raw, contains('adhan_fajr.ogg'));
      expect(raw, contains('CC0'));
      expect(raw, contains('wikimedia.org'));
    });
  });
}
