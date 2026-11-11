import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AdhanScreen extends StatefulWidget {
  const AdhanScreen({super.key});

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _fajrEnabled = true;
  bool _dhuhrEnabled = true;
  bool _asrEnabled = true;
  bool _maghribEnabled = true;
  bool _ishaEnabled = true;
  String _selectedAdhan = 'أذان الحرم المكي';

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _scheduleAdhan(
      String prayerName, int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'adhan_channel',
      'أوقات الأذان',
      channelDescription: 'تنبيهات صوتية لأوقات الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan_makkah'),
    );

    await _notificationsPlugin.zonedSchedule(
      prayerName.hashCode,
      'حان وقت صلاة $prayerName',
      'الله أكبر، الله أكبر...',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم جدولة أذان $prayerName في $hour:$minute'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذان والتنبيهات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('صوت الأذان'),
              subtitle: Text(_selectedAdhan),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () {
                setState(() {
                  _selectedAdhan = _selectedAdhan == 'أذان الحرم المكي'
                      ? 'أذان الحرم المدني'
                      : 'أذان الحرم المكي';
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'تفعيل الأذان لكل صلاة:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('الفجر'),
            value: _fajrEnabled,
            onChanged: (val) => setState(() => _fajrEnabled = val),
          ),
          SwitchListTile(
            title: const Text('الظهر'),
            value: _dhuhrEnabled,
            onChanged: (val) => setState(() => _dhuhrEnabled = val),
          ),
          SwitchListTile(
            title: const Text('العصر'),
            value: _asrEnabled,
            onChanged: (val) => setState(() => _asrEnabled = val),
          ),
          SwitchListTile(
            title: const Text('المغرب'),
            value: _maghribEnabled,
            onChanged: (val) => setState(() => _maghribEnabled = val),
          ),
          SwitchListTile(
            title: const Text('العشاء'),
            value: _ishaEnabled,
            onChanged: (val) => setState(() => _ishaEnabled = val),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _scheduleAdhan('الفجر', 5, 0),
            child: const Text('اختبار جدولة أذان الفجر (5:00 ص)'),
          ),
        ],
      ),
    );
  }
}
