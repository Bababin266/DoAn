import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/note_service.dart';
import '../services/language_service.dart';
import 'add_edit_note_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NoteService _noteService = NoteService();

  String _calendarLocale(String code) {
    switch (code) {
      case 'vi':
        return 'vi_VN';
      case 'en':
        return 'en_US';
      case 'ja':
        return 'ja_JP';
      case 'ko':
        return 'ko_KR';
      case 'fr':
        return 'fr_FR';
      case 'es':
        return 'es_ES';
      case 'de':
        return 'de_DE';
      case 'zh-Hans':
        return 'zh_CN';
      case 'zh-Hant':
        return 'zh_TW';
      case 'ru':
        return 'ru_RU';
      case 'ar':
        return 'ar_SA';
      case 'hi':
        return 'hi_IN';
      case 'th':
        return 'th_TH';
      case 'id':
        return 'id_ID';
      case 'tr':
        return 'tr_TR';
      default:
        return 'en_US';
    }
  }

  void _navigateToAddEditNote([Note? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditNoteScreen(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final L = LanguageService.instance;
    return ValueListenableBuilder<String>(
      valueListenable: L.langCode,
      builder: (_, code, __) {
        final loc = _calendarLocale(code);
        return Scaffold(
          appBar: AppBar(
            title: Text(L.tr('notes.appbar')),
            elevation: 1,
          ),
          body: StreamBuilder<List<Note>>(
            stream: _noteService.getNotes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('${L.tr('error.generic')}: ${snapshot.error}'));
              }
              final notes = snapshot.data ?? [];
              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(L.tr('notes.empty'),
                          style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final grouped = groupBy(
                notes,
                    (Note n) => DateFormat('yyyy-MM-dd').format(n.date.toDate()),
              );
              final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: keys.length,
                itemBuilder: (_, idx) {
                  final dateKey = keys[idx];
                  final notesForDate = grouped[dateKey]!;
                  final displayDate =
                  DateFormat.yMMMMEEEEd(loc).format(notesForDate.first.date.toDate());

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          displayDate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      ...notesForDate.map((n) => _buildNoteCard(n, L, loc)),
                    ],
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddEditNote(),
            label: Text(L.tr('notes.add')),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildNoteCard(Note note, LanguageService L, String loc) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          note.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateFormat.Hm(loc).format(note.date.toDate())),
        onTap: () => _navigateToAddEditNote(note),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(L.tr('notes.delete.title')),
                content: Text(L.tr('notes.delete.body')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(L.tr('action.cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(L.tr('action.delete'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true && mounted) {
              await _noteService.deleteNote(note.id!);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(L.tr('notes.deleted'))));
            }
          },
        ),
      ),
    );
  }
}
