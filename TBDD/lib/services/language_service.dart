// lib/services/language_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const _prefsKey = 'lang_code';
  static const _assetListPath = 'assets/i18n/_list.txt';
  static const _assetDir = 'assets/i18n';

  /// Danh sách mã (vd: en, vi, ja, ko, fr, zh-Hans...)
  final ValueNotifier<List<String>> supported = ValueNotifier<List<String>>([]);

  /// Mã hiện tại (vd: 'vi')
  final ValueNotifier<String> langCode = ValueNotifier<String>('vi');

  /// Tương thích ngược: true nếu 'vi'
  final ValueNotifier<bool> isVietnamese = ValueNotifier<bool>(true);

  /// Bảng dịch: langCode -> {key: value}
  final Map<String, Map<String, String>> _bundles = {};

  Future<void> init({Locale? deviceLocale}) async {
    // 1) load danh sách ngôn ngữ
    final listRaw = await rootBundle.loadString(_assetListPath);
    final codes = listRaw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('#'))
        .toList();
    supported.value = codes;

    // 2) load tất cả file json
    for (final code in codes) {
      final path = '$_assetDir/$code.json';
      try {
        final s = await rootBundle.loadString(path);
        final map = Map<String, dynamic>.from(json.decode(s));
        _bundles[code] = map.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        _bundles[code] = {};
      }
    }

    // 3) chọn ngôn ngữ ban đầu: đã lưu → theo máy → 'vi'
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    String start = saved ??
        (deviceLocale?.toLanguageTag() ?? deviceLocale?.languageCode) ??
        'vi';

    // Nếu mã đầy đủ không có, thử rút gọn (e.g. 'pt-BR' -> 'pt')
    if (!_bundles.containsKey(start) && start.contains('-')) {
      final short = start.split('-').first;
      if (_bundles.containsKey(short)) start = short;
    }
    if (!_bundles.containsKey(start)) start = 'vi';

    await setLanguage(start);
  }

  Future<void> setLanguage(String code) async {
    String picked = code;
    if (!_bundles.containsKey(picked)) {
      // thử rút gọn
      if (picked.contains('-')) {
        final short = picked.split('-').first;
        if (_bundles.containsKey(short)) picked = short;
      }
    }
    if (!_bundles.containsKey(picked)) picked = 'vi';

    langCode.value = picked;
    isVietnamese.value = (picked == 'vi');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, picked);
  }

  Future<void> cycleLanguage() async {
    final list = supported.value;
    final idx = list.indexOf(langCode.value);
    final next = list[(idx + 1) % list.length];
    await setLanguage(next);
  }

  /// Dịch theo key: ưu tiên lang hiện tại -> rút gọn -> 'en' -> 'vi' -> key.
  String tr(String key, {Map<String, String>? params}) {
    String? v = _resolve(key);
    v ??= key;
    if (params != null && params.isNotEmpty) {
      params.forEach((k, p) {
        v = v!.replaceAll('{$k}', p);
      });
    }
    return v!;
  }

  /// Giữ API cũ: t(vi, en). Nếu lang khác vi/en -> ưu tiên en.
  String t(String vi, String en) {
    final code = langCode.value;
    if (code == 'vi') return vi;
    if (code == 'en') return en;
    return en;
  }

  /// Dịch theo map (đa ngôn ngữ nhanh)
  String tMap(Map<String, String> byCode, {String? fallback}) {
    final code = langCode.value;
    if (byCode.containsKey(code)) return byCode[code]!;
    // nếu code dài (pt-BR), thử rút gọn
    if (code.contains('-')) {
      final short = code.split('-').first;
      if (byCode.containsKey(short)) return byCode[short]!;
    }
    if (byCode.containsKey('en')) return byCode['en']!;
    if (byCode.containsKey('vi')) return byCode['vi']!;
    return fallback ?? byCode.values.first;
  }

  /// supported -> List<Locale> cho MaterialApp
  List<Locale> supportedLocales() {
    return supported.value.map((c) {
      if (c.contains('-')) {
        final parts = c.split('-');
        return Locale.fromSubtags(languageCode: parts.first, scriptCode: parts.length == 3 ? parts[1] : null, countryCode: parts.last);
      }
      return Locale(c);
    }).toList();
  }

  String? _resolve(String key) {
    final code = langCode.value;
    String? v = _bundles[code]?[key];
    if (v != null) return v;

    // thử rút gọn
    if (code.contains('-')) {
      final short = code.split('-').first;
      v = _bundles[short]?[key];
      if (v != null) return v;
    }

    // fallback en -> vi
    v = _bundles['en']?[key];
    v ??= _bundles['vi']?[key];
    return v;
  }

  String displayNameOf(String code) {
    switch (code) {
      case 'vi': return 'Tiếng Việt';
      case 'en': return 'English';
      case 'ja': return '日本語';
      case 'ko': return '한국어';
      case 'fr': return 'Français';
      case 'es': return 'Español';
      case 'de': return 'Deutsch';
      case 'zh-Hans': return '简体中文';
      case 'zh-Hant': return '繁體中文';
      case 'ru': return 'Русский';
      case 'ar': return 'العربية';
      case 'hi': return 'हिन्दी';
      case 'th': return 'ไทย';
      case 'id': return 'Bahasa Indonesia';
      case 'tr': return 'Türkçe';
      default: return code;
    }
  }

  String flagOf(String code) {
    switch (code) {
      case 'vi': return '🇻🇳';
      case 'en': return '🇺🇸';
      case 'ja': return '🇯🇵';
      case 'ko': return '🇰🇷';
      case 'fr': return '🇫🇷';
      case 'es': return '🇪🇸';
      case 'de': return '🇩🇪';
      case 'zh-Hans': return '🇨🇳';
      case 'zh-Hant': return '🇹🇼';
      case 'ru': return '🇷🇺';
      case 'ar': return '🇦🇪';
      case 'hi': return '🇮🇳';
      case 'th': return '🇹🇭';
      case 'id': return '🇮🇩';
      case 'tr': return '🇹🇷';
      default: return '🌐';
    }
  }
}
