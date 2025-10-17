import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/note_service.dart';import '../services/language_service.dart'; // 👈 THÊM IMPORT
import 'add_edit_note_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NoteService _noteService = NoteService();

  // 👈 THÊM CÁC HÀM ĐA NGÔN NGỮ
  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  void _toggleLanguage() {
    final ln = LanguageService.instance.isVietnamese;
    ln.value = !ln.value;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ln.value ? 'Đã chuyển sang Tiếng Việt' : 'Switched to English'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }
  // --- KẾT THÚC PHẦN THÊM MỚI ---

  void _navigateToAddEditNote([Note? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditNoteScreen(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👈 BỌC SCAFFOLD BẰNG VALUELISTENABLEBUILDER
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVietnamese, _) {
        return Scaffold(
          appBar: AppBar(
            // 👈 CẬP NHẬT TIÊU ĐỀ
            title: Text(t('Ghi chú sức khỏe', 'Health Notes')),
            elevation: 1,
            // 👈 THÊM NÚT ĐỔI NGÔN NGỮ
            actions: [
              IconButton(
                icon: const Icon(Icons.language),
                tooltip: t('Đổi ngôn ngữ', 'Change language'),
                onPressed: _toggleLanguage,
              ),
            ],
          ),
          body: StreamBuilder<List<Note>>(
            stream: _noteService.getNotes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // 👈 CẬP NHẬT THÔNG BÁO LỖI
                return Center(child: Text('${t('Lỗi', 'Error')}: ${snapshot.error}'));
              }
              final notes = snapshot.data ?? [];

              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      // 👈 CẬP NHẬT VĂN BẢN
                      Text(
                        t('Chưa có ghi chú nào', 'No notes yet'),
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Nhóm các ghi chú theo ngày
              final groupedNotes = groupBy(notes, (Note note) => DateFormat('yyyy-MM-dd').format(note.date.toDate()));
              final sortedKeys = groupedNotes.keys.toList()..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final dateKey = sortedKeys[index];
                  final notesForDate = groupedNotes[dateKey]!;
                  // 👈 CẬP NHẬT ĐỊNH DẠNG NGÀY THÁNG ĐA NGÔN NGỮ
                  final displayDate = DateFormat.yMMMMEEEEd(isVietnamese ? 'vi_VN' : 'en_US').format(notesForDate.first.date.toDate());

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          displayDate,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ),
                      // 👈 TRUYỀN HÀM t() VÀO WIDGET CON
                      ...notesForDate.map((note) => _buildNoteCard(note, t, isVietnamese)),
                    ],
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddEditNote(),
            // 👈 CẬP NHẬT LABEL
            label: Text(t('Thêm ghi chú', 'Add Note')),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  // 👈 THÊM THAM SỐ CHO HÀM _buildNoteCard
  Widget _buildNoteCard(Note note, String Function(String, String) t, bool isVietnamese) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          note.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        // 👈 CẬP NHẬT ĐỊNH DẠNG GIỜ ĐA NGÔN NGỮ
        subtitle: Text(DateFormat.Hm(isVietnamese ? 'vi_VN' : 'en_US').format(note.date.toDate())),
        onTap: () => _navigateToAddEditNote(note),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                // 👈 CẬP NHẬT VĂN BẢN TRONG DIALOG
                title: Text(t('Xác nhận xóa', 'Confirm Deletion')),
                content: Text(t('Bạn có chắc muốn xóa ghi chú này không?', 'Are you sure you want to delete this note?')),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('Hủy', 'Cancel'))),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(t('Xóa', 'Delete'), style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true && mounted) {
              await _noteService.deleteNote(note.id!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('Đã xóa ghi chú', 'Note deleted'))),
              );
            }
          },
        ),
      ),
    );
  }
}

