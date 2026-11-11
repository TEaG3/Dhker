import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart';
import 'package:quran_library/quran_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/adhan_screen.dart';
import 'screens/adhkar_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/quran_library_preview_screen.dart';
import 'services/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HijriDate.setLocal('ar');
  await DatabaseHelper().database;
  await QuranLibrary.init();
  runApp(const DhikrApp());
}

class DhikrApp extends StatefulWidget {
  const DhikrApp({
    super.key,
    this.enableClock = true,
    this.testMode = false,
  });

  final bool enableClock;
  final bool testMode;

  @override
  State<DhikrApp> createState() => _DhikrAppState();
}

class _DhikrAppState extends State<DhikrApp> {
  int _themeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _themeIndex = preferences.getInt('dhker_theme') ?? 0);
  }

  Future<void> _setTheme(int index) async {
    setState(() => _themeIndex = index.clamp(0, 2));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('dhker_theme', _themeIndex);
  }

  ThemeData _themeFor(int index) {
    final light = index == 1;
    final seed = index == 2
        ? const Color(0xFF2879A8)
        : const Color(0xFF247C67);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: light ? Brightness.light : Brightness.dark,
      surface: light ? const Color(0xFFF6F2E9) : const Color(0xFF0D2028),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          light ? const Color(0xFFF4F0E6) : const Color(0xFF081521),
      appBarTheme: AppBarTheme(
        backgroundColor: light ? const Color(0xFFF4F0E6) : const Color(0xFF081521),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: light ? const Color(0xFFFFFCF5) : const Color(0xFF102C2B),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: light
                ? const Color(0xFFD7C7A2)
                : const Color(0x35C6A76A),
          ),
        ),
      ),
      textTheme: GoogleFonts.amiriTextTheme(
        ThemeData(brightness: light ? Brightness.light : Brightness.dark)
            .textTheme,
      ),
    );
  }

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
      theme: _themeFor(_themeIndex),
      home: MainTabs(
        themeIndex: _themeIndex,
        onThemeChanged: _setTheme,
        enableClock: widget.enableClock,
        testMode: widget.testMode,
      ),
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({
    super.key,
    required this.themeIndex,
    required this.onThemeChanged,
    this.enableClock = true,
    this.testMode = false,
  });

  final int themeIndex;
  final ValueChanged<int> onThemeChanged;
  final bool enableClock;
  final bool testMode;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: widget.testMode
              ? const [
                  Center(child: Text('المواقيت')),
                  Center(child: Text('القرآن')),
                  Center(child: Text('الأذكار')),
                  Center(child: Text('الأذان')),
                ]
              : [
                  PrayerTimesScreen(
                    themeIndex: widget.themeIndex,
                    onThemeChanged: widget.onThemeChanged,
                    enableClock: widget.enableClock,
                  ),
                  const QuranLibraryPreviewScreen(),
                  const AdhkarScreen(),
                  const AdhanScreen(),
                ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.house),
            selectedIcon: Icon(Icons.home_filled),
            label: 'المواقيت',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bookOpen),
            selectedIcon: Icon(Icons.menu_book),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bookMarked),
            selectedIcon: Icon(Icons.bookmark),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bell),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'الأذان',
          ),
        ],
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({
    super.key,
    required this.themeIndex,
    required this.onThemeChanged,
    this.enableClock = true,
  });

  final int themeIndex;
  final ValueChanged<int> onThemeChanged;
  final bool enableClock;

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _city;
  PrayerTimes? _times;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  String? _error;
  int _clockStyle = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enableClock) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
    _loadCities();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recompute();
      setState(() => _now = DateTime.now());
    }
  }

  Future<void> _loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) throw const FormatException('قائمة المدن فارغة');

      final preferences = await SharedPreferences.getInstance();
      final savedId = preferences.getString('city_id') ?? 'baghdad';
      final savedClockStyle = preferences.getInt('dhker_clock_style') ?? 0;
      final city = list.firstWhere(
        (item) => item['id'] == savedId,
        orElse: () => list.first,
      );

      if (!mounted) return;
      setState(() {
        _cities = list;
        _city = city;
        _clockStyle = savedClockStyle.clamp(0, 2);
      });
      _recompute();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل المدن: $error');
    }
  }

  void _recompute() {
    final city = _city;
    if (city == null) return;

    try {
      final coordinates = Coordinates(
        (city['lat'] as num).toDouble(),
        (city['lng'] as num).toDouble(),
      );
      final methodIndex = (city['method'] as num)
          .toInt()
          .clamp(0, CalculationMethod.values.length - 1);
      final parameters =
          CalculationMethod.values[methodIndex].getParameters();
      final times = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()),
        parameters,
      );

      if (!mounted) return;
      setState(() {
        _times = times;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر حساب المواقيت: $error');
    }
  }

  Future<void> _selectCity(Map<String, dynamic> city) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('city_id', city['id'] as String);
    if (!mounted) return;
    setState(() => _city = city);
    _recompute();
  }

  Future<void> _cycleClockStyle() async {
    final next = (_clockStyle + 1) % 3;
    setState(() => _clockStyle = next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('dhker_clock_style', next);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    return DateFormat.Hm('ar').format(time);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(_softRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final hijri = HijriDate.fromDate(_now);
    final hijriLabel = '${hijri.toFormat('dd MMMM yyyy')} هـ';
    final gregorianLabel =
        DateFormat('EEEE، d MMMM yyyy', 'ar').format(_now);
    final nextPrayer = _times?.nextPrayer();
    final nextPrayerTime = nextPrayer == null || nextPrayer == Prayer.none
        ? null
        : _times?.timeForPrayer(nextPrayer);

    final prayerRows = _times == null
        ? <_PrayerRowData>[]
        : <_PrayerRowData>[
            _PrayerRowData('الفجر', _times!.fajr, LucideIcons.sunrise, 'fajr'),
            _PrayerRowData('الشروق', _times!.sunrise, LucideIcons.sun, 'sunrise'),
            _PrayerRowData('الظهر', _times!.dhuhr, Icons.wb_sunny_outlined, 'dhuhr'),
            _PrayerRowData('العصر', _times!.asr, Icons.wb_cloudy_outlined, 'asr'),
            _PrayerRowData('المغرب', _times!.maghrib, LucideIcons.sunset, 'maghrib'),
            _PrayerRowData('العشاء', _times!.isha, LucideIcons.moon, 'isha'),
          ];

    return RefreshIndicator(
      onRefresh: () async {
        _recompute();
        setState(() => _now = DateTime.now());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ذِكر',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC6A76A),
                          ),
                    ),
                    Text(
                      'سكينة ترافق يومك',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              _HeaderAction(
                icon: LucideIcons.compass,
                tooltip: 'معاينة البوصلة',
                onTap: () => _openPage(const QiblaScreen()),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: LucideIcons.palette,
                tooltip: 'تغيير الواجهة',
                onTap: () => _showThemePicker(context),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
          const SizedBox(height: 16),
          _BrandVerseCard().animate().fadeIn(delay: 80.ms).slideY(begin: 0.04),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(_city?['name']?.toString() ?? 'اختر المدينة'),
              subtitle: Text(_city?['country']?.toString() ?? 'الموقع'),
              trailing: const Icon(Icons.expand_more),
              onTap: () => _showCityPicker(context),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'الوقت الآن',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _cycleClockStyle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF103B35), Color(0xFF081521)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x55C6A76A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: _clockStyle == 1
                        ? SizedBox(
                            key: const ValueKey('analog'),
                            height: 142,
                            width: 142,
                            child: CustomPaint(
                              painter: _ClockPainter(_now),
                            ),
                          )
                        : Text(
                            DateFormat(
                              _clockStyle == 2 ? 'HH:mm' : 'HH:mm:ss',
                              'ar',
                            ).format(_now),
                            key: ValueKey(_clockStyle),
                            style: TextStyle(
                              color: const Color(0xFFF3DFB2),
                              fontSize: _clockStyle == 2 ? 48 : 42,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'انقر لتغيير شكل الساعة',
                    style: TextStyle(
                      color: Color(0xFFB2C7C0),
                      fontSize: 12,
                    ),
                  ),
                  if (nextPrayer != null && nextPrayer != Prayer.none) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x25C6A76A),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        'الصلاة القادمة: ${_prayerName(nextPrayer)} • ${_formatTime(nextPrayerTime)}',
                        style: const TextStyle(color: Color(0xFFF3DFB2)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPage(const HijriCalendarScreen()),
            child: Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'التاريخ الهجري',
                    value: hijriLabel,
                    icon: LucideIcons.moonStar,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: 'التاريخ الميلادي',
                    value: gregorianLabel,
                    icon: LucideIcons.calendarDays,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _HijriCalendarPreview(
            date: _now,
            onTap: () => _openPage(const HijriCalendarScreen()),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'مواقيت الصلاة اليوم',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Text(
                DateFormat('d MMMM', 'ar').format(_now),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < prayerRows.length; index++) ...[
                  _PrayerTimeTile(
                    row: prayerRows[index],
                    time: _formatTime(prayerRows[index].time),
                    isNext: nextPrayer?.name == prayerRows[index].id,
                  ),
                  if (index != prayerRows.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
                if (_times == null)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'وصول سريع',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.compass,
                  label: 'القبلة',
                  onTap: () => _openPage(const QiblaScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.calendarDays,
                  label: 'التقويم',
                  onTap: () => _openPage(const HijriCalendarScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.bell,
                  label: 'إعدادات الأذان',
                  onTap: () => _openPage(const AdhanScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _prayerName(Prayer prayer) {
    const names = {
      Prayer.fajr: 'الفجر',
      Prayer.sunrise: 'الشروق',
      Prayer.dhuhr: 'الظهر',
      Prayer.asr: 'العصر',
      Prayer.maghrib: 'المغرب',
      Prayer.isha: 'العشاء',
      Prayer.none: '—',
    };
    return names[prayer] ?? '—';
  }

  Future<void> _showCityPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: _cities.length,
          itemBuilder: (context, index) {
            final city = _cities[index];
            final selected = city['id'] == _city?['id'];
            return ListTile(
              title: Text(city['name'].toString()),
              subtitle: Text(city['country'].toString()),
              trailing: selected ? const Icon(Icons.check_circle) : null,
              onTap: () {
                Navigator.pop(sheetContext);
                _selectCity(city);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showThemePicker(BuildContext context) async {
    const choices = [
      ('الأخضر والذهبي', Color(0xFF103B35)),
      ('الورق الفاتح', Color(0xFFF4F0E6)),
      ('الأزرق الليلي', Color(0xFF123D59)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر مظهر التطبيق',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < choices.length; i++)
                ListTile(
                  leading: CircleAvatar(backgroundColor: choices[i].$2),
                  title: Text(choices[i].$1),
                  trailing: widget.themeIndex == i
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    widget.onThemeChanged(i);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandVerseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123E36), Color(0xFF0B2429)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55C6A76A)),
      ),
      child: const Column(
        children: [
          Text(
            '✦  وَذَكِّرْ فَإِنَّ الذِّكْرَىٰ تَنفَعُ الْمُؤْمِنِينَ  ✦',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF3DFB2),
              fontSize: 19,
              height: 1.6,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'طمأنينة في يومك، وقرب من الله',
            style: TextStyle(color: Color(0xFFB2C7C0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.alignment,
  });

  final String label;
  final String value;
  final IconData icon;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Icon(icon, size: 17, color: const Color(0xFFC6A76A)),
            const SizedBox(height: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: alignment == CrossAxisAlignment.start
                  ? TextAlign.start
                  : TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerRowData {
  const _PrayerRowData(this.label, this.time, this.icon, this.id);
  final String label;
  final DateTime time;
  final IconData icon;
  final String id;
}

class _PrayerTimeTile extends StatelessWidget {
  const _PrayerTimeTile({
    required this.row,
    required this.time,
    required this.isNext,
  });

  final _PrayerRowData row;
  final String time;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: isNext ? const Color(0x1FC6A76A) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          row.icon,
          color: isNext ? const Color(0xFFC6A76A) : colors.onSurfaceVariant,
        ),
        title: Text(
          row.label,
          style: TextStyle(
            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNext)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 8),
                child: Icon(Icons.radio_button_checked,
                    size: 15, color: Color(0xFFC6A76A)),
              ),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isNext ? const Color(0xFFC6A76A) : colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 24, color: const Color(0xFFC6A76A)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05);
  }
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter(this.time);
  final DateTime time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final gold = Paint()
      ..color = const Color(0xFFC6A76A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, gold);
    canvas.drawCircle(
      center,
      radius - 6,
      Paint()
        ..color = const Color(0xFF42C6A5).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final major = i % 5 == 0;
      final outer = radius - 8;
      final inner = radius - (major ? 19 : 13);
      canvas.drawLine(
        center + Offset(math.sin(angle) * inner, -math.cos(angle) * inner),
        center + Offset(math.sin(angle) * outer, -math.cos(angle) * outer),
        Paint()
          ..color = major ? const Color(0xFFF3DFB2) : const Color(0xFF78948C)
          ..strokeWidth = major ? 2 : 1,
      );
    }

    final hour = (time.hour % 12) + time.minute / 60;
    final minute = time.minute + time.second / 60;
    final second = time.second.toDouble();
    _hand(canvas, center, radius * 0.48, hour * math.pi / 6, 4,
        const Color(0xFFF3DFB2));
    _hand(canvas, center, radius * 0.67, minute * math.pi / 30, 2.5,
        const Color(0xFF42C6A5));
    _hand(canvas, center, radius * 0.76, second * math.pi / 30, 1,
        const Color(0xFFC6A76A));
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFFC6A76A));
  }

  void _hand(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    double width,
    Color color,
  ) {
    canvas.drawLine(
      center,
      center + Offset(math.sin(angle) * length, -math.cos(angle) * length),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.time.second != time.second;
}

class _HijriCalendarPreview extends StatelessWidget {
  const _HijriCalendarPreview({
    required this.date,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onTap;

  static const _weekDays = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

  @override
  Widget build(BuildContext context) {
    final today = HijriDate.fromDate(date);
    final month = HijriDate.fromHijri(today.hYear, today.hMonth, 1);
    final monthLength = month.lengthOfMonth;
    final firstGregorian = month.hijriToGregorian(today.hYear, today.hMonth, 1);
    final offset = firstGregorian.weekday % 7;
    final cellCount = ((offset + monthLength + 6) ~/ 7) * 7;
    final days = List<int>.generate(cellCount, (index) {
      final day = index - offset + 1;
      return day >= 1 && day <= monthLength ? day : 0;
    });

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.calendarDays,
                    color: Color(0xFFC6A76A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'التقويم الهجري',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    '${month.getLongMonthName()} ${today.hYear} هـ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronLeft, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final dayName in _weekDays)
                    Expanded(
                      child: Center(
                        child: Text(
                          dayName,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.65,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];
                  if (day == 0) return const SizedBox.shrink();
                  final isToday = day == today.hDay;
                  final scheme = Theme.of(context).colorScheme;
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? scheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isToday ? scheme.onPrimary : scheme.onSurface,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'اضغط لفتح التقويم الكامل',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late int _month;
  late int _year;
  int? _selectedDay;

  static const _weekDays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  @override
  void initState() {
    super.initState();
    final today = HijriDate.now();
    _month = today.hMonth;
    _year = today.hYear;
    _selectedDay = today.hDay;
  }

  void _moveMonth(int delta) {
    var month = _month + delta;
    var year = _year;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    setState(() {
      _month = month;
      _year = year;
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthDate = HijriDate.fromHijri(_year, _month, 1);
    final monthLength = monthDate.lengthOfMonth;
    final firstGregorian = monthDate.hijriToGregorian(_year, _month, 1);
    final offset = firstGregorian.weekday % 7;
    final today = HijriDate.now();
    final cells = List<int>.generate(42, (index) {
      final day = index - offset + 1;
      return day >= 1 && day <= monthLength ? day : 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم الهجري'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _moveMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          monthDate.getLongMonthName(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('$_year هـ'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final day in _weekDays)
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cells.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      final day = cells[index];
                      final isToday = day == today.hDay &&
                          _month == today.hMonth &&
                          _year == today.hYear;
                      final selected = day != 0 && day == _selectedDay;
                      if (day == 0) return const SizedBox.shrink();

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : isToday
                                    ? const Color(0x25C6A76A)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !selected
                                ? Border.all(color: const Color(0xFFC6A76A))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              day.toString(),
                              style: TextStyle(
                                color: selected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                                fontWeight: isToday || selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDay != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  LucideIcons.calendarDays,
                  color: Color(0xFFC6A76A),
                ),
                title: Text('$_selectedDay ${monthDate.getLongMonthName()} $_year هـ'),
                subtitle: Text(
                  DateFormat('EEEE، d MMMM yyyy', 'ar').format(
                    monthDate.hijriToGregorian(_year, _month, _selectedDay!),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final surahs = List<int>.generate(114, (index) => index + 1)
        .where((number) => getSurahNameArabic(number).contains(_query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'معاينة مكتبة المصحف الجديدة',
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () {
              Navigator.of(context).push(
                _softRoute(const QuranLibraryPreviewScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              textDirection: ui.TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن سورة...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              itemCount: surahs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final number = surahs[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFC6A76A),
                      foregroundColor: const Color(0xFF081521),
                      child: Text('$number'),
                    ),
                    title: Text(
                      getSurahNameArabic(number),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${getVerseCount(number)} آية • ${getPlaceOfRevelation(number)}',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () {
                      Navigator.of(context).push(
                        _softRoute(
                          QuranReaderScreen(
                            surahNumber: number,
                            surahName: getSurahNameArabic(number),
                          ),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(duration: 220.ms);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
  });

  final int surahNumber;
  final String surahName;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late final PageController _pageController;
  late int _pageNumber;

  @override
  void initState() {
    super.initState();
    _pageNumber = getPageNumber(widget.surahNumber, 1);
    _pageController = PageController(initialPage: _pageNumber - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showAyahActions(int surah, int ayah) {
    final text = getVerse(surah, ayah);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${getSurahNameArabic(surah)} • الآية $ayah',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, height: 1.9),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ الآية'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surahName),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: Text('صفحة $_pageNumber / 604')),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF2E8D3),
        child: QuranPageView(
          pageController: _pageController,
          highlights: const <HighlightVerse>[],
          isDarkMode: false,
          scrollDirection: Axis.horizontal,
          pageSnapping: true,
          pageBackgroundColor: const Color(0xFFF9F2E3),
          pagePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPageChanged: (pageNumber) {
            setState(() => _pageNumber = pageNumber);
          },
          onLongPress: (surahNumber, verseNumber) {
            _showAyahActions(surahNumber, verseNumber);
          },
        ),
      ),
    );
  }
}

Route<void> _softRoute(Widget page) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
