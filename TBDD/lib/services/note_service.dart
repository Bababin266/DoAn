import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';

class NoteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy stream của tất cả các ghi chú của người dùng hiện tại, sắp xếp theo ngày mới nhất
  Stream<List<Note>> getNotes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Trả về danh sách rỗng nếu người dùng chưa đăng nhập
    }

    return _db
        .collection('notes')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList());
  }

  // Thêm một ghi chú mới
  Future<void> addNote(String content, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final newNote = Note(
      content: content,
      date: Timestamp.fromDate(date),
      userId: user.uid,
    );
    await _db.collection('notes').add(newNote.toFirestore());
  }

  // Cập nhật một ghi chú đã có
  Future<void> updateNote(String id, String newContent, DateTime newDate) async {
    await _db.collection('notes').doc(id).update({
      'content': newContent,
      'date': Timestamp.fromDate(newDate),
    });
  }

  // Xóa một ghi chú
  Future<void> deleteNote(String id) async {
    await _db.collection('notes').doc(id).delete();
  }
}
