// lib/services/medicine_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/compliance_data.dart';
import '../models/medicine.dart';

class MedicineService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ✅ TRUY VẤN TRỰC TIẾP VÀO COLLECTION 'medicines' Ở CẤP CAO NHẤT
  CollectionReference<Map<String, dynamic>> get _medsCollection =>
      _db.collection('medicines');

  Future<String> addMedicine(Medicine med) async {
    final uid = _uid;
    if (uid == null) throw 'Chưa đăng nhập';

    // ✅ THÊM LẠI ownerId VÀO DỮ LIỆU
    final data = med.toMap()
      ..['ownerId'] = uid
      ..['createdAt'] = FieldValue.serverTimestamp();

    final doc = await _medsCollection.add(data);
    return doc.id;
  }

  Stream<List<Medicine>> getMedicines() {
    final uid = _uid;
    if (uid == null) return const Stream<List<Medicine>>.empty();

    // ✅ THÊM LẠI .where() ĐỂ LỌC THEO ownerId
    return _medsCollection
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map<Medicine>((d) => Medicine.fromMap(d.data(), id: d.id))
        .toList());
  }

  Future<void> updateMedicine(Medicine med) async {
    if (med.id == null) throw 'Thiếu id của thuốc';
    final data = med.toMap()..remove('ownerId');
    await _medsCollection.doc(med.id!).update(data);
  }

  Future<void> deleteMedicine(String id) => _medsCollection.doc(id).delete();

  // ================== LOGIC THEO DÕI HẰNG NGÀY (KHÔNG THAY ĐỔI) ==================

  String _generateKeyForDate(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  String _todayKey() => _generateKeyForDate(DateTime.now());

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMedicineDoc(String id) {
    return _medsCollection.doc(id).snapshots();
  }

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

    // Nếu số lượng liều đã thay đổi (người dùng sửa thuốc), điều chỉnh lại mảng
    // Giả định nếu `count` được truyền vào > 0, nó là `count` mới
    if (count > 0 && arr.length != count) {
      if (arr.length > count) {
        arr = arr.take(count).toList();
      } else {
        arr = [...arr, ...List<bool>.filled(count - arr.length, false)];
      }
    }
    return arr;
  }

  Future<void> toggleTodayIntake({
    required String medId,
    required int index,
    required int count,
    required bool value,
  }) async {
    final key = _todayKey();
    final docRef = _medsCollection.doc(medId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = (snap.data() as Map<String, dynamic>? ?? {});
      final daily = (data['dailyTaken'] as Map<String, dynamic>? ?? {});
      List<dynamic> arr = (daily[key] as List?) ?? List<bool>.filled(count, false);

      if (arr.length != count) {
        if (arr.length > count) {
          arr = arr.take(count).toList();
        } else {
          arr = [...arr, ...List<bool>.filled(count - arr.length, false)];
        }
      }

      // Đảm bảo index không vượt quá giới hạn mảng
      if (index < arr.length) {
        arr[index] = value;
      }

      final allDone = arr.every((e) => e == true);

      tx.update(docRef, {
        'dailyTaken.$key': arr,
        'taken': allDone,
      });
    });
  }

  // --- CÁC HÀM THỐNG KÊ (KHÔNG THAY ĐỔI) ---

  int _countByFreq(String freqCode) {
    switch (freqCode) {
      case 'twice':
        return 2;
      case 'thrice':
        return 3;
      default:
        return 1;
    }
  }

  Future<double> getComplianceForDay(DateTime day) async {
    final allMeds = await getMedicines().first;
    if (allMeds.isEmpty) return 0.0;

    int totalDoses = 0;
    int takenDoses = 0;
    final dayKey = _generateKeyForDate(day);

    for (final med in allMeds) {
      final count = _countByFreq(med.frequency);
      totalDoses += count;

      final doc = await _medsCollection.doc(med.id).get();
      if (doc.exists && doc.data()!.containsKey('dailyTaken')) {
        final tracking = doc.data()!['dailyTaken'] as Map<String, dynamic>;
        if (tracking.containsKey(dayKey)) {
          final dosesForDay = List<bool>.from(tracking[dayKey]);
          takenDoses += dosesForDay.where((d) => d == true).length;
        }
      }
    }
    return totalDoses > 0 ? takenDoses / totalDoses : 0.0;
  }

  Future<Map<DateTime, List<ComplianceData>>> getComplianceForMonth(DateTime month) async {
    final allMeds = await getMedicines().first;
    if (allMeds.isEmpty) return {};

    final Map<DateTime, List<ComplianceData>> events = {};
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    final allMedDocs = await Future.wait(
        allMeds.map((med) => _medsCollection.doc(med.id).get()));

    for (int i = 0; i < lastDayOfMonth.day; i++) {
      final currentDay = firstDayOfMonth.add(Duration(days: i));
      final dayKey = _generateKeyForDate(currentDay);

      int totalDosesForDay = 0;
      int takenDosesForDay = 0;

      for (int j = 0; j < allMeds.length; j++) {
        final med = allMeds[j];
        final doc = allMedDocs[j];

        if (med.createdAt != null) {
          final medCreationDate = (med.createdAt as Timestamp).toDate();
          if (currentDay.isBefore(DateTime(medCreationDate.year, medCreationDate.month, medCreationDate.day))) {
            continue;
          }
        }

        final count = _countByFreq(med.frequency);
        totalDosesForDay += count;

        if (doc.exists && doc.data()!.containsKey('dailyTaken')) {
          final tracking = doc.data()!['dailyTaken'] as Map<String, dynamic>;
          if (tracking.containsKey(dayKey)) {
            final dosesForDay = List<bool>.from(tracking[dayKey]);
            takenDosesForDay += dosesForDay.where((d) => d == true).length;
          }
        }
      }

      if (totalDosesForDay > 0) {
        final dayWithoutTime = DateTime(currentDay.year, currentDay.month, currentDay.day);
        events[dayWithoutTime] = [
          ComplianceData(
            dosesTaken: takenDosesForDay,
            dosesMissed: totalDosesForDay - takenDosesForDay,
            totalDoses: totalDosesForDay,
          )
        ];
      }
    }
    return events;
  }
}

// ❗️ DÁN ĐOẠN CODE NÀY VÀO CUỐI FILE `medicine_service.dart` CỦA BẠN
extension MedicineServiceActions on MedicineService {
  /// Đánh dấu một liều thuốc đã uống dựa trên ID và chỉ số liều.
  /// Hàm này được thiết kế để `NotificationService` gọi.
  Future<void> markDoseAsTakenById(String medId, int doseIndex) async {
    // Lấy document để có `count` chính xác nhất
    final medDoc = await watchMedicineDoc(medId).first;
    if (!medDoc.exists) return;

    // Lấy `count` từ dữ liệu thực tế trong Firestore.
    // Nếu chưa có mảng nào cho hôm nay, chúng ta cần `count` từ chính document.
    final medData = Medicine.fromMap(medDoc.data()!, id: medDoc.id);
    final count = _countByFreq(medData.frequency);

    // Gọi hàm có sẵn để cập nhật
    await toggleTodayIntake(
      medId: medId,
      index: doseIndex,
      count: count,
      value: true, // Luôn luôn là true vì đây là hành động "đã uống"
    );
  }
}


