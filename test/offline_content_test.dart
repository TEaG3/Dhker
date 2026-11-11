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
      final categories =
          (data['categories'] as List).cast<Map<String, dynamic>>();

      expect(categories, isNotEmpty);
      for (final category in categories) {
        expect(category['id'], isA<String>());
        expect(category['title'], isA<String>());
        final items =
            (category['items'] as List).cast<Map<String, dynamic>>();
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
          (jsonDecode(adhkarRaw)['categories'] as List)
              .cast<Map<String, dynamic>>();
      final refs = (jsonDecode(refsRaw)['references'] as List)
          .cast<Map<String, dynamic>>();
      final refIds = refs.map((ref) => ref['id']).toSet();

      for (final category in categories) {
        for (final item in (category['items'] as List)) {
          expect(refIds, contains(item['reference_id']));
        }
      }
    });

    test('all ten Kiwifu adhan recordings are bundled as MP3 assets', () async {
      const recordings = [
        'adhan_muhammad_ramadan_saad.mp3',
        'adhan_ali_ibn_ahmad_mala.mp3',
        'adhan_muhammad_khaleel_raml.mp3',
        'adhan_nayf_fedah.mp3',
        'adhan_faruq_abdul_rahman_hadrawe.mp3',
        'adhan_assem_bukhrare.mp3',
        'adhan_nurdin_hamza_al_maghriby.mp3',
        'adhan_najee_qazaz.mp3',
        'adhan_mishary_rashid_alafasy.mp3',
        'adhan_abdulbasit_abdusamad.mp3',
      ];

      expect(recordings.toSet(), hasLength(10));
      for (final name in recordings) {
        final data = await rootBundle.load('assets/adhan/$name');
        expect(data.lengthInBytes, greaterThan(10000), reason: name);
      }
    });

    test('adhan asset manifest documents the ten Kiwifu recordings', () async {
      final raw = await rootBundle.loadString('assets/adhan/README.md');
      expect(raw, contains('Kiwifu/adhan-mp3'));
      expect(raw, contains('محمد رمضان سعد'));
      expect(raw, contains('علي بن أحمد ملا'));
      expect(raw, contains('محمد خليل رمل'));
      expect(raw, contains('نايف فداح'));
      expect(raw, contains('فاروق عبدالرحمن حضراوي'));
      expect(raw, contains('عاصم بخراري'));
      expect(raw, contains('نور الدين حمزة المغربي'));
      expect(raw, contains('ناجي قزاز'));
      expect(raw, contains('مشاري راشد العفاسي'));
      expect(raw, contains('عبد الباسط عبد الصمد'));
    });
  });
}
