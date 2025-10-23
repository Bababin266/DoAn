import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Simple i18n service for app-wide translations.
/// - Đổi ngôn ngữ bằng [setLanguage] → rebuild toàn app.
/// - Tự load file JSON từ assets/i18n.
/// - Fallback sang en.json nếu thiếu key hoặc file.
class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const _prefsKey = 'app.langCode';
  static const _dir = 'assets/i18n';
  static const _listFile = '$_dir/_list.txt';

  final ValueNotifier<String> langCode = ValueNotifier('en');
  final ValueNotifier<bool> isVietnamese = ValueNotifier(false);
  final ValueNotifier<List<String>> supported = ValueNotifier([]);

  Map<String, dynamic> _bundle = {};
  Map<String, dynamic> _bundleEn = {};

  /// Khởi tạo: đọc danh sách ngôn ngữ + chọn locale mặc định (hoặc từ device)
  Future<void> init({Locale? deviceLocale}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    final rawList = await rootBundle.loadString(_listFile);
    final codes = rawList
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('#'))
        .toList();

    final available = <String>[];
    for (final c in codes) {
      try {
        await rootBundle.loadString('$_dir/$c.json');
        available.add(c);
      } catch (_) {}
    }
    if (available.isEmpty) available.add('en');
    supported.value = available;

    // Load fallback EN
    _bundleEn = await _loadJsonSafe('en');

    String initial = 'en';
    if (saved != null && available.contains(saved)) {
      initial = saved;
    } else if (deviceLocale != null) {
      final deviceTag = deviceLocale.toLanguageTag();
      final short = deviceLocale.languageCode;
      if (available.contains(deviceTag)) {
        initial = deviceTag;
      } else if (available.contains(short)) {
        initial = short;
      } else if (available.contains('vi')) {
        initial = 'vi';
      }
    }
    await setLanguage(initial, persist: true);
  }

  /// Đổi ngôn ngữ + notify toàn app
  Future<void> setLanguage(String code, {bool persist = true}) async {
    if (!supported.value.contains(code)) {
      code = supported.value.contains('en') ? 'en' : supported.value.first;
    }
    _bundle = await _loadJsonSafe(code);
    langCode.value = code;
    isVietnamese.value = (code == 'vi');

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    }
  }

  /// Trả về danh sách locale cho MaterialApp
  List<Locale> supportedLocales() {
    return supported.value
        .map((c) {
      if (c.contains('-')) {
        final parts = c.split('-');
        return Locale(parts[0], parts[1]);
      }
      return Locale(c);
    })
        .toList();
  }

  /// Dịch key → string (fallback sang en.json hoặc chính key)
  String tr(String key, {Map<String, String>? params, String? fallback}) {
    String? value = _stringForKey(key, _bundle) ??
        _stringForKey(key, _bundleEn) ??
        fallback ??
        key;
    if (params != null) {
      params.forEach((k, v) {
        value = value!.replaceAll('{$k}', v);
      });
    }
    return value!;
  }

  // ====== Helper ======
  Future<Map<String, dynamic>> _loadJsonSafe(String code) async {
    try {
      final s = await rootBundle.loadString('$_dir/$code.json');
      return json.decode(s);
    } catch (_) {
      return {};
    }
  }

  String? _stringForKey(String key, Map<String, dynamic> map) {
    dynamic cur = map;
    for (final part in key.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur is String ? cur : null;
  }

  /// Hiển thị tên ngôn ngữ
  /// Hiển thị tên ngôn ngữ theo mã
  String displayNameOf(String code) {
    const names = {
      'en': 'English',
      'vi': 'Tiếng Việt',
      'ja': '日本語',
      'ko': '한국어',
      'fr': 'Français',
      'es': 'Español',
      'de': 'Deutsch',
      'id': 'Bahasa Indonesia',
      'tr': 'Türkçe',
      'zh-Hans': '简体中文',
      'zh-Hant': '繁體中文',
      'ru': 'Русский',          // Russian
      'hi': 'हिन्दी',           // Hindi
      'th': 'ภาษาไทย',          // Thai
      'ar': 'العربية',           // Arabic
    };
    return names[code] ?? code;
  }

  /// Cờ emoji hiển thị trong LanguagePicker
  String flagOf(String code) {
    const flags = {
      'en': '🇺🇸',
      'vi': '🇻🇳',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'id': '🇮🇩',
      'tr': '🇹🇷',
      'zh-Hans': '🇨🇳',
      'zh-Hant': '🇹🇼',
      'ru': '🇷🇺',  // Russian
      'hi': '🇮🇳',  // Hindi
      'th': '🇹🇭',  // Thai
      'ar': '🇸🇦',  // Arabic (bạn có thể đổi sang 🇪🇬 hoặc 🇦🇪 nếu muốn)
    };
    return flags[code] ?? '🌐';
  }
}
