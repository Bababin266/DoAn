import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/note_service.dart';
import '../services/language_service.dart';

class AddEditNoteScreen extends StatefulWidget {
  final Note? note; // note != null => edit, else => add

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

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      // edit mode
      _contentController.text = widget.note!.content;
      _selectedDate = widget.note!.date.toDate();
    } else {
      // add mode
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final isVi = LanguageService.instance.isVietnamese.value;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: isVi ? const Locale('vi', 'VN') : const Locale('en', 'US'),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final content = _contentController.text.trim();
      if (widget.note == null) {
        await _noteService.addNote(content, _selectedDate);
      } else {
        await _noteService.updateNote(widget.note!.id!, content, _selectedDate);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.instance.tr('notes.saved'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${LanguageService.instance.tr('error.generic')}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = LanguageService.instance;

    // Rebuild khi đổi ngôn ngữ
    return ValueListenableBuilder<String>(
      valueListenable: L.langCode,
      builder: (context, _, __) {
        final isVi = L.isVietnamese.value;
        final dateLocale = isVi ? 'vi_VN' : 'en_US';

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.note == null
                ? L.tr('notes.editor.title.new')
                : L.tr('notes.editor.title.edit')),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: L.tr('btn.save'),
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
                  // Date picker
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(L.tr('notes.editor.date')),
                    subtitle: Text(
                      DateFormat.yMMMMEEEEd(dateLocale).format(_selectedDate),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Content
                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: L.tr('notes.editor.content.label'),
                      hintText: L.tr('notes.editor.content.hint'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return L.tr('notes.editor.content.required');
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
