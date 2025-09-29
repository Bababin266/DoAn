import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String? id;
  final String name;
  final String dosage;
  final String time;
  final String type;
  final String frequency;
  final bool taken;
  final Timestamp? createdAt;

  const Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.time,
    this.type = 'Viên nén',
    this.frequency = 'Hàng ngày',
    this.taken = false,
    this.createdAt,
  });

  // ĐÃ CÓ: fromSnapshot(...)
  factory Medicine.fromSnapshot(QueryDocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    return Medicine.fromMap(data, id: doc.id);
  }

  // ✅ THÊM: fromMap để dùng cho service.map(...)
  factory Medicine.fromMap(Map<String, dynamic> data, {String? id}) {
    return Medicine(
      id: id,
      name: (data['name'] ?? '').toString(),
      dosage: (data['dosage'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      type: (data['type'] ?? 'Viên nén').toString(),
      frequency: (data['frequency'] ?? 'Hàng ngày').toString(),
      taken: (data['taken'] ?? false) as bool,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'dosage': dosage,
    'time': time,
    'type': type,
    'frequency': frequency,
    'taken': taken,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };
}
