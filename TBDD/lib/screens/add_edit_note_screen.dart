import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../services/language_service.dart'; // 👈 BƯỚC 1: THÊM IMPORT

class AddEditNoteScreen extends StatefulWidget {
  final Note? note; // Nếu note != null -> đang sửa, ngược lại -> đang thêm mới

  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final NoteService _noteService = NoteService();

  late DateTime _selectedDate;
  bool _isLoading = false;

  // 👈 BƯỚC 2: THÊM HÀM t()
  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      // Chế độ sửa
      _contentController.text = widget.note!.content;
      _selectedDate = widget.note!.date.toDate();
    } else {
      // Chế độ thêm mới
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      // 👈 BƯỚC 4: THÊM LOCALE CHO DATE PICKER
      locale: LanguageService.instance.isVietnamese.value
          ? const Locale('vi', 'VN')
          : const Locale('en', 'US'),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final content = _contentController.text.trim();
      if (widget.note == null) {
        // Thêm mới
        await _noteService.addNote(content, _selectedDate);
      } else {
        // Cập nhật
        await _noteService.updateNote(widget.note!.id!, content, _selectedDate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Lưu ghi chú thành công', 'Note saved successfully'))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('Lỗi', 'Error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👈 BƯỚC 3: SỬ DỤNG VALUELISTENABLEBUILDER
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVietnamese, _) {
        return Scaffold(
          appBar: AppBar(
            // 👈 BƯỚC 4: CẬP NHẬT UI VỚI HÀM t()
            title: Text(widget.note == null
                ? t('Thêm ghi chú mới', 'Add New Note')
                : t('Chỉnh sửa ghi chú', 'Edit Note')),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: t('Lưu', 'Save'),
                onPressed: _isLoading ? null : _saveNote,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chọn ngày
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(t('Ngày ghi chú', 'Note Date')),
                    subtitle: Text(
                      DateFormat.yMMMMEEEEd(isVietnamese ? 'vi_VN' : 'en_US')
                          .format(_selectedDate),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Nội dung
                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: t('Nội dung ghi chú', 'Note Content'),
                      hintText: t('Hôm nay bạn cảm thấy thế nào?', 'How are you feeling today?'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return t('Vui lòng nhập nội dung', 'Please enter content');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
