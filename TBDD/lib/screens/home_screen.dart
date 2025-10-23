// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/dose_state_service.dart';
import '../services/language_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'add_medicine_screen.dart';
import 'compliance_screen.dart';
import 'notes_screen.dart';
import 'medicine_detail_screen.dart';

enum MedFilter { all, notTaken, taken, missed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MedicineService _medicineService = MedicineService();
  final AuthService _authService = AuthService();
  final NotificationService _notiService = NotificationService.instance;

  late final AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  Timer? _debounce;
  MedFilter _filter = MedFilter.all;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  List<Medicine> _filterMedicines(
      List<Medicine> medicines,
      Map<String, List<bool>> missedStatus,
      ) {
    List<Medicine> list = medicines;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((m) =>
      m.name.toLowerCase().contains(q) ||
          m.dosage.toLowerCase().contains(q))
          .toList();
    }
    switch (_filter) {
      case MedFilter.notTaken:
        return list.where((m) => !m.taken).toList();
      case MedFilter.taken:
        return list.where((m) => m.taken).toList();
      case MedFilter.missed:
        return list
            .where((m) => missedStatus[m.id]?.any((isMissed) => isMissed) ?? false)
            .toList();
      case MedFilter.all:
      default:
        return list;
    }
  }

  // ================== DELETE (i18n) ==================
  Future<void> _deleteMedicine(Medicine medicine) async {
    final L = LanguageService.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.tr('confirm.delete.title')),
        content: Text(L.tr('confirm.delete.body', params: {'name': medicine.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L.tr('action.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L.tr('action.delete')),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm || !mounted) return;

    try {
      await _notiService.cancelAllNotificationsForMedicine(medicine.id!);
      await _medicineService.deleteMedicine(medicine.id!);
      await DoseStateService.instance.clearDoseState(medicine.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(L.tr('toast.deleted')),
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('error.delete') + '$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== EXPORT ==================
  Future<List<Medicine>> _getFilteredMedsForExport() async {
    final allMeds = await _medicineService.getMedicines().first;
    return allMeds;
  }

  Future<void> _exportToCsv() async {
    final L = LanguageService.instance;
    try {
      final medicines = await _getFilteredMedsForExport();
      if (medicines.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.tr('export.none'))));
        return;
      }
      final rows = <List<dynamic>>[
        [L.tr('table.name'), L.tr('table.dosage'), L.tr('table.frequency')],
        ...medicines.map((m) => [m.name, m.dosage, _freqLabel(m.frequency)]),
      ];
      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/medicines_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csvData, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('export.saved.csv') + file.path.split('/').last),
          action: SnackBarAction(
            label: L.tr('action.open'),
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('error.export.csv') + '$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToPdf() async {
    final L = LanguageService.instance;
    try {
      final medicines = await _getFilteredMedsForExport();
      if (medicines.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L.tr('export.none'))));
        return;
      }
      final pdfData = await _generatePdf(medicines);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/medicines_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(pdfData, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('export.saved.pdf') + file.path.split('/').last),
          action: SnackBarAction(
            label: L.tr('action.open'),
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('error.export.pdf') + '$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _generatePdf(List<Medicine> medicines) async {
    final L = LanguageService.instance;
    final pdf = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(L.tr('pdf.title'),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
            pw.SizedBox(height: 8),
            pw.Text(
              '${L.tr('pdf.exported.on')}: '
                  '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (ctx) => [
          pw.Table.fromTextArray(
            headers: [L.tr('table.name'), L.tr('table.dosage'), L.tr('table.frequency')],
            data: medicines.map((m) => [m.name, m.dosage, _freqLabel(m.frequency)]).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
          ),
        ],
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${L.tr('pdf.page')} ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey),
          ),
        ),
      ),
    );
    return pdf.save();
  }

  // ================== UI helpers ==================
  String _homeLogoAsset(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'assets/images/icon_monochrome.png'
        : 'assets/images/icon_foreground.png';
  }

  Widget _buildEmptySliver() {
    final L = LanguageService.instance;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 18),
            Text(L.tr('empty.title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              L.tr('empty.hint'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  int _countByFreq(String code) {
    switch (code) {
      case 'twice':
        return 2;
      case 'thrice':
        return 3;
      default:
        return 1;
    }
  }

  String _freqLabel(String code) {
    final L = LanguageService.instance;
    switch (code) {
      case 'twice':
        return L.tr('freq.twice');
      case 'thrice':
        return L.tr('freq.thrice');
      default:
        return L.tr('freq.once');
    }
  }

  Future<Map<String, List<bool>>> _calculateAllMissedStatuses(
      List<Medicine> medicines) async {
    final now = DateTime.now();
    final result = <String, List<bool>>{};
    for (final m in medicines) {
      final count = _countByFreq(m.frequency);
      final missed = List<bool>.filled(count, false);
      final times = await DoseStateService.instance.getSavedTimes(m.id!);
      final doc = await _medicineService.watchMedicineDoc(m.id!).first;

      if (doc.exists) {
        final takenToday = _medicineService.getTodayArrayFromDoc(doc, count);
        for (int i = 0; i < times.length; i++) {
          final p = times[i].split(':');
          if (p.length == 2) {
            final h = int.tryParse(p[0]) ?? 0;
            final mm = int.tryParse(p[1]) ?? 0;
            final t = DateTime(now.year, now.month, now.day, h, mm);
            if (now.isAfter(t) && (i >= takenToday.length || !takenToday[i])) {
              missed[i] = true;
            }
          }
        }
      }
      result[m.id!] = missed;
    }
    return result;
  }

  // Language Picker
  void _showLanguagePicker(BuildContext context) {
    final ls = LanguageService.instance;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<String>(
          valueListenable: ls.langCode,
          builder: (_, code, __) {
            final items = ls.supported.value;
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(ls.tr('lang.select'),
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                const Divider(height: 1),
                ...items.map((c) {
                  final selected = (c == code);
                  return ListTile(
                    leading:
                    Text(ls.flagOf(c), style: const TextStyle(fontSize: 22)),
                    title: Text(ls.displayNameOf(c)),
                    trailing:
                    selected ? const Icon(Icons.check, color: Colors.teal) : null,
                    onTap: () async {
                      await ls.setLanguage(c); // -> notify và rebuild toàn app
                      if (mounted) Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final L = LanguageService.instance;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.tr('logout.title')),
        content: Text(L.tr('logout.body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(L.tr('action.cancel'))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L.tr('menu.logout'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
    if (!ok) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final L = LanguageService.instance;

    // 🔒 Clamp text-scale để tránh overflow khi cỡ chữ hệ thống quá lớn
    final clampedMedia = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.15),
      ),
    );

    return MediaQuery(
      data: clampedMedia,
      child: ValueListenableBuilder<String>(
        valueListenable: LanguageService.instance.langCode,
        builder: (context, lang, _) {
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  expandedHeight: 120,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    title: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            _homeLogoAsset(context),
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.local_pharmacy,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ✅ Chữ nhỏ hơn + FittedBox để không bị tràn
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              L.tr('home.title'),
                              maxLines: 1,
                              softWrap: false,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: (Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.fontSize ??
                                    20) -
                                    2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    centerTitle: false,
                  ),
                  actions: [
                    IconButton(
                      tooltip: L.tr('menu.notes'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotesScreen()),
                      ),
                      icon: const Icon(Icons.note_alt_outlined),
                    ),
                    IconButton(
                      tooltip: L.tr('menu.stats'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ComplianceScreen()),
                      ),
                      icon: const Icon(Icons.bar_chart_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip: L.tr('menu.more'),
                      onSelected: (value) async {
                        if (value == 'export_pdf') {
                          _exportToPdf();
                        } else if (value == 'export_csv') {
                          _exportToCsv();
                        } else if (value == 'theme') {
                          ThemeService.instance.toggle();
                        } else if (value == 'lang') {
                          _showLanguagePicker(context);
                        } else if (value == 'logout') {
                          await _logout();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export_pdf',
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined,
                                  color: Colors.red),
                              const SizedBox(width: 12),
                              Text(L.tr('menu.export.pdf')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export_csv',
                          child: Row(
                            children: [
                              const Icon(Icons.description_outlined,
                                  color: Colors.green),
                              const SizedBox(width: 12),
                              Text(L.tr('menu.export.csv')),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'theme',
                          child: Row(
                            children: [
                              const Icon(Icons.brightness_6_outlined),
                              const SizedBox(width: 12),
                              Text(L.tr('menu.theme')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'lang',
                          child: Row(
                            children: [
                              const Icon(Icons.translate_outlined),
                              const SizedBox(width: 12),
                              Text(L.tr('menu.lang')),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              const Icon(Icons.logout, color: Colors.red),
                              const SizedBox(width: 12),
                              Text(L.tr('menu.logout'),
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // search box
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: L.tr('search.hint'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.6),
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                ),

                // filter chips
                SliverToBoxAdapter(
                  child: StreamBuilder<List<Medicine>>(
                    stream: _medicineService.getMedicines(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData ||
                          (snapshot.data?.isEmpty ?? true)) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data!;
                      return FutureBuilder<Map<String, List<bool>>>(
                        future: _calculateAllMissedStatuses(data),
                        builder: (context, missSnap) {
                          final missedMap = missSnap.data ?? {};
                          final taken = data.where((m) => m.taken).length;
                          final missed = data
                              .where((m) =>
                          missedMap[m.id]?.any((b) => b) ?? false)
                              .length;
                          final notTaken = data.length - taken;

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: Text(
                                      "${L.tr('filter.all')} (${data.length})"),
                                  selected: _filter == MedFilter.all,
                                  onSelected: (_) =>
                                      setState(() => _filter = MedFilter.all),
                                ),
                                FilterChip(
                                  label: Text(
                                      "${L.tr('filter.pending')} ($notTaken)"),
                                  selected: _filter == MedFilter.notTaken,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.notTaken),
                                ),
                                FilterChip(
                                  label: Text(
                                      "${L.tr('filter.missed')} ($missed)"),
                                  selected: _filter == MedFilter.missed,
                                  selectedColor: Colors.red.shade200,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.missed),
                                ),
                                FilterChip(
                                  label: Text(
                                      "${L.tr('filter.done')} ($taken)"),
                                  selected: _filter == MedFilter.taken,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.taken),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // list
                StreamBuilder<List<Medicine>>(
                  stream: _medicineService.getMedicines(),
                  builder: (context, medSnap) {
                    if (medSnap.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (medSnap.hasError) {
                      return SliverFillRemaining(
                        child: Center(
                            child: Text(
                                LanguageService.instance.tr('error.loading'))),
                      );
                    }
                    final all = medSnap.data ?? [];
                    if (all.isEmpty) return _buildEmptySliver();

                    return FutureBuilder<Map<String, List<bool>>>(
                      future: _calculateAllMissedStatuses(all),
                      builder: (context, missSnap) {
                        final missedMap = missSnap.data ?? {};
                        final filtered = _filterMedicines(all, missedMap);

                        if (filtered.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Text(LanguageService.instance
                                  .tr('empty.search')),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, i) =>
                                  _buildMedicineCard(filtered[i], i, filtered.length),
                              childCount: filtered.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
              ),
              tooltip: L.tr('fab.add'),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine, int index, int total) {
    final L = LanguageService.instance;

    final anim = CurvedAnimation(
      parent: _animationController,
      curve: Interval(index / total, 1.0, curve: Curves.easeOutCubic),
    );
    final count = _countByFreq(medicine.frequency);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .4), end: Offset.zero)
            .animate(anim),
        child: FutureBuilder<List<String>>(
          future: DoseStateService.instance.getSavedTimes(medicine.id!),
          initialData: const [],
          builder: (context, timeSnap) {
            final doseTimes = timeSnap.data ?? [];
            return StreamBuilder(
              stream: _medicineService.watchMedicineDoc(medicine.id!),
              builder: (context, snap) {
                bool allDone = medicine.taken;
                int takenCount = 0;
                List<bool> takenToday = [];
                List<bool> missedToday = List.filled(count, false);
                bool hasMissed = false;

                if (snap.hasData && snap.data!.exists) {
                  takenToday =
                      _medicineService.getTodayArrayFromDoc(snap.data!, count);
                  takenCount = takenToday.where((e) => e).length;
                  allDone = takenCount == count;

                  final now = DateTime.now();
                  for (int i = 0; i < doseTimes.length; i++) {
                    final parts = doseTimes[i].split(':');
                    if (parts.length == 2) {
                      final h = int.tryParse(parts[0]) ?? 0;
                      final m = int.tryParse(parts[1]) ?? 0;
                      final t = DateTime(now.year, now.month, now.day, h, m);
                      if (now.isAfter(t) &&
                          (i >= takenToday.length || !takenToday[i])) {
                        missedToday[i] = true;
                      }
                    }
                  }
                  hasMissed = missedToday.any((b) => b);
                }

                final stripeColor = hasMissed
                    ? Colors.red.shade400
                    : allDone
                    ? Colors.teal.shade700
                    : (takenCount > 0)
                    ? Colors.teal.shade300
                    : Colors.grey.shade400;

                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicineDetailScreen(medicine: medicine),
                        ),
                      );
                    },
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            decoration: BoxDecoration(
                              color: stripeColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title + menu
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              medicine.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                  fontWeight:
                                                  FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Chip(
                                              avatar: Icon(
                                                Icons.access_time_filled,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              label: Text(
                                                doseTimes.isEmpty
                                                    ? medicine.time
                                                    : doseTimes.join(' - '),
                                                style: const TextStyle(
                                                    fontWeight:
                                                    FontWeight.w500),
                                              ),
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4),
                                              visualDensity:
                                              VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'edit') {
                                            if (!mounted) return;
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AddMedicineScreen(
                                                        medicine: medicine),
                                              ),
                                            );
                                          } else if (v == 'delete') {
                                            await _deleteMedicine(medicine);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit_outlined,
                                                    color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(L.tr('action.edit')),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red),
                                                const SizedBox(width: 8),
                                                Text(L.tr('action.delete')),
                                              ],
                                            ),
                                          ),
                                        ],
                                        icon: Icon(Icons.more_vert,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // dose chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: List.generate(count, (i) {
                                      final isTaken = i < takenToday.length
                                          ? takenToday[i]
                                          : false;
                                      final isMissed =
                                      i < missedToday.length
                                          ? missedToday[i]
                                          : false;
                                      final label = i < doseTimes.length
                                          ? doseTimes[i]
                                          : L.tr('dose.n',
                                          params: {'n': '${i + 1}'});
                                      return ActionChip(
                                        avatar: Icon(
                                          isTaken
                                              ? Icons.check_circle
                                              : (isMissed
                                              ? Icons
                                              .warning_amber_rounded
                                              : Icons
                                              .radio_button_unchecked),
                                          color: isTaken
                                              ? Colors.white
                                              : (isMissed
                                              ? Colors.white
                                              : Colors.grey[700]),
                                        ),
                                        label: Text(label),
                                        backgroundColor: isTaken
                                            ? stripeColor
                                            : (isMissed
                                            ? Colors.red.shade400
                                            : Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant),
                                        labelStyle: TextStyle(
                                          color: (isTaken || isMissed)
                                              ? Colors.white
                                              : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                          fontWeight: (isTaken || isMissed)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        onPressed: () {
                                          _medicineService.toggleTodayIntake(
                                            medId: medicine.id!,
                                            index: i,
                                            count: count,
                                            value: !isTaken,
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
