// lib/services/medicine_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';

class MedicineService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _meds =>
      _db.collection('medicines');

  Future<String> addMedicine(Medicine med) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'Chưa đăng nhập';

    final data = med.toMap()
      ..['ownerId'] = uid
      ..['createdAt'] = FieldValue.serverTimestamp();

    final doc = await _meds.add(data);
    return doc.id;
  }

  Stream<List<Medicine>> getMedicines() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream<List<Medicine>>.empty();

    return _meds
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map<Medicine>((d) => Medicine.fromMap(d.data(), id: d.id))
        .toList());
  }

  Future<void> updateMedicine(Medicine med) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'Chưa đăng nhập';
    if (med.id == null) throw 'Thiếu id';

    final data = med.toMap()..remove('ownerId');
    await _meds.doc(med.id!).update(data);
  }

  Future<void> deleteMedicine(String id) => _meds.doc(id).delete();

  Future<void> setTaken(String id, bool value) async {
    await _meds.doc(id).update({'taken': value});
  }

  // ================== NEW: per-day, per-ocurrence ==================

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
    // ví dụ: 20251007
  }

  /// Lấy stream doc để theo dõi thay đổi dailyTaken mọi lúc
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMedicineDoc(String id) {
    return _meds.doc(id).snapshots();
  }

  /// Đọc mảng taken hôm nay theo số lần (count = 1/2/3). Nếu chưa có -> trả về mảng false tương ứng.
  List<bool> getTodayArrayFromDoc(
      DocumentSnapshot<Map<String, dynamic>> snap,
      int count,
      ) {
    final data = snap.data() ?? {};
    final daily = (data['dailyTaken'] as Map<String, dynamic>?) ?? {};
    final key = _todayKey();
    final arrDynamic = daily[key];

    List<bool> arr;
    if (arrDynamic is List) {
      arr = arrDynamic.map((e) => e == true).toList();
    } else {
      arr = List<bool>.filled(count, false);
    }

    // đảm bảo đúng độ dài (nếu đổi tần suất trong ngày)
    if (arr.length != count) {
      if (arr.length > count) {
        arr = arr.take(count).toList();
      } else {
        arr = [...arr, ...List<bool>.filled(count - arr.length, false)];
      }
    }
    return arr;
  }

  /// Toggle một lần trong ngày (index 0/1/2). Tự set `taken=true` nếu tất cả true; ngược lại false.
  Future<void> toggleTodayIntake({
    required String medId,
    required int index,
    required int count,
    required bool value,
  }) async {
    final key = _todayKey();
    final docRef = _meds.doc(medId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = (snap.data() as Map<String, dynamic>? ?? {});
      final daily = (data['dailyTaken'] as Map<String, dynamic>? ?? {});
      List<dynamic> arr = (daily[key] as List?) ?? List<bool>.filled(count, false);

      // đảm bảo length
      if (arr.length != count) {
        if (arr.length > count) {
          arr = arr.take(count).toList();
        } else {
          arr = [...arr, ...List<bool>.filled(count - arr.length, false)];
        }
      }

      arr[index] = value;
      final allDone = arr.every((e) => e == true);

      // cập nhật nested field và field taken
      tx.update(docRef, {
        'dailyTaken.$key': arr,
        'taken': allDone, // hiển thị tích lớn nếu xong hết hôm nay
      });
    });
  }
}
