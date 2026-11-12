import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const _soundPreferenceKey = 'prayer_sound_';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _city;
  Map<String, bool> _enabled = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  Map<String, String> _sounds = {
    'fajr': 'adhan_muhammad_ramadan_saad',
    'dhuhr': 'adhan_muhammad_ramadan_saad',
    'asr': 'adhan_muhammad_ramadan_saad',
    'maghrib': 'adhan_muhammad_ramadan_saad',
    'isha': 'adhan_muhammad_ramadan_saad',
  };
  bool _notificationsEnabled = false;
  bool _loading = true;
  bool _working = false;
  bool _scheduling = false;
  String? _error;
  String? _previewing;

  static const _prayers = <String, String>{
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  static const _soundNames = <String, String>{
    'adhan_muhammad_ramadan_saad': 'محمد رمضان سعد — الحرم المكي',
    'adhan_ali_ibn_ahmad_mala': 'علي بن أحمد ملا — الحرم المكي',
    'adhan_muhammad_khaleel_raml': 'محمد خليل رمل — الحرم المكي',
    'adhan_nayf_fedah': 'نايف فداح — الحرم المكي',
    'adhan_faruq_abdul_rahman_hadrawe': 'فاروق عبدالرحمن حضراوي — الحرم المكي',
    'adhan_assem_bukhrare': 'عاصم بخراري — الحرم المكي',
    'adhan_nurdin_hamza_al_maghriby': 'نور الدين حمزة المغربي — المسجد الأقصى',
    'adhan_najee_qazaz': 'ناجي قزاز — المسجد الأقصى',
    'adhan_mishary_rashid_alafasy': 'مشاري راشد العفاسي — الكويت',
    'adhan_abdulbasit_abdusamad': 'عبد الباسط عبد الصمد — مصر',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = null);
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
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
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));

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
      final sounds = <String, String>{};
      for (final prayerId in _prayers.keys) {
        enabled[prayerId] =
            preferences.getBool('$_enabledPreferenceKey$prayerId') ?? true;
        final savedSound =
            preferences.getString('$_soundPreferenceKey$prayerId');
        sounds[prayerId] = _soundNames.containsKey(savedSound)
            ? savedSound!
            : _soundNames.keys.first;
      }

      if (!mounted) return;
      setState(() {
        _city = city;
        _enabled = enabled;
        _sounds = sounds;
        _notificationsEnabled =
            preferences.getBool(_notificationPreferenceKey) ?? false;
        _loading = false;
      });

      if (_notificationsEnabled) await _scheduleUpcomingPrayers();
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
    // Exact alarms are optional: continue with inexact reminders when denied.
    await android.requestExactAlarmsPermission();
    return true;
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
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final exactAlarmsAvailable =
          await android?.canScheduleExactNotifications() ?? false;
      if (!exactAlarmsAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'التنبيهات مفعّلة، لكن قد تصل متأخرة قليلاً لأن المنبهات الدقيقة غير مسموحة في الجهاز.',
            ),
          ),
        );
      }
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
    if (_notificationsEnabled) await _scheduleUpcomingPrayers();
  }

  Future<void> _setPrayerSound(String prayerId, String sound) async {
    if (!_soundNames.containsKey(sound)) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_soundPreferenceKey$prayerId', sound);
    if (!mounted) return;
    setState(() => _sounds[prayerId] = sound);
    if (_notificationsEnabled) await _scheduleUpcomingPrayers();
  }

  Future<void> _previewSound(String prayerId) async {
    final sound = _sounds[prayerId]!;
    try {
      if (_previewing == prayerId) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _previewing = null);
        return;
      }
      await _audioPlayer.stop();
      if (mounted) setState(() => _previewing = prayerId);
      await _audioPlayer.play(AssetSource('adhan/$sound.mp3'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _previewing = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل معاينة الأذان: $error')),
      );
    }
  }

  Future<void> _scheduleUpcomingPrayers() async {
    if (_scheduling) return;
    final city = _city;
    if (city == null || !_notificationsEnabled) return;
    _scheduling = true;
    try {

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final canScheduleExact =
        await android.canScheduleExactNotifications() ?? false;

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

        final sound = _sounds[entry.key]!;
        final channelId = 'prayer_${entry.key}_${sound}_v3';
        final androidDetails = AndroidNotificationDetails(
          channelId,
          'أذان ${_prayers[entry.key]}',
          channelDescription: 'صوت الأذان عند دخول وقت الصلاة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        final details = NotificationDetails(android: androidDetails);
        final scheduledAt = tz.TZDateTime.from(entry.value, tz.local);

        await _notificationsPlugin.zonedSchedule(
          dayOffset * 10 + prayerIndex,
          'حان الآن وقت صلاة ${_prayers[entry.key]}',
          'حافظ على صلاتك',
          scheduledAt,
          details,
          androidScheduleMode: canScheduleExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
    } finally {
      _scheduling = false;
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
        title: const Text('إعدادات الأذان'),
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
            'اختر صوت الأذان لكل صلاة، ويمكنك الاستماع إلى معاينة قبل اعتماده:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final entry in _prayers.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: _enabled[entry.key] ?? true,
                      onChanged: (value) =>
                          _setPrayerEnabled(entry.key, value),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sounds[entry.key],
                            decoration: const InputDecoration(
                              labelText: 'صوت الأذان',
                              isDense: true,
                            ),
                            items: _soundNames.entries
                                .map(
                                  (sound) => DropdownMenuItem(
                                    value: sound.key,
                                    child: Text(sound.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _setPrayerSound(entry.key, value);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'معاينة الصوت',
                          onPressed: () => _previewSound(entry.key),
                          icon: Icon(
                            _previewing == entry.key
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
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
                  ? 'تحديث مواعيد الأذان'
                  : 'تفعيل الأذان والتنبيهات',
            ),
          ),
          if (_notificationsEnabled)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'تم تفعيل تنبيهات الصلوات للأيام السبعة القادمة.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
