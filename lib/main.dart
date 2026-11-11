import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/database_helper.dart';
import 'screens/adhan_screen.dart';
import 'screens/adhkar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة قاعدة البيانات
  await DatabaseHelper().database;
  
  runApp(const DhikrApp());
}

class DhikrApp extends StatelessWidget {
  const DhikrApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const MainTabs(),
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const PrayerTimesScreen(),
      const QuranScreen(),
      const AdhkarScreen(),
      const AdhanScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mosque), label: 'المواقيت'),
          NavigationDestination(icon: Icon(Icons.book), label: 'القرآن'),
          NavigationDestination(icon: Icon(Icons.format_quote), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.notifications_active), label: 'الأذان'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. شاشة المواقيت
// ==========================================
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _city;
  PrayerTimes? _times;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('city_id') ?? 'baghdad';
      final city = list.firstWhere((c) => c['id'] == savedId, orElse: () => list.first);
      
      if (!mounted) return;
      setState(() {
        _cities = list;
        _city = city;
      });
      _recompute();
    } catch (e) {
      setState(() => _error = 'فشل تحميل المدن: $e');
    }
  }

  Future<void> _selectCity(Map<String, dynamic> city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city_id', city['id']);
    setState(() => _city = city);
    _recompute();
  }

  void _recompute() {
    try {
      final c = _city!;
      final coordinates = Coordinates((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
      final method = CalculationMethod.values[((c['method'] as num).toInt()).clamp(0, CalculationMethod.values.length - 1)];
      final params = method.getParameters();
      final date = DateComponents.from(DateTime.now());
      final times = PrayerTimes(coordinates, date, params);
      
      setState(() {
        _times = times;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'خطأ في الحساب: $e');
    }
  }

  String _fmt(DateTime? d) => d == null ? '—' : DateFormat.Hm('ar').format(d);

  @override
  Widget build(BuildContext context) {
    if (_city == null) return const Center(child: CircularProgressIndicator());
    
    final next = _times?.nextPrayer();
    final nextName = _nextPrayerName(next);
    DateTime? nextTime;
    if (next != null && next != Prayer.none) {
      nextTime = _times?.timeForPrayer(next);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_city),
            title: Text('${_city!['name']}'),
            subtitle: Text('${_city!['country']}'),
            trailing: const Icon(Icons.edit_location_alt),
            onTap: () => _showCityPicker(context),
          ),
        ),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          ),
        if (_times != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(nextName.isEmpty ? '—' : 'الصلاة القادمة: $nextName', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_fmt(nextTime), style: Theme.of(context).textTheme.displayMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _row('الفجر', _times?.fajr),
                const Divider(height: 1),
                _row('الشروق', _times?.sunrise),
                const Divider(height: 1),
                _row('الظهر', _times?.dhuhr),
                const Divider(height: 1),
                _row('العصر', _times?.asr),
                const Divider(height: 1),
                _row('المغرب', _times?.maghrib),
                const Divider(height: 1),
                _row('العشاء', _times?.isha),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, DateTime? time) {
    return ListTile(
      title: Text(label),
      trailing: Text(_fmt(time), style: Theme.of(context).textTheme.titleMedium),
    );
  }

  String _nextPrayerName(Prayer? p) {
    if (p == null) return '';
    const names = {
      Prayer.fajr: 'الفجر',
      Prayer.sunrise: 'الشروق',
      Prayer.dhuhr: 'الظهر',
      Prayer.asr: 'العصر',
      Prayer.maghrib: 'المغرب',
      Prayer.isha: 'العشاء',
      Prayer.none: '',
    };
    return names[p] ?? '';
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: _cities.length,
          itemBuilder: (_, i) {
            final c = _cities[i];
            final selected = c['id'] == _city?['id'];
            return ListTile(
              title: Text('${c['name']}'),
              subtitle: Text('${c['country']}'),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(context);
                _selectCity(c);
              },
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة القرآن
// ==========================================
class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 114,
      itemBuilder: (context, index) {
        final surahNumber = index + 1;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFC6A76A),
              child: Text('$surahNumber', style: const TextStyle(color: Color(0xFF081521), fontWeight: FontWeight.bold)),
            ),
            title: Text(getSurahNameArabic(surahNumber), style: const TextStyle(fontFamily: 'Amiri', fontSize: 18)),
            subtitle: Text('${getVerseCount(surahNumber)} آية • ${getPlaceOfRevelation(surahNumber)}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SurahReaderScreen(surahNumber: surahNumber, surahName: getSurahNameArabic(surahNumber)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class SurahReaderScreen extends StatelessWidget {
  final int surahNumber;
  final String surahName;
  const SurahReaderScreen({super.key, required this.surahNumber, required this.surahName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surahName),
        centerTitle: true,
        backgroundColor: const Color(0xFF103B35),
      ),
      body: QuranSurahListView(surahNumber: surahNumber),
    );
  }
}
