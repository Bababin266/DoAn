import 'package:shared_preferences/shared_preferences.dart';

class DoseStateService {
  DoseStateService._();
  static final DoseStateService instance = DoseStateService._();

  String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  String _key(String medId) => 'dose_${medId}_${_today()}';
  String _countKey(String medId) => 'dosecnt_$medId';
  String _timesKey(String medId) => 'dosetimes_$medId'; // nếu muốn lưu times hiển thị

  Future<void> saveCount(String medId, int count) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_countKey(medId), count.clamp(1, 3));
  }

  Future<int> getSavedCount(String medId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_countKey(medId)) ?? 1;
  }

  // (tuỳ chọn) để Home dùng nếu bạn muốn lưu time2/time3 local
  Future<void> saveTimes(String medId, List<String> hhmmList) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_timesKey(medId), hhmmList);
  }

  Future<List<String>> getSavedTimes(String medId) async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_timesKey(medId)) ?? const [];
  }

  Future<List<bool>> getTodayState(String medId, int count) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key(medId)) ?? '';
    final need = count.clamp(1, 3);
    final out = List<bool>.filled(need, false);
    for (int i = 0; i < need && i < s.length; i++) {
      out[i] = s[i] == '1';
    }
    return out;
  }

  Future<bool> toggle(String medId, int index, int count) async {
    final p = await SharedPreferences.getInstance();
    final need = count.clamp(1, 3);
    var s = p.getString(_key(medId)) ?? ''.padRight(need, '0');
    if (s.length < need) s = s.padRight(need, '0');
    final chars = s.split('');
    chars[index] = (chars[index] == '1') ? '0' : '1';
    final newStr = chars.join();
    await p.setString(_key(medId), newStr);
    return !newStr.contains('0');
  }

  Future<bool> markTaken(String medId, int index, {int? countHint}) async {
    final p = await SharedPreferences.getInstance();
    final count = countHint ?? await getSavedCount(medId);
    final need = count.clamp(1, 3);
    var s = p.getString(_key(medId)) ?? ''.padRight(need, '0');
    if (s.length < need) s = s.padRight(need, '0');
    final chars = s.split('');
    chars[index] = '1';
    final newStr = chars.join();
    await p.setString(_key(medId), newStr);
    return !newStr.contains('0');
  }

  Future<void> resetToday(String medId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(medId));
  }
}
