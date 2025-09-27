// lib/services/notification_service.dart
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

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const _channelId   = 'med_channel';
  static const _channelName = 'Medicine Reminder';
  static const _channelDesc = 'Thông báo nhắc giờ uống thuốc';

  Future<void> init() async {
    // Timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Init per-platform
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin  = DarwinInitializationSettings();
    const settings    = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
      macOS: initDarwin,
    );
    await _plugin.initialize(settings);

    // Android: xin quyền + tạo channel
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.requestNotificationsPermission(); // Android 13+
      await android?.requestExactAlarmsPermission();   // Android 12+

      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(const [0, 800, 300, 1200]),
        ),
      );
    }
  }

  /// ĐẶT LỊCH HẰNG NGÀY vào HH:mm.
  /// Thử exactAllowWhileIdle; nếu hệ thống chặn → fallback inexact (không ném lỗi).
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduled = _nextInstanceOfTime(hour, minute);

    Future<void> _call({AndroidScheduleMode? mode}) {
      return _plugin.zonedSchedule(
        id, title, body, scheduled,
        NotificationDetails(
          android: Platform.isAndroid
              ? AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 300, 1200]),
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          )
              : null,
        ),
        androidScheduleMode: mode, // null => inexact
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidAllowWhileIdle: true,
      );
    }

    try {
      await _call(mode: AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[Noti] exact not permitted → fallback inexact. $e');
      }
      await _call(); // retry inexact
    } catch (_) {
      await _call(); // mọi lỗi khác → thử inexact
    }

    if (kDebugMode) {
      print('Scheduled daily at $hour:$minute (id=$id) -> $scheduled');
    }
  }

  /// ĐẶT 1 LẦN (khi cần test nhanh với thời điểm cụ thể).
  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    final t = tz.TZDateTime.from(whenLocal, tz.local);

    Future<void> _call({AndroidScheduleMode? mode}) {
      return _plugin.zonedSchedule(
        id, title, body, t,
        NotificationDetails(
          android: Platform.isAndroid
              ? AndroidNotificationDetails(
            _channelId, _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          )
              : null,
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
    }

    try {
      await _call(mode: AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await _call(); // fallback inexact
    } catch (_) {
      await _call();
    }
  }

  /// HIỆN NGAY (để test)
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id, title, body,
      NotificationDetails(
        android: Platform.isAndroid
            ? AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 800]),
          category: AndroidNotificationCategory.reminder,
        )
            : null,
      ),
    );
  }

  Future<void> cancel(int id)    => _plugin.cancel(id);
  Future<void> cancelAll()       => _plugin.cancelAll();

  /// Helper: parse "HH:mm" → (hour, minute)
  ({int hour, int minute}) parseHHmm(String hhmm,
      {int defHour = 8, int defMinute = 0}) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? defHour;
    final m = int.tryParse(parts.elementAt(1)) ?? defMinute;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  /// Tính lần chạy tiếp theo trong ngày (nếu giờ đã qua thì cộng 1 ngày)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
