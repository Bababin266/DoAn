// lib/services/notification_service.dart
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'dose_state_service.dart';

// --- CÁC HÀM XỬ LÝ BACKGROUND (ĐẶT BÊN NGOÀI CLASS) ---

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    print("--- Background Action Received ---");
    print("Action ID: ${response.actionId}");
    print("Payload: ${response.payload}");
  }

  final payload = response.payload ?? '';
  // Chỉ xử lý hành động 'mark_taken'
  if (response.actionId == 'mark_taken' && payload.startsWith('take:')) {
    final parts = payload.split(':');
    if (parts.length >= 3) {
      final medId = parts[1];
      final doseIdx = int.tryParse(parts[2]) ?? 0;
      // Khi đã uống, hủy các thông báo nhắc lại và cập nhật DB
      await NotificationService.instance.cancelRemindersForDose(medId, doseIdx);
      await _handleMarkTakenInBackground(medId, doseIdx);
    }
  }
}

Future<void> _handleMarkTakenInBackground(String medId, int doseIdx) async {
  try {
    final medicineService = MedicineService();
    await medicineService.markDoseAsTakenById(medId, doseIdx);
    if (kDebugMode) {
      print("✅ Successfully marked dose in background for medId: $medId");
    }
  } catch (e) {
    if (kDebugMode) {
      print("❌ Error marking dose in background: $e");
    }
  }
}


class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navKey;

  static const String _channelId = 'med_channel';
  static const String _channelName = 'Medicine Reminder';
  static const String _channelDesc = 'Thông báo nhắc giờ uống thuốc';
  static const String _actMarkTaken = 'mark_taken';

  // --- KHỞI TẠO VÀ XỬ LÝ TAP ---

  Future<void> init({
    GlobalKey<NavigatorState>? navigatorKey,
    String timezoneName = 'Asia/Ho_Chi_Minh',
  }) async {
    _navKey = navigatorKey;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
      macOS: initDarwin,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Xử lý khi app bị đóng và mở lại từ 1 thông báo
    _plugin.getNotificationAppLaunchDetails().then((details) {
      if (details?.didNotificationLaunchApp ?? false) {
        handleTapFromTerminatedState(details!.notificationResponse);
      }
    });

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
        await android.createNotificationChannel(
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
  }

  void handleTapFromTerminatedState(NotificationResponse? response) {
    if (response == null) return;
    // Chỉ xử lý khi người dùng nhấn vào thân thông báo để mở app
    if (response.actionId == null) {
      _onNotificationTap(response);
    }
  }

  void _onNotificationTap(NotificationResponse resp) async {
    final payload = resp.payload ?? '';
    if (!payload.startsWith('take:')) return;

    final parts = payload.split(':');
    if (parts.length < 3) return;
    final medId = parts[1];
    final doseIdx = int.tryParse(parts[2]) ?? 0;

    // Khi người dùng tương tác (bấm nút hoặc mở app), hủy các lời nhắc
    await cancelRemindersForDose(medId, doseIdx);

    // Xử lý khi nhấn nút "Đã uống" (khi app đang chạy)
    if (resp.actionId == _actMarkTaken) {
      await _handleMarkTakenInBackground(medId, doseIdx);
      return;
    }

    // Xử lý khi nhấn vào thân thông báo -> mở màn hình
    if (resp.actionId == null) {
      if (_navKey?.currentState != null) {
        _navKey!.currentState!.popUntil((route) => route.isFirst);
        _navKey!.currentState!.pushNamed('/take', arguments: medId);
      }
    }
  }

  // --- LÊN LỊCH VÀ HỦY THÔNG BÁO ---

  Future<void> rescheduleNotificationsForMedicine(Medicine medicine) async {
    if (medicine.id == null) return;
    final times = await DoseStateService.instance.getSavedTimes(medicine.id!);

    await cancelAllNotificationsForMedicine(medicine.id!);
    if (times.isEmpty) return;

    for (int i = 0; i < times.length; i++) {
      final timeParts = times[i].split(':');
      if (timeParts.length != 2) continue;

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      if (hour != null && minute != null) {
        // Lên lịch cho thông báo chính VÀ các thông báo nhắc lại
        await _scheduleDoseWithReminders(
          medicine: medicine,
          doseIndex: i,
          hour: hour,
          minute: minute,
        );
      }
    }
  }

  /// ✅ HÀM QUAN TRỌNG: Lên lịch cho 1 liều và 3 lần nhắc lại
  Future<void> _scheduleDoseWithReminders({
    required Medicine medicine,
    required int doseIndex,
    required int hour,
    required int minute,
  }) async {
    final basePayload = 'take:${medicine.id}:$doseIndex';
    final initialTime = _nextInstanceOfTime(hour, minute);

    // 1. Lên lịch thông báo chính
    await _zonedSchedule(
      id: _generateNotificationId(medicine.id!, doseIndex, 0), // Lần 0 là thông báo gốc
      title: '💊 Giờ uống thuốc',
      body: 'Đã đến giờ uống ${medicine.name} (${medicine.dosage})',
      scheduledTime: initialTime,
      payload: basePayload,
    );

    // 2. Lên lịch cho 3 thông báo nhắc lại
    for (int i = 1; i <= 3; i++) {
      await _zonedSchedule(
        id: _generateNotificationId(medicine.id!, doseIndex, i), // Lần 1, 2, 3 là nhắc lại
        title: '⏰ Nhắc lại: Giờ uống thuốc',
        body: 'Bạn chưa uống ${medicine.name}. Hãy uống ngay nhé!',
        scheduledTime: initialTime.add(Duration(minutes: i * 2)), // +2, +4, +6 phút
        payload: basePayload, // Payload giống nhau để biết chúng cùng 1 liều
      );
    }
  }

  /// Hủy tất cả thông báo (chính + nhắc lại) của một liều cụ thể
  Future<void> cancelRemindersForDose(String medId, int doseIndex) async {
    for (int i = 0; i <= 3; i++) { // Hủy thông báo gốc (0) và 3 lần nhắc lại (1,2,3)
      final notifId = _generateNotificationId(medId, doseIndex, i);
      await cancel(notifId);
    }
  }

  /// Hủy tất cả thông báo của một loại thuốc (khi xóa/sửa thuốc)
  Future<void> cancelAllNotificationsForMedicine(String medId) async {
    final pendingNotifications = await _plugin.pendingNotificationRequests();
    for (var notif in pendingNotifications) {
      if (notif.payload?.contains(':$medId:') ?? false) {
        await cancel(notif.id);
      }
    }
  }

  /// Tạo ID duy nhất cho mỗi thông báo (kể cả nhắc lại)
  int _generateNotificationId(String medId, int doseIndex, int reminderCount) {
    return '${medId}_${doseIndex}_$reminderCount'.hashCode;
  }

  // --- CÁC HÀM TIỆN ÍCH (HELPER) ---

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id, title, body, scheduledTime,
        NotificationDetails(android: _androidDetailsWithActions()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) print("Failed to schedule exact alarm: $e");
    }
  }

  Future<void> cancel(int id) async => await _plugin.cancel(id);

  tz.TZDateTime _nextInstanceOfTime(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  AndroidNotificationDetails _androidDetailsWithActions() {
    return AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 800, 300, 1200]),
      // ✅ Thêm lại actions để nút "Đã uống" hiển thị
      /*actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _actMarkTaken,
          'Đã uống',
          showsUserInterface: false,
          cancelNotification: true, // Nhấn là tự hủy thông báo đó
        ),
      ],*/
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
  }

  Future<void> cancelTodayFollowUps(String id) async {}
}
