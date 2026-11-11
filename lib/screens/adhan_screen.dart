import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AdhanScreen extends StatefulWidget {
  const AdhanScreen({super.key});

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen>
    with WidgetsBindingObserver {
  static const _notificationPreferenceKey = 'prayer_notifications_enabled';
  static const _enabledPreferenceKey = 'prayer_enabled_';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Map<String, dynamic>? _city;
  Map<String, bool> _enabled = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  bool _notificationsEnabled = false;
  bool _loading = true;
  bool _working = false;
  String? _error;

  static const _prayers = <String, String>{
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _notificationsEnabled) {
      _scheduleUpcomingPrayers();
    }
  }

  Future<void> _load() async {
    try {
      tz.initializeTimeZones();
      // Convert device-local prayer times to UTC without changing the instant.
      tz.setLocalLocation(tz.UTC);

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(settings);

      final raw = await rootBundle.loadString('assets/data/cities.json');
      final cities = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (cities.isEmpty) throw const FormatException('قائمة المدن فارغة');

      final preferences = await SharedPreferences.getInstance();
      final cityId = preferences.getString('city_id') ?? 'baghdad';
      final city = cities.firstWhere(
        (item) => item['id'] == cityId,
        orElse: () => cities.first,
      );

      final enabled = <String, bool>{};
      for (final prayerId in _prayers.keys) {
        enabled[prayerId] =
            preferences.getBool('$_enabledPreferenceKey$prayerId') ?? true;
      }

      if (!mounted) return;
      setState(() {
        _city = city;
        _enabled = enabled;
        _notificationsEnabled =
            preferences.getBool(_notificationPreferenceKey) ?? false;
        _loading = false;
      });

      if (_notificationsEnabled) {
        await _scheduleUpcomingPrayers();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تهيئة تنبيهات الصلاة: $error';
        _loading = false;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final notificationGranted =
        await android.requestNotificationsPermission() ?? false;
    if (!notificationGranted) return false;

    return await android.requestExactAlarmsPermission() ?? false;
  }

  Future<void> _enableNotifications() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final granted = await _requestPermissions();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اسمح بالإشعارات والمنبهات الدقيقة من إعدادات الجهاز لتفعيل التنبيهات',
            ),
          ),
        );
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_notificationPreferenceKey, true);
      if (!mounted) return;
      setState(() => _notificationsEnabled = true);
      await _scheduleUpcomingPrayers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تفعيل التنبيهات: $error')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _setPrayerEnabled(String prayerId, bool value) async {
    setState(() => _enabled[prayerId] = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_enabledPreferenceKey$prayerId', value);
    if (_notificationsEnabled) {
      await _scheduleUpcomingPrayers();
    }
  }

  Future<void> _scheduleUpcomingPrayers() async {
    final city = _city;
    if (city == null || !_notificationsEnabled) return;

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final canSchedule =
        await android.canScheduleExactNotifications() ?? false;
    if (!canSchedule) {
      if (mounted) setState(() => _notificationsEnabled = false);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_notificationPreferenceKey, false);
      return;
    }

    final coordinates = Coordinates(
      (city['lat'] as num).toDouble(),
      (city['lng'] as num).toDouble(),
    );
    final methodIndex = (city['method'] as num)
        .toInt()
        .clamp(0, CalculationMethod.values.length - 1);
    final parameters = CalculationMethod.values[methodIndex].getParameters();
    final now = DateTime.now();

    await _notificationsPlugin.cancelAll();
    const androidDetails = AndroidNotificationDetails(
      'prayer_reminders',
      'تنبيهات الصلاة',
      channelDescription: 'تنبيه عند دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      final times = PrayerTimes(
        coordinates,
        DateComponents.from(date),
        parameters,
      );
      final prayerTimes = <String, DateTime>{
        'fajr': times.fajr,
        'dhuhr': times.dhuhr,
        'asr': times.asr,
        'maghrib': times.maghrib,
        'isha': times.isha,
      };

      var prayerIndex = 0;
      for (final entry in prayerTimes.entries) {
        prayerIndex++;
        if (_enabled[entry.key] != true || !entry.value.isAfter(now)) {
          continue;
        }

        final scheduledAt = tz.TZDateTime.from(entry.value, tz.UTC);
        await _notificationsPlugin.zonedSchedule(
          dayOffset * 10 + prayerIndex,
          'حان الآن وقت صلاة ${_prayers[entry.key]}',
          'حافظ على صلاتك',
          scheduledAt,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنبيهات الصلاة'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (_city != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text('${_city!['name']}'),
                subtitle: Text('${_city!['country']}'),
                trailing: const Icon(Icons.access_time),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'اختر الصلوات التي تريد التنبيه عند دخول وقتها:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final entry in _prayers.entries)
            SwitchListTile(
              title: Text(entry.value),
              value: _enabled[entry.key] ?? true,
              onChanged: (value) => _setPrayerEnabled(entry.key, value),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _working ? null : _enableNotifications,
            icon: _working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_active_outlined),
            label: Text(
              _notificationsEnabled
                  ? 'تحديث مواعيد التنبيهات'
                  : 'تفعيل تنبيهات الصلاة',
            ),
          ),
          if (_notificationsEnabled)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'تُحدّث التنبيهات للأيام السبعة القادمة عند فتح التطبيق. '
                'يستخدم التنبيه صوت الإشعار الافتراضي للجهاز.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
