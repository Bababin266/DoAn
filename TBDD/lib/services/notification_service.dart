import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navKey;

  static const String _channelId   = 'med_channel';
  static const String _channelName = 'Medicine Reminder';
  static const String _channelDesc = 'Thông báo nhắc giờ uống thuốc';

  Future<void> init({
    GlobalKey<NavigatorState>? navigatorKey,
    String timezoneName = 'Asia/Ho_Chi_Minh',
  }) async {
    _navKey = navigatorKey;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    final initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initDarwin  = DarwinInitializationSettings();
    final settings = InitializationSettings(android: initAndroid, iOS: initDarwin, macOS: initDarwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.startsWith('take:')) {
          final medId = payload.substring(5);
          _navKey?.currentState?.pushNamed('/take', arguments: medId);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId, _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 300, 1200]),
        ),
      );
    }
  }

  // Lịch hằng ngày
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
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
          ),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    }

    try {
      await call(mode: AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await call();
    }
  }

  // Follow-up mỗi 2 phút
  Future<void> scheduleFollowUpsForOccurrence({
    required String medDocId,
    required int baseHour,
    required int baseMinute,
    int count = 10,
    int intervalMinutes = 2,
    required String title,
    required String body,
    String? payload,
  }) async {
    final first = _nextInstanceOfTime(baseHour, baseMinute);
    for (int i = 1; i <= count; i++) {
      final t = first.add(Duration(minutes: intervalMinutes * i));
      final idStr = '${medDocId}_${_fmtYmd(t)}_f$i';
      final id = idStr.hashCode;

      await _plugin.zonedSchedule(
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  Future<void> cancelTodayFollowUps(String medDocId) async {
    final now = tz.TZDateTime.now(tz.local);
    final ymd = _fmtYmd(now);
    for (int i = 1; i <= 60; i++) {
      final id = ('${medDocId}_${ymd}_f$i').hashCode;
      await _plugin.cancel(id);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  String _fmtYmd(tz.TZDateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}
