import 'dart:convert';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/database/dhker_database.dart';
import 'data/database/tasbih_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await DhkerDatabase.open();
  runApp(DhkerApp(database: database));
}

class DhkerApp extends StatelessWidget {
  const DhkerApp({super.key, required this.database});

  final DhkerDatabase database;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ذِكر',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF103B35),
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.amiriTextTheme(ThemeData.dark().textTheme),
        ),
        home: MainTabs(database: database),
      );
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key, required this.database});

  final DhkerDatabase database;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      PrayerTimesScreen(database: widget.database),
      const QuranScreen(),
      AdhkarScreen(database: widget.database),
      QiblaScreen(database: widget.database),
      TasbihScreen(repository: TasbihRepository(widget.database)),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: screens)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mosque), label: 'المواقيت'),
          NavigationDestination(icon: Icon(Icons.book), label: 'القرآن'),
          NavigationDestination(icon: Icon(Icons.format_quote), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'القبلة'),
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'التسبيح'),
        ],
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key, required this.database});

  final DhkerDatabase database;

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _city;
  PrayerTimes? _times;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final cities = decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (cities.isEmpty) throw const FormatException('قائمة المدن فارغة');
      final cityId = await widget.database.getSetting('city_id') ?? 'baghdad';
      final city = cities.firstWhere(
        (item) => item['id'] == cityId,
        orElse: () => cities.first,
      );
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _city = city;
        _loading = false;
      });
      _recompute();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات المدن: $error';
        _loading = false;
      });
    }
  }

  Future<void> _selectCity(Map<String, dynamic> city) async {
    await widget.database.setSetting('city_id', city['id'].toString());
    if (!mounted) return;
    setState(() => _city = city);
    _recompute();
  }

  void _recompute() {
    final city = _city;
    if (city == null) return;
    try {
      final latitude = (city['lat'] as num).toDouble();
      final longitude = (city['lng'] as num).toDouble();
      final coordinates = Coordinates(latitude, longitude);
      final rawMethod = (city['method'] as num?)?.toInt() ?? 3;
      final methodIndex = rawMethod.clamp(0, CalculationMethod.values.length - 1);
      final parameters = CalculationMethod.values[methodIndex].getParameters();
      final calculated = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()),
        parameters,
      );
      if (!mounted) return;
      setState(() {
        _times = calculated;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حساب المواقيت: $error');
    }
  }

  String _formatTime(DateTime? date) =>
      date == null ? '—' : DateFormat.Hm('ar').format(date);

  String _prayerName(Prayer? prayer) {
    if (prayer == null) return '';
    const names = <Prayer, String>{
      Prayer.fajr: 'الفجر',
      Prayer.sunrise: 'الشروق',
      Prayer.dhuhr: 'الظهر',
      Prayer.asr: 'العصر',
      Prayer.maghrib: 'المغرب',
      Prayer.isha: 'العشاء',
      Prayer.none: '',
    };
    return names[prayer] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_city == null) return Center(child: Text(_error ?? 'لا تتوفر مدينة.'));
    final nextPrayer = _times?.nextPrayer();
    final nextTime = nextPrayer == null || nextPrayer == Prayer.none
        ? null
        : _times?.timeForPrayer(nextPrayer);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ذِكر', style: Theme.of(context).textTheme.headlineMedium),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_city),
            title: Text('${_city!['name']}'),
            subtitle: Text('${_city!['country']} • تغيير المدينة'),
            trailing: const Icon(Icons.edit_location_alt),
            onTap: _showCityPicker,
          ),
        ),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          ),
        if (_times != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('الصلاة القادمة: ${_prayerName(nextPrayer)}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_formatTime(nextTime),
                      style: Theme.of(context).textTheme.displayMedium),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                _prayerRow('الفجر', _times!.fajr),
                const Divider(height: 1),
                _prayerRow('الشروق', _times!.sunrise),
                const Divider(height: 1),
                _prayerRow('الظهر', _times!.dhuhr),
                const Divider(height: 1),
                _prayerRow('العصر', _times!.asr),
                const Divider(height: 1),
                _prayerRow('المغرب', _times!.maghrib),
                const Divider(height: 1),
                _prayerRow('العشاء', _times!.isha),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'تُحسب المواقيت محليًا وفق طريقة المدينة. يُرجى التأكد من ملاءمة طريقة الحساب لموقعك.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _prayerRow(String name, DateTime time) => ListTile(
        title: Text(name),
        trailing: Text(_formatTime(time),
            style: Theme.of(context).textTheme.titleMedium),
      );

  void _showCityPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: _cities.length,
          itemBuilder: (context, index) {
            final city = _cities[index];
            return ListTile(
              title: Text('${city['name']}'),
              subtitle: Text('${city['country']}'),
              trailing: city['id'] == _city?['id']
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _selectCity(city);
              },
            );
          },
        ),
      ),
    );
  }
}

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.database});

  final DhkerDatabase database;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final Future<List<Map<String, Object?>>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = widget.database.getCategories();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل التصنيفات: ${snapshot.error}'));
          }
          final categories = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('الأذكار', style: Theme.of(context).textTheme.headlineMedium),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'التصنيفات جاهزة. لن يُعرض متن ذكر قبل توثيق مصدره ومراجعته.',
                  ),
                ),
              ),
              for (final category in categories)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.format_quote),
                    title: Text('${category['title_ar']}'),
                    subtitle: const Text('لا توجد نصوص مراجعة مضافة بعد'),
                  ),
                ),
            ],
          );
        },
      );
}

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNumber = index + 1;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFC6A76A),
                child: Text('$surahNumber',
                    style: const TextStyle(
                        color: Color(0xFF081521), fontWeight: FontWeight.bold)),
              ),
              title: Text(getSurahNameArabic(surahNumber),
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 18)),
              subtitle: Text(
                  '${getVerseCount(surahNumber)} آية • ${getPlaceOfRevelation(surahNumber)}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SurahReaderScreen(
                    surahNumber: surahNumber,
                    surahName: getSurahNameArabic(surahNumber),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class SurahReaderScreen extends StatelessWidget {
  const SurahReaderScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
  });

  final int surahNumber;
  final String surahName;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(surahName), centerTitle: true),
        body: QuranSurahListView(surahNumber: surahNumber),
      );
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, required this.database});

  final DhkerDatabase database;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  Map<String, dynamic>? _city;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final cities = (jsonDecode(raw) as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final selectedId = await widget.database.getSetting('city_id') ?? 'baghdad';
      final city = cities.firstWhere(
        (item) => item['id'] == selectedId,
        orElse: () => cities.first,
      );
      if (mounted) setState(() => _city = city);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل المدينة: $error');
    }
  }

  double _bearing(double latitude, double longitude) {
    const kaabaLatitude = 21.4225;
    const kaabaLongitude = 39.8262;
    final lat1 = latitude * math.pi / 180;
    final lat2 = kaabaLatitude * math.pi / 180;
    final deltaLongitude = (kaabaLongitude - longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final city = _city;
    if (city == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Text(_error!),
      );
    }
    final bearing = _bearing(
      (city['lat'] as num).toDouble(),
      (city['lng'] as num).toDouble(),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore, size: 96, color: Color(0xFFC6A76A)),
            const SizedBox(height: 16),
            Text('اتجاه القبلة من ${city['name']}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${bearing.toStringAsFixed(1)}° من الشمال',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text(
              'الاتجاه محسوب من المدينة المختارة وليس من بوصلة الجهاز. اختر المدينة في صفحة المواقيت.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key, required this.repository});

  final TasbihRepository repository;

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  static const int _target = 33;
  static const String _label = 'سبحان الله';

  int? _sessionId;
  int _count = 0;
  bool _busy = false;

  Future<void> _increment() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = _sessionId ??= await widget.repository.startSession(
        label: _label,
        target: _target,
      );
      final count = await widget.repository.increment(id);
      if (mounted) setState(() => _count = count);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ التسبيح: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newSession() async {
    final id = _sessionId;
    if (id != null) await widget.repository.finish(id);
    if (!mounted) return;
    setState(() {
      _sessionId = null;
      _count = 0;
    });
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التسبيح', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(_label, style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              Text('$_count / $_target',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _busy ? null : _increment,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(170, 170),
                  shape: const CircleBorder(),
                ),
                child: const Text('سَبِّح', style: TextStyle(fontSize: 28)),
              ),
              TextButton.icon(
                onPressed: _newSession,
                icon: const Icon(Icons.restart_alt),
                label: const Text('جلسة جديدة'),
              ),
              const Text('يُحفظ التقدم محليًا على الجهاز.'),
            ],
          ),
        ),
      );
}
// استيراد الشاشات الجديدة
import 'screens/adhkar_screen.dart';
import 'screens/adhan_screen.dart';

// داخل _MainTabsState
final screens = [
  const PrayerTimesScreen(),
  const QuranScreen(),
  const AdhkarScreen(),      // شاشة الأذكار الجديدة
  const AdhanScreen(),       // شاشة الأذان الجديدة
];

// في NavigationBar
destinations: const [
  NavigationDestination(icon: Icon(Icons.mosque), label: 'المواقيت'),
  NavigationDestination(icon: Icon(Icons.book), label: 'القرآن'),
  NavigationDestination(icon: Icon(Icons.format_quote), label: 'الأذكار'),
  NavigationDestination(icon: Icon(Icons.notifications_active), label: 'الأذان'),
],
