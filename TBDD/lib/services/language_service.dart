import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const _key = 'lang'; // 'vi' | 'en'
  // true = VI, false = EN
  final ValueNotifier<bool> isVietnamese = ValueNotifier<bool>(true);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    isVietnamese.value = (raw != 'en'); // mặc định VI
  }

  Future<void> toggle() async {
    isVietnamese.value = !isVietnamese.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isVietnamese.value ? 'vi' : 'en');
  }

  String t(String vi, String en) => isVietnamese.value ? vi : en;
}
