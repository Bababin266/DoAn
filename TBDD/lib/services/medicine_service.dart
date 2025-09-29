import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';

class MedicineService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _meds => _db.collection('medicines');

  // ➜ trả về docId để dùng làm gốc id notification
  Future<String> addMedicine(Medicine med) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'Chưa đăng nhập';

    final data = med.toMap()
      ..['ownerId']  = uid
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
}
