// lib/screens/add_medicine_screen.dart
import 'package:flutter/material.dart';
import '../models/medicine.dart';import '../services/medicine_service.dart';
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
  final _nameCtrl   = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _time1Ctrl  = TextEditingController();
  final _time2Ctrl  = TextEditingController();
  final _time3Ctrl  = TextEditingController();

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
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

    if (_isEditing) {
      final m = widget.medicine!;
      _nameCtrl.text   = m.name;
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
  String t(String vi, String en) => LanguageService.instance.isVietnamese.value ? vi : en;

  String _toHHmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  ({int hour, int minute}) _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final initialTime = ctrl.text.isNotEmpty
        ? TimeOfDay(hour: _parseHHmm(ctrl.text).hour, minute: _parseHHmm(ctrl.text).minute)
        : TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      // ✅ ĐÃ XÓA THAM SỐ `locale` KHÔNG HỢP LỆ
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
          SnackBar(content: Text(_isEditing ? t('Đã cập nhật thuốc', 'Medicine updated') : t('Đã thêm thuốc mới', 'New medicine added'))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('Lỗi', 'Error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing || widget.medicine?.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Xác nhận xoá', 'Confirm Deletion')),
        content: Text(t("Bạn có chắc muốn xóa '${widget.medicine!.name}'?", "Are you sure you want to delete '${widget.medicine!.name}'?")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Hủy', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Xoá', 'Delete')),
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
      await DoseStateService.instance.clearDoseState(id); // ✅ HÀM NÀY GIỜ ĐÃ HỢP LỆ

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Đã xóa thuốc', 'Medicine deleted'))));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('Lỗi', 'Error')}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVI, _) {
        final title = _isEditing ? t('Chỉnh sửa thuốc', 'Edit Medicine') : t('Thêm thuốc mới', 'Add New Medicine');

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (_isEditing)
                IconButton(
                  tooltip: t('Xoá', 'Delete'),
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
                      _buildTextField(_nameCtrl, t('Tên thuốc', 'Medicine Name'), Icons.medication, (v) => (v == null || v.trim().isEmpty) ? t('Vui lòng nhập tên thuốc', 'Please enter medicine name') : null),
                      _buildTextField(_dosageCtrl, t('Liều lượng', 'Dosage'), Icons.science_outlined, (v) => (v == null || v.trim().isEmpty) ? t('Vui lòng nhập liều lượng', 'Please enter dosage') : null, hint: t('ví dụ: 1 viên, 10ml', 'e.g., 1 pill, 10ml')),
                      _buildDropdown(_freqCodes, _freqCode, _freqLabel, (v) => setState(() => _freqCode = v ?? 'once'), t('Tần suất', 'Frequency'), Icons.repeat_on_outlined),
                      _buildDropdown(_typeCodes, _typeCode, _typeLabel, (v) => setState(() => _typeCode = v ?? 'pill'), t('Loại thuốc', 'Medicine Type'), Icons.category_outlined),

                      const SizedBox(height: 16),
                      Text(t('Thời gian uống', 'Intake Times'), style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),

                      _buildTimePickerField(_time1Ctrl, t('Giờ lần 1', 'Time #1')),
                      if (_freqCode == 'twice' || _freqCode == 'thrice')
                        _buildTimePickerField(_time2Ctrl, t('Giờ lần 2', 'Time #2')),
                      if (_freqCode == 'thrice')
                        _buildTimePickerField(_time3Ctrl, t('Giờ lần 3', 'Time #3')),

                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
                        onPressed: _loading ? null : _save,
                        icon: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_alt_outlined),
                        label: Text(_isEditing ? t('Cập nhật', 'Update') : t('Lưu', 'Save')),
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

  // Widget builder helpers
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String? Function(String?)? validator, {String? hint}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: validator,
    ),
  );

  Widget _buildDropdown(List<String> codes, String value, String Function(String) labelBuilder, void Function(String?) onChanged, String label, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: DropdownButtonFormField<String>(
      value: value,
      items: codes.map((c) => DropdownMenuItem(value: c, child: Text(labelBuilder(c)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    ),
  );

  Widget _buildTimePickerField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pick(controller),
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.access_time_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: (v) => (v == null || v.trim().isEmpty) ? t('Vui lòng chọn giờ', 'Please pick a time') : null,
    ),
  );

  String _freqLabel(String code) {
    return switch (code) {
      'once'   => t('1 lần/ngày', 'Once daily'),
      'twice'  => t('2 lần/ngày', 'Twice daily'),
      'thrice' => t('3 lần/ngày', '3 times daily'),
      _        => code
    };
  }

  String _typeLabel(String code) {
    return switch (code) {
      'pill'      => t('Viên nén', 'Pill'),
      'capsule'   => t('Viên nang', 'Capsule'),
      'syrup'     => t('Siro', 'Syrup'),
      'topical'   => t('Thuốc bôi', 'Topical'),
      'eyedrop'   => t('Thuốc nhỏ mắt', 'Eye drops'),
      'spray'     => t('Thuốc xịt', 'Spray'),
      'injection' => t('Thuốc tiêm', 'Injection'),
      _           => code
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
