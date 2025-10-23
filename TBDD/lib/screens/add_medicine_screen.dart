// lib/screens/add_medicine_screen.dart
import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';
import '../services/dose_state_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _time1Ctrl = TextEditingController();
  final _time2Ctrl = TextEditingController();
  final _time3Ctrl = TextEditingController();

  final MedicineService _service = MedicineService();
  final NotificationService _notiService = NotificationService.instance;

  bool _loading = false;
  late final AnimationController _ac;
  late final Animation<double> _fade;

  static const List<String> _freqCodes = ['once', 'twice', 'thrice'];
  String _freqCode = 'once';

  static const List<String> _typeCodes = [
    'pill','capsule','syrup','topical','eyedrop','spray','injection'
  ];
  String _typeCode = 'pill';

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

    if (_isEditing) {
      final m = widget.medicine!;
      _nameCtrl.text = m.name;
      _dosageCtrl.text = m.dosage;
      _freqCode = _guessFreqCode(m.frequency);
      _typeCode = _guessTypeCode(m.type);
      _loadSavedTimesIfAny(m.id!);
    } else {
      final now = TimeOfDay.now();
      _time1Ctrl.text = _toHHmm(now);
    }

    _ac.forward();
  }

  Future<void> _loadSavedTimesIfAny(String medId) async {
    final saved = await DoseStateService.instance.getSavedTimes(medId);
    if (saved.isNotEmpty) {
      _time1Ctrl.text = saved.isNotEmpty ? saved[0] : '';
      _time2Ctrl.text = saved.length >= 2 ? saved[1] : '';
      _time3Ctrl.text = saved.length >= 3 ? saved[2] : '';
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _time1Ctrl.dispose();
    _time2Ctrl.dispose();
    _time3Ctrl.dispose();
    super.dispose();
  }

  // ===== Helpers =====
  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  ({int hour, int minute}) _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final initialTime = ctrl.text.isNotEmpty
        ? TimeOfDay(
      hour: _parseHHmm(ctrl.text).hour,
      minute: _parseHHmm(ctrl.text).minute,
    )
        : TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null && mounted) {
      setState(() {
        ctrl.text = _toHHmm(picked);
      });
    }
  }

  List<String> _collectTimes() {
    final times = <String>[];
    if (_time1Ctrl.text.trim().isNotEmpty) times.add(_time1Ctrl.text.trim());
    if (_freqCode == 'twice' || _freqCode == 'thrice') {
      if (_time2Ctrl.text.trim().isNotEmpty) times.add(_time2Ctrl.text.trim());
    }
    if (_freqCode == 'thrice') {
      if (_time3Ctrl.text.trim().isNotEmpty) times.add(_time3Ctrl.text.trim());
    }
    return times;
  }

  // ===== Logic chính: Lưu và Xóa =====
  Future<void> _save() async {
    final L = LanguageService.instance;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final times = _collectTimes();
      final medicineToSave = Medicine(
        id: _isEditing ? widget.medicine!.id : null,
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        time: times.isNotEmpty ? times[0] : '08:00',
        type: _typeCode,
        frequency: _freqCode,
        taken: false,
      );

      String finalId;
      Medicine finalMedicine;

      if (_isEditing) {
        await _service.updateMedicine(medicineToSave);
        finalId = medicineToSave.id!;
        finalMedicine = medicineToSave;
      } else {
        finalId = await _service.addMedicine(medicineToSave);
        finalMedicine = medicineToSave.copyWith(id: finalId);
      }

      await DoseStateService.instance.saveTimes(finalId, times);
      await _notiService.rescheduleNotificationsForMedicine(finalMedicine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? L.tr('toast.updated') : L.tr('toast.added')),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L.tr('error.generic')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final L = LanguageService.instance;
    if (!_isEditing || widget.medicine?.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.tr('confirm.delete.title')),
        content: Text(L.tr('confirm.delete.body',
            params: {'name': widget.medicine!.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.tr('action.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.tr('action.delete')),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    setState(() => _loading = true);

    try {
      final id = widget.medicine!.id!;
      await _notiService.cancelAllNotificationsForMedicine(id);
      await _service.deleteMedicine(id);
      await DoseStateService.instance.clearDoseState(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.tr('toast.deleted.medicine'))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L.tr('error.generic')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe langCode → rebuild ngay khi đổi
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.langCode,
      builder: (_, __, ___) {
        final L = LanguageService.instance;
        final title = _isEditing ? L.tr('add.title.edit') : L.tr('add.title.new');

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (_isEditing)
                IconButton(
                  tooltip: L.tr('action.delete'),
                  onPressed: _loading ? null : _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          body: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _nameCtrl,
                        label: L.tr('field.name'),
                        icon: Icons.medication,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? L.tr('validate.name')
                            : null,
                      ),
                      _buildTextField(
                        controller: _dosageCtrl,
                        label: L.tr('field.dosage'),
                        icon: Icons.science_outlined,
                        hint: L.tr('hint.dosage'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? L.tr('validate.dosage')
                            : null,
                      ),
                      _buildDropdown(
                        codes: _freqCodes,
                        value: _freqCode,
                        labelBuilder: _freqLabel,
                        onChanged: (v) => setState(() => _freqCode = v ?? 'once'),
                        label: L.tr('field.frequency'),
                        icon: Icons.repeat_on_outlined,
                      ),
                      _buildDropdown(
                        codes: _typeCodes,
                        value: _typeCode,
                        labelBuilder: _typeLabel,
                        onChanged: (v) => setState(() => _typeCode = v ?? 'pill'),
                        label: L.tr('field.type'),
                        icon: Icons.category_outlined,
                      ),

                      const SizedBox(height: 16),
                      Text(L.tr('field.times'), style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),

                      _buildTimePickerField(
                        controller: _time1Ctrl,
                        label: L.tr('time.n', params: {'n': '1'}),
                      ),
                      if (_freqCode == 'twice' || _freqCode == 'thrice')
                        _buildTimePickerField(
                          controller: _time2Ctrl,
                          label: L.tr('time.n', params: {'n': '2'}),
                        ),
                      if (_freqCode == 'thrice')
                        _buildTimePickerField(
                          controller: _time3Ctrl,
                          label: L.tr('time.n', params: {'n': '3'}),
                        ),

                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: _loading ? null : _save,
                        icon: _loading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save_alt_outlined),
                        label: Text(_isEditing ? L.tr('btn.update') : L.tr('btn.save')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== UI helpers =====
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown({
    required List<String> codes,
    required String value,
    required String Function(String) labelBuilder,
    required void Function(String?) onChanged,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        items: codes
            .map(
              (c) => DropdownMenuItem(
            value: c,
            child: Text(labelBuilder(c)),
          ),
        )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required TextEditingController controller,
    required String label,
  }) {
    final L = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _pick(controller),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? L.tr('validate.time') : null,
      ),
    );
  }

  String _freqLabel(String code) {
    final L = LanguageService.instance;
    return switch (code) {
      'once'   => L.tr('freq.once'),
      'twice'  => L.tr('freq.twice'),
      'thrice' => L.tr('freq.thrice'),
      _        => code,
    };
  }

  String _typeLabel(String code) {
    final L = LanguageService.instance;
    return switch (code) {
      'pill'      => L.tr('type.pill'),
      'capsule'   => L.tr('type.capsule'),
      'syrup'     => L.tr('type.syrup'),
      'topical'   => L.tr('type.topical'),
      'eyedrop'   => L.tr('type.eyedrop'),
      'spray'     => L.tr('type.spray'),
      'injection' => L.tr('type.injection'),
      _           => code,
    };
  }

  String _guessFreqCode(String raw) {
    final x = raw.trim().toLowerCase();
    if (['twice', '2 lần/ngày'].contains(x)) return 'twice';
    if (['thrice', '3 lần/ngày'].contains(x)) return 'thrice';
    return 'once';
  }

  String _guessTypeCode(String raw) {
    final x = raw.trim().toLowerCase();
    if (['capsule','viên nang'].contains(x)) return 'capsule';
    if (['syrup','siro'].contains(x)) return 'syrup';
    if (['topical','thuốc bôi'].contains(x)) return 'topical';
    if (['eyedrop','eye drops','thuốc nhỏ mắt'].contains(x)) return 'eyedrop';
    if (['spray','thuốc xịt'].contains(x)) return 'spray';
    if (['injection','thuốc tiêm'].contains(x)) return 'injection';
    return 'pill';
  }
}
