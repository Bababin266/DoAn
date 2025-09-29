import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId   = 'med_channel';
  static const String _channelName = 'Medicine Reminder';
  static const String _channelDesc = 'Thông báo nhắc giờ uống thuốc';

  Future<void> init({String timezoneName = 'Asia/Ho_Chi_Minh'}) async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    final initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initDarwin  = DarwinInitializationSettings();
    final settings    = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
      macOS: initDarwin,
    );
    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();    // Android 13+
      await android?.requestExactAlarmsPermission();      // Android 12+
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 800, 300, 1200]),
        ),
      );
    }
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduled = _nextInstanceOfTime(hour, minute);

    Future<void> call({AndroidScheduleMode? mode}) {
      return _plugin.zonedSchedule(
        id, title, body, scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList(<int>[0, 800, 300, 1200]),
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
        ),
        androidScheduleMode: mode, // null => inexact
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    try {
      await call(mode: AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (kDebugMode) print('[Noti] exact not permitted → fallback: $e');
      await call(); // inexact (có thể lệch vài phút nếu tắt "Alarms & reminders")
    }
  }

  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    final t = tz.TZDateTime.from(whenLocal, tz.local);
    Future<void> call({AndroidScheduleMode? mode}) {
      return _plugin.zonedSchedule(
        id, title, body, t,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    try {
      await call(mode: AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await call();
    }
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 500, 200, 800]),
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  Future<void> cancel(int id)   => _plugin.cancel(id);
  Future<void> cancelAll()      => _plugin.cancelAll();

  ({int hour, int minute}) parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }
}
