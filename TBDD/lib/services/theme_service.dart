// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'theme_mode'; // light | dark | system
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    switch (raw) {
      case 'light':
        mode.value = ThemeMode.light;
        break;
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      default:
        mode.value = ThemeMode.system;
    }
  }

  Future<void> _save(ThemeMode m) async {
    final prefs = await SharedPreferences.getInstance();
    switch (m) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_key, 'system');
        break;
    }
  }

  /// Bật/tắt giữa Light và Dark (bỏ qua System)
  Future<void> toggle() async {
    mode.value = (mode.value == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    await _save(mode.value);
  }

  /// Đặt mode cụ thể nếu bạn muốn cho thêm menu chọn 3 chế độ
  Future<void> set(ThemeMode m) async {
    mode.value = m;
    await _save(m);
  }
}
