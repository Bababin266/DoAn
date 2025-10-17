import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String? id;
  final String content; // Nội dung ghi chú
  final Timestamp date;   // Ngày của ghi chú
  final String userId;    // ID của người dùng sở hữu ghi chú

  Note({
    this.id,
    required this.content,
    required this.date,
    required this.userId,
  });

  // Chuyển từ DocumentSnapshot (dữ liệu từ Firestore) thành đối tượng Note
  factory Note.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      content: data['content'] ?? '',
      date: data['date'] ?? Timestamp.now(),
      userId: data['userId'] ?? '',
    );
  }

  // Chuyển từ đối tượng Note thành một Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'date': date,
      'userId': userId,
    };
  }
}
