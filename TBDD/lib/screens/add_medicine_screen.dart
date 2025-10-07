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
  final _nameCtrl   = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _time1Ctrl  = TextEditingController(); // HH:mm
  final _time2Ctrl  = TextEditingController(); // HH:mm
  final _time3Ctrl  = TextEditingController(); // HH:mm
  final _noteCtrl   = TextEditingController();

  final MedicineService _service = MedicineService();

  bool _loading = false;
  late final AnimationController _ac;
  late final Animation<double> _fade;

  static const List<String> _freqCodes = ['once', 'twice', 'thrice', 'prn'];
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
      _time1Ctrl.text  = m.time;

      _freqCode = _guessFreqCode(m.frequency);
      _typeCode = _guessTypeCode(m.type);

      // ✳️ Quan trọng: load times đã lưu nếu có
      _loadSavedTimesIfAny(m.id!);
    } else {
      final now = TimeOfDay.now();
      _time1Ctrl.text = _toHHmm(now);
    }

    _ac.forward();
  }

  Future<void> _loadSavedTimesIfAny(String medId) async {
    // Lấy times đã lưu (nếu người dùng từng đặt giờ #2/#3 khác)
    final saved = await DoseStateService.instance.getSavedTimes(medId);

    if (saved.isNotEmpty) {
      // saved[0] thường trùng time1 trong model, giữ value hiện tại
      if (saved.length >= 2) _time2Ctrl.text = saved[1];
      if (saved.length >= 3) _time3Ctrl.text = saved[2];
      setState(() {}); // cập nhật UI
      return;
    }

    // Không có dữ liệu đã lưu → chỉ khi đó mới auto gợi ý
    // để tránh ghi đè giờ người dùng đã đặt
    final hm1 = _parseHHmm(_time1Ctrl.text);
    if (_freqCode == 'twice' && _time2Ctrl.text.isEmpty) {
      _time2Ctrl.text = _toHHmm(TimeOfDay(hour: (hm1.hour + 12) % 24, minute: hm1.minute));
    }
    if (_freqCode == 'thrice' && _time2Ctrl.text.isEmpty && _time3Ctrl.text.isEmpty) {
      _time2Ctrl.text = _toHHmm(TimeOfDay(hour: (hm1.hour + 8) % 24, minute: hm1.minute));
      _time3Ctrl.text = _toHHmm(TimeOfDay(hour: (hm1.hour + 16) % 24, minute: hm1.minute));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ac.dispose();
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _time1Ctrl.dispose();
    _time2Ctrl.dispose();
    _time3Ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ===== Helpers =====
  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  ({int hour, int minute}) _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _pick(String which) async {
    final ctrl = switch (which) {
      't1' => _time1Ctrl,
      't2' => _time2Ctrl,
      _    => _time3Ctrl,
    };
    final seed = ctrl.text.isNotEmpty
        ? _parseHHmm(ctrl.text)
        : (which == 't1')
        ? _parseHHmm(_time1Ctrl.text)
        : (hour: TimeOfDay.now().hour, minute: TimeOfDay.now().minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: seed.hour, minute: seed.minute),
    );
    if (picked != null) {
      ctrl.text = _toHHmm(picked);
      setState(() {});
    }
  }

  String _freqLabel(String code) {
    switch (code) {
      case 'once':   return t('1 lần/ngày', 'Once daily');
      case 'twice':  return t('2 lần/ngày', 'Twice daily');
      case 'thrice': return t('3 lần/ngày', '3 times daily');
      case 'prn':    return t('Khi cần', 'As needed');
      default:       return code;
    }
  }

  String _typeLabel(String code) {
    switch (code) {
      case 'pill':      return t('Viên nén', 'Pill');
      case 'capsule':   return t('Viên nang', 'Capsule');
      case 'syrup':     return t('Siro', 'Syrup');
      case 'topical':   return t('Thuốc bôi', 'Topical');
      case 'eyedrop':   return t('Thuốc nhỏ mắt', 'Eye drops');
      case 'spray':     return t('Thuốc xịt', 'Spray');
      case 'injection': return t('Thuốc tiêm', 'Injection');
      default:          return code;
    }
  }

  String _guessFreqCode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'hàng ngày':
      case 'once':
      case 'once daily':
        return 'once';
      case '2 lần/ngày':
      case 'twice':
      case 'twice daily':
        return 'twice';
      case '3 lần/ngày':
      case 'thrice':
      case '3 times daily':
        return 'thrice';
      case 'khi cần':
      case 'prn':
      case 'as needed':
        return 'prn';
      default:
        return 'once';
    }
  }

  String _guessTypeCode(String raw) {
    final x = raw.trim().toLowerCase();
    if (['pill','viên nén'].contains(x)) return 'pill';
    if (['capsule','viên nang'].contains(x)) return 'capsule';
    if (['syrup','siro'].contains(x)) return 'syrup';
    if (['topical','thuốc bôi'].contains(x)) return 'topical';
    if (['eyedrop','eye drops','thuốc nhỏ mắt'].contains(x)) return 'eyedrop';
    if (['spray','thuốc xịt'].contains(x)) return 'spray';
    if (['injection','thuốc tiêm'].contains(x)) return 'injection';
    return 'pill';
  }

  List<String> _collectTimes() {
    final t1 = _time1Ctrl.text.trim();
    final times = <String>[];
    if (t1.isNotEmpty) times.add(t1);
    if (_freqCode == 'twice' || _freqCode == 'thrice') {
      if (_time2Ctrl.text.trim().isNotEmpty) times.add(_time2Ctrl.text.trim());
    }
    if (_freqCode == 'thrice') {
      if (_time3Ctrl.text.trim().isNotEmpty) times.add(_time3Ctrl.text.trim());
    }
    return times;
  }

  Future<void> _scheduleFor(
      String docId, String name, String dosage, List<String> hhmmList) async {
    for (var i = 0; i < hhmmList.length; i++) {
      final hm = _parseHHmm(hhmmList[i]);

      await NotificationService.instance.scheduleDaily(
        id: ('${docId}_$i').hashCode,
        title: t('Nhắc uống thuốc', 'Medicine reminder'),
        body: '$name - $dosage',
        hour: hm.hour,
        minute: hm.minute,
        payload: 'take:$docId:$i',
      );

      await NotificationService.instance.scheduleFollowUpsForOccurrence(
        medDocId: docId,
        baseHour: hm.hour,
        baseMinute: hm.minute,
        count: 10,
        intervalMinutes: 2,
        title: t('Nhắc lại uống thuốc', 'Reminder again'),
        body: '$name - $dosage',
        payload: 'take:$docId:$i',
      );
    }
  }

  Future<void> _cancelToday(String docId) async {
    for (int i = 0; i < 3; i++) {
      await NotificationService.instance.cancel(('${docId}_$i').hashCode);
    }
    await NotificationService.instance.cancelTodayFollowUps(docId);
  }

  void _popResult(String result) {
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_freqCode == 'twice' && _time2Ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Hãy chọn giờ lần 2', 'Please set time #2'))),
      );
      return;
    }
    if (_freqCode == 'thrice' &&
        (_time2Ctrl.text.trim().isEmpty || _time3Ctrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Hãy chọn đủ giờ lần 2 và 3', 'Please set both time #2 and #3'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final hm1 = _parseHHmm(_time1Ctrl.text.trim());
      final time1 = '${hm1.hour.toString().padLeft(2,'0')}:${hm1.minute.toString().padLeft(2,'0')}';

      final med = Medicine(
        id: _isEditing ? widget.medicine!.id : null,
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        time: time1,
        type: _typeCode,
        frequency: _freqCode,
        taken: false,
      );

      final times = _collectTimes();

      if (_isEditing) {
        final id = med.id!;
        await _cancelToday(id);
        await _service.updateMedicine(med);

        // LƯU count + times để lần sau mở sửa sẽ giữ nguyên
        await DoseStateService.instance.saveCount(id, times.length);
        await DoseStateService.instance.saveTimes(id, times);

        await _scheduleFor(id, med.name, med.dosage, times);
        _popResult('updated');
      } else {
        final id = await _service.addMedicine(med);

        await DoseStateService.instance.saveCount(id, times.length);
        await DoseStateService.instance.saveTimes(id, times);

        await _scheduleFor(id, med.name, med.dosage, times);
        _popResult('added');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing || widget.medicine?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Xác nhận xoá', 'Confirm delete')),
        content: Text(t("Xoá '${widget.medicine!.name}'?", "Delete '${widget.medicine!.name}'?")),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: Text(t('Huỷ','Cancel'))),
          ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: Text(t('Xoá','Delete'))),
        ],
      ),
    ) ?? false;
    if (!ok) return;

    try {
      final id = widget.medicine!.id!;
      await _cancelToday(id);
      await _service.deleteMedicine(id);
      _popResult('deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVI, _) {
        final title = _isEditing
            ? t('Chỉnh sửa thuốc','Edit medicine')
            : t('Thêm thuốc mới','Add medicine');

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (_isEditing)
                IconButton(
                  tooltip: t('Xoá','Delete'),
                  onPressed: _loading ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: t('Tên thuốc','Medicine name'),
                        prefixIcon: const Icon(Icons.medication),
                      ),
                      validator: (v)=> (v==null||v.trim().isEmpty)
                          ? t('Nhập tên thuốc','Enter medicine name') : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _dosageCtrl,
                      decoration: InputDecoration(
                        labelText: t('Liều lượng','Dosage'),
                        prefixIcon: const Icon(Icons.straighten),
                        suffixText: 'mg / ml',
                      ),
                      validator: (v)=> (v==null||v.trim().isEmpty)
                          ? t('Nhập liều lượng','Enter dosage') : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _freqCode,
                      items: _freqCodes
                          .map((c)=>DropdownMenuItem(value:c,child:Text(_freqLabel(c))))
                          .toList(),
                      onChanged: (v)=> setState(()=> _freqCode = v ?? 'once'),
                      decoration: InputDecoration(
                        labelText: t('Tần suất','Frequency'),
                        prefixIcon: const Icon(Icons.repeat),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _typeCode,
                      items: _typeCodes
                          .map((c)=>DropdownMenuItem(value:c,child:Text(_typeLabel(c))))
                          .toList(),
                      onChanged: (v)=> setState(()=> _typeCode = v ?? 'pill'),
                      decoration: InputDecoration(
                        labelText: t('Loại thuốc','Type'),
                        prefixIcon: const Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _time1Ctrl,
                      readOnly: true,
                      onTap: ()=>_pick('t1'),
                      decoration: InputDecoration(
                        labelText: t('Giờ lần 1 (HH:mm)','Time #1 (HH:mm)'),
                        prefixIcon: const Icon(Icons.access_time),
                      ),
                      validator: (v)=> (v==null||v.trim().isEmpty)
                          ? t('Chọn giờ lần 1','Pick time #1') : null,
                    ),
                    const SizedBox(height: 12),

                    if (_freqCode == 'twice' || _freqCode == 'thrice') ...[
                      TextFormField(
                        controller: _time2Ctrl,
                        readOnly: true,
                        onTap: ()=>_pick('t2'),
                        decoration: InputDecoration(
                          labelText: t('Giờ lần 2 (HH:mm)','Time #2 (HH:mm)'),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        validator: (v) {
                          if (_freqCode == 'twice' || _freqCode == 'thrice') {
                            if (v==null || v.trim().isEmpty) {
                              return t('Chọn giờ lần 2','Pick time #2');
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_freqCode == 'thrice') ...[
                      TextFormField(
                        controller: _time3Ctrl,
                        readOnly: true,
                        onTap: ()=>_pick('t3'),
                        decoration: InputDecoration(
                          labelText: t('Giờ lần 3 (HH:mm)','Time #3 (HH:mm)'),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        validator: (v) {
                          if (_freqCode == 'thrice') {
                            if (v==null || v.trim().isEmpty) {
                              return t('Chọn giờ lần 3','Pick time #3');
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _save,
                        icon: Icon(_isEditing ? Icons.update : Icons.save),
                        label: Text(_isEditing
                            ? t('Cập nhật & đặt nhắc','Update & schedule')
                            : t('Lưu & đặt nhắc','Save & schedule')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
