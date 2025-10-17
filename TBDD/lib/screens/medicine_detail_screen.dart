import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../services/dose_state_service.dart';
import '../services/language_service.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final _svc = MedicineService();
  final _noteCtrl = TextEditingController();
  late Future<List<String>> _timesFut;

  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  @override
  void initState() {
    super.initState();
    _timesFut = DoseStateService.instance.getSavedTimes(widget.medicine.id!);
    _loadNote();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final sp = await SharedPreferences.getInstance();
    _noteCtrl.text = sp.getString('med_note_${widget.medicine.id}') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _saveNote() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('med_note_${widget.medicine.id}', _noteCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(t('Đã lưu ghi chú', 'Notes saved')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  int _countByFreq(String f) => switch (f) { 'twice' => 2, 'thrice' => 3, _ => 1 };

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    final count = _countByFreq(m.frequency);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Chi tiết thuốc', 'Medicine Details')),
        elevation: 0,
      ),
      body: FutureBuilder<List<String>>(
        future: _timesFut,
        builder: (context, timeSnap) {
          final times = (timeSnap.data != null && timeSnap.data!.isNotEmpty)
              ? timeSnap.data!
              : [m.time];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Card với gradient
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.medication_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    m.dosage,
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Frequency Card
                      _buildInfoCard(
                        context,
                        icon: Icons.repeat_rounded,
                        iconColor: Colors.blue,
                        title: t('Tần suất', 'Frequency'),
                        content: switch (m.frequency) {
                          'twice' => t('2 lần/ngày', 'Twice daily'),
                          'thrice' => t('3 lần/ngày', '3 times daily'),
                          _ => t('1 lần/ngày', 'Once daily')
                        },
                      ),
                      const SizedBox(height: 16),

                      // Time Card
                      _buildInfoCard(
                        context,
                        icon: Icons.access_time_rounded,
                        iconColor: Colors.purple,
                        title: t('Giờ uống', 'Dosage Times'),
                        content: times.join('  •  '),
                      ),
                      const SizedBox(height: 24),

                      // Trạng thái hôm nay
                      Text(
                        t('Trạng thái hôm nay', 'Today\'s Status'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder(
                        stream: _svc.watchMedicineDoc(m.id!),
                        builder: (context, snap) {
                          final takenToday = (snap.hasData &&
                              (snap.data as dynamic).exists)
                              ? _svc.getTodayArrayFromDoc(
                              snap.data as dynamic, count)
                              : List<bool>.filled(count, false);

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: List.generate(count, (i) {
                              final on =
                              (i < takenToday.length) ? takenToday[i] : false;
                              final label = (i < times.length)
                                  ? times[i]
                                  : t('Lần ${i + 1}', 'Dose ${i + 1}');
                              return _buildDoseChip(
                                  context, label, on, i, m.id!, count);
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Ghi chú Section
                      Text(
                        t('Ghi chú', 'Notes'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _noteCtrl,
                          minLines: 4,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: t(
                              'Nhập ghi chú cho thuốc này…',
                              'Write notes for this medicine…',
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saveNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            t('Lưu ghi chú', 'Save Notes'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String content,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseChip(
      BuildContext context,
      String label,
      bool isTaken,
      int index,
      String medId,
      int count,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isTaken
          ? colorScheme.primary
          : colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(16),
      elevation: isTaken ? 4 : 0,
      child: InkWell(
        onTap: () => _svc.toggleTodayIntake(
          medId: medId,
          index: index,
          count: count,
          value: !isTaken,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTaken ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isTaken ? Colors.white : Colors.grey[700],
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isTaken ? Colors.white : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}