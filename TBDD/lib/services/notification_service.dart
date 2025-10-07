import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../services/medicine_service.dart';
import 'dose_state_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navKey;

  static const String _channelId   = 'med_channel';
  static const String _channelName = 'Medicine Reminder';
  static const String _channelDesc = 'Thông báo nhắc giờ uống thuốc';

  static const String _actMarkTaken = 'mark_taken';

  Future<void> init({
    GlobalKey<NavigatorState>? navigatorKey,
    String timezoneName = 'Asia/Ho_Chi_Minh',
  }) async {
    _navKey = navigatorKey;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin  = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
      macOS: initDarwin,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) async => _handleTapOrAction(resp),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

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

  AndroidNotificationDetails _androidDetailsWithActions() {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 800, 300, 1200]),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _actMarkTaken,
          'Đã uống',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
  }

  // Test nhanh: hiện thông báo ngay
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kDebugMode) {
      print('[Noti] showNow id=$id payload=$payload');
    }
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _androidDetailsWithActions()),
      payload: payload,
    );
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload, // "take:<docId>:<idx>"
  }) async {
    final scheduled = _nextInstanceOfTime(hour, minute);

    Future<void> call({AndroidScheduleMode? mode}) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(android: _androidDetailsWithActions()),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    }

    try {
      await call(mode: AndroidScheduleMode.exactAllowWhileIdle);
      if (kDebugMode) {
        print('[Noti] scheduled (exact) id=$id at=$scheduled payload=$payload');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[Noti] exact not permitted → fallback inexact: $e');
      }
      await call();
      if (kDebugMode) {
        print('[Noti] scheduled (inexact) id=$id at=$scheduled payload=$payload');
      }
    }
  }

  Future<void> scheduleFollowUpsForOccurrence({
    required String medDocId,
    required int baseHour,
    required int baseMinute,
    int count = 10,
    int intervalMinutes = 2,
    required String title,
    required String body,
    String? payload, // "take:<docId>:<idx>"
  }) async {
    final first = _nextInstanceOfTime(baseHour, baseMinute);
    for (int i = 1; i <= count; i++) {
      final t = first.add(Duration(minutes: intervalMinutes * i));
      final idStr = '${medDocId}_${_fmtYmd(t)}_f$i';
      final id = idStr.hashCode;

      await _plugin.zonedSchedule(
        id, title, body, t,
        NotificationDetails(android: _androidDetailsWithActions()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      if (kDebugMode) {
        print('[Noti] follow-up scheduled id=$id at=$t payload=$payload');
      }
    }
  }

  Future<void> cancelTodayFollowUps(String medDocId) async {
    final now = tz.TZDateTime.now(tz.local);
    final ymd = _fmtYmd(now);
    for (int i = 1; i <= 60; i++) {
      final id = ('${medDocId}_${ymd}_f$i').hashCode;
      await _plugin.cancel(id);
    }
    if (kDebugMode) {
      print('[Noti] cancel today follow-ups for $medDocId');
    }
  }

  // ✅ BỔ SUNG: huỷ 1 id & huỷ tất cả
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    if (kDebugMode) print('[Noti] cancel id=$id');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    if (kDebugMode) print('[Noti] cancelAll');
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

  Future<void> _handleTapOrAction(NotificationResponse resp) async {
    final payload = resp.payload ?? '';
    final action = resp.actionId;

    if (!payload.startsWith('take:')) return;

    final parts = payload.split(':'); // [take, medId, idx]
    final medId = parts.length >= 2 ? parts[1] : '';
    final doseIdx = (parts.length >= 3) ? int.tryParse(parts[2]!) ?? 0 : 0;

    if (action == _actMarkTaken) {
      bool allDone = false;
      try {
        final cnt = await DoseStateService.instance.getSavedCount(medId);

        // cập nhật firestore để Home tick ngày
        await MedicineService().toggleTodayIntake(
          medId: medId,
          index: doseIdx,
          count: cnt,
          value: true,
        );

        // mirror local và kiểm tra hoàn tất cả ngày
        allDone = await DoseStateService.instance.markTaken(
          medId,
          doseIdx,
          countHint: cnt,
        );
      } catch (e) {
        if (kDebugMode) print('Dose mark error: $e');
      }

      if (allDone) {
        try { await MedicineService().setTaken(medId, true); } catch (_) {}
        try { await cancelTodayFollowUps(medId); } catch (_) {}
      }
      return;
    }

    // Người dùng chạm vào thông báo (không bấm action) -> mở màn hình take nếu cần
    _navKey?.currentState?.pushNamed('/take', arguments: medId);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Không làm việc nặng ở đây
}
