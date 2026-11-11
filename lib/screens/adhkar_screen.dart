import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = DatabaseHelper().getCategories();
  }

  IconData _categoryIcon(String id) {
    switch (id) {
      case 'morning':
        return LucideIcons.sunrise;
      case 'evening':
        return LucideIcons.sunset;
      case 'sleep':
        return LucideIcons.moon;
      case 'waking':
        return LucideIcons.alarmClock;
      case 'after_prayer':
        return LucideIcons.bellRing;
      case 'mosque':
        return LucideIcons.building2;
      case 'travel':
        return LucideIcons.plane;
      default:
        return LucideIcons.bookOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: 'تعذر تحميل الأذكار: ${snapshot.error}',
              onRetry: () => setState(
                () => _categoriesFuture = DatabaseHelper().getCategories(),
              ),
            );
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('لا توجد فئات أذكار متاحة حالياً.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF103B35), Color(0xFF081521)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x55C6A76A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'وردك اليومي',
                      style: TextStyle(
                        color: Color(0xFFF3DFB2),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'اختر الذكر، واقرأه، وسجّل تكرارك اليومي.',
                      style: TextStyle(color: Color(0xFFB2C7C0)),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
              const SizedBox(height: 18),
              Text(
                'فئات الأذكار',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < categories.length; index++)
                _CategoryCard(
                  category: categories[index],
                  icon: _categoryIcon(categories[index]['id'].toString()),
                  index: index,
                ),
              const SizedBox(height: 12),
              Text(
                'تُعرض النصوص ومراجعها كما وردت في قاعدة بيانات التطبيق. '
                'عدد الأذكار المتاح يعتمد على المحتوى المضاف والمراجع المعتمدة.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.icon,
    required this.index,
  });

  final Map<String, dynamic> category;
  final IconData icon;
  final int index;

  @override
  Widget build(BuildContext context) {
    final title = category['title']?.toString() ?? 'الأذكار';
    final id = category['id']?.toString() ?? '';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getAdhkarByCategory(id),
      builder: (context, snapshot) {
        final count = snapshot.data?.length;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) =>
                      AdhkarDetailScreen(categoryId: id, title: title),
                  transitionDuration: const Duration(milliseconds: 280),
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
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x22C6A76A),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: const Color(0xFFC6A76A)),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          count == null ? 'جارٍ تحميل العدد...' : '$count أذكار',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(
              delay: Duration(milliseconds: 35 * index),
              duration: 240.ms,
            );
      },
    );
  }
}

class AdhkarDetailScreen extends StatefulWidget {
  const AdhkarDetailScreen({
    super.key,
    required this.categoryId,
    required this.title,
  });

  final String categoryId;
  final String title;

  @override
  State<AdhkarDetailScreen> createState() => _AdhkarDetailScreenState();
}

class _AdhkarDetailScreenState extends State<AdhkarDetailScreen> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  final Map<String, int> _progress = {};
  bool _progressLoaded = false;
  String _dateKey = _todayKey();

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}$month$day';
  }

  @override
  void initState() {
    super.initState();
    _itemsFuture = DatabaseHelper().getAdhkarByCategory(widget.categoryId);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final today = _todayKey();
    final items = await _itemsFuture;
    final loaded = <String, int>{};
    for (final item in items) {
      final id = item['id'].toString();
      final target = (item['repeat_count'] as num?)?.toInt() ?? 1;
      final stored = preferences.getInt('adhkar_count_${today}_$id') ?? 0;
      loaded[id] = stored.clamp(0, target).toInt();
    }
    if (!mounted) return;
    setState(() {
      _dateKey = today;
      _progress
        ..clear()
        ..addAll(loaded);
      _progressLoaded = true;
    });
  }

  Future<void> _setCount(String id, int count, int target) async {
    final safe = count.clamp(0, target).toInt();
    setState(() => _progress[id] = safe);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('adhkar_count_${_dateKey}_$id', safe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !_progressLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: 'تعذر تحميل الأذكار: ${snapshot.error}',
              onRetry: () {
                setState(() {
                  _itemsFuture = DatabaseHelper().getAdhkarByCategory(
                    widget.categoryId,
                  );
                  _progressLoaded = false;
                });
                _loadProgress();
              },
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد أذكار في هذه الفئة.'));
          }

          final completed = items.where((item) {
            final id = item['id'].toString();
            final target = (item['repeat_count'] as num?)?.toInt() ?? 1;
            return (_progress[id] ?? 0) >= target;
          }).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.chartNoAxesColumnIncreasing,
                            color: Color(0xFFC6A76A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'إنجاز اليوم',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text('$completed / ${items.length}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: items.isEmpty ? 0 : completed / items.length,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final item in items)
                _DhikrCard(
                  item: item,
                  count: _progress[item['id'].toString()] ?? 0,
                  onCountChanged: (count, target) => _setCount(
                    item['id'].toString(),
                    count,
                    target,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.item,
    required this.count,
    required this.onCountChanged,
  });

  final Map<String, dynamic> item;
  final int count;
  final ValueChanged2 onCountChanged;

  @override
  Widget build(BuildContext context) {
    final text = item['text']?.toString() ?? '';
    final target = (item['repeat_count'] as num?)?.toInt() ?? 1;
    final safeCount = count.clamp(0, target).toInt();
    final completed = safeCount >= target;
    final source = item['book_name']?.toString() ?? 'غير محدد';
    final hadithNumber = item['hadith_number']?.toString() ?? '';
    final grade = item['grade']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x22C6A76A),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'العدد $target',
                    style: const TextStyle(
                      color: Color(0xFFC6A76A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (completed)
                  const Icon(Icons.check_circle, color: Color(0xFF42C6A5)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 23, height: 2.0),
            ),
            const SizedBox(height: 12),
            Text(
              'المصدر: $source'
              '${hadithNumber.isNotEmpty ? ' • رقم $hadithNumber' : ''}'
              '${grade.isNotEmpty ? ' • $grade' : ''}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: target <= 0 ? 0 : safeCount / target,
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'إعادة العد',
                  onPressed: safeCount == 0
                      ? null
                      : () => onCountChanged(0, target),
                  icon: const Icon(Icons.restart_alt),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: completed
                        ? null
                        : () => onCountChanged(safeCount + 1, target),
                    icon: Icon(
                      completed ? Icons.check : Icons.add,
                    ),
                    label: Text(
                      completed ? 'اكتمل الذكر' : 'تسجيل تكرار • $safeCount / $target',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef ValueChanged2 = void Function(int count, int target);

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
