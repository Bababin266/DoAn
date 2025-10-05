// lib/screens/add_medicine_screen.dart
import 'package:flutter/material.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../models/medicine.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController   = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController   = TextEditingController(); // luôn dạng HH:mm
  final _notesController  = TextEditingController(); // (nếu bạn thêm vào model thì map)

  final MedicineService service = MedicineService();

  bool _isLoading = false;
  TimeOfDay? _selectedTime;
  String _selectedFrequency = 'Hàng ngày';
  String _selectedMedicineType = 'Viên nén'; // nếu bạn dùng vào model

  late AnimationController _ac;
  late Animation<double> _fade;

  final _frequencies = <String>[
    'Hàng ngày',
    '2 lần/ngày',
    '3 lần/ngày',
    'Khi cần thiết',
  ];

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

    // Prefill khi sửa
    if (_isEditing) {
      _nameController.text   = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _timeController.text   = widget.medicine!.time; // kỳ vọng HH:mm
      _selectedFrequency     = widget.medicine!.frequency;
      _selectedMedicineType  = widget.medicine!.type;

      final p = widget.medicine!.time.split(':');
      if (p.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(p[0]) ?? 8,
          minute: int.tryParse(p[1]) ?? 0,
        );
      }
    }

    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ================== Helpers ==================

  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (t != null) {
      setState(() {
        _selectedTime = t;
        _timeController.text = _toHHmm(t); // chuẩn HH:mm
      });
    }
  }

  ({int hour, int minute}) _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  /// Tạo danh sách mốc giờ (h, m) theo tần suất, bắt đầu từ hh:mm.
  List<({int h, int m})> _timesFromFrequency(String hhmm, String frequency) {
    final base = _parseHHmm(hhmm);
    final h0 = base.hour, m0 = base.minute;

    switch (frequency) {
      case '2 lần/ngày':
        return [
          (h: h0, m: m0),
          (h: (h0 + 12) % 24, m: m0),
        ];
      case '3 lần/ngày':
        return [
          (h: h0, m: m0),
          (h: (h0 + 8) % 24, m: m0),
          (h: (h0 + 16) % 24, m: m0),
        ];
      case 'Hàng ngày':
        return [(h: h0, m: m0)];
      case 'Khi cần thiết':
      default:
        return [(h: h0, m: m0)]; // không lặp thêm mốc, nhưng vẫn có mốc chính
    }
  }

  /// Đặt lịch theo danh sách mốc giờ: lịch chính + follow-up 2 phút x10.
  Future<void> _scheduleAllForDoc({
    required String docId,
    required String name,
    required String dosage,
    required String hhmm,
    required String frequency,
  }) async {
    final times = _timesFromFrequency(hhmm, frequency);

    for (int i = 0; i < times.length; i++) {
      final h = times[i].h, m = times[i].m;

      // 1) Lịch hằng ngày (noti chính)
      await NotificationService.instance.scheduleDaily(
        id: (docId + '_$i').hashCode,
        title: 'Nhắc uống thuốc',
        body: '$name - $dosage',
        hour: h,
        minute: m,
        payload: 'take:$docId',
      );

      // 2) Follow-up: mỗi 2 phút, tối đa 10 lần kể từ giờ chính của NGÀY HIỆN TẠI
      await NotificationService.instance.scheduleFollowUpsForOccurrence(
        medDocId: docId,
        baseHour: h,
        baseMinute: m,
        count: 10,
        intervalMinutes: 2,
        title: 'Nhắc lại uống thuốc',
        body: '$name - $dosage',
        payload: 'take:$docId',
      );
    }
  }

  /// Huỷ các lịch hằng ngày cũ (tối đa 3 mốc) + huỷ follow-up của HÔM NAY.
  Future<void> _cancelOldSchedulesToday(String docId) async {
    for (int i = 0; i < 3; i++) {
      await NotificationService.instance.cancel((docId + '_$i').hashCode);
    }
    await NotificationService.instance.cancelTodayFollowUps(docId);
  }

  void _return(String result) {
    bool popped = false;
    try { Navigator.of(context).pop(result); popped = true; } catch (_) {}
    if (!popped) {
      try { Navigator.of(context, rootNavigator: true).pop(result); popped = true; } catch (_) {}
    }
    if (!popped) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ================== Save / Delete ==================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Chuẩn hoá HH:mm
      var hhmm = _timeController.text.trim();
      final hm = _parseHHmm(hhmm);
      hhmm = '${hm.hour.toString().padLeft(2, '0')}:${hm.minute.toString().padLeft(2, '0')}';

      final med = Medicine(
        id: _isEditing ? widget.medicine!.id : null,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        time: hhmm,
        type: _selectedMedicineType,
        frequency: _selectedFrequency,
        taken: false, // khi lưu/sửa thì reset về chưa uống cho lần tới
      );

      if (_isEditing) {
        final docId = med.id!;
        // Huỷ lịch cũ của hôm nay (cả chính & follow-up)
        await _cancelOldSchedulesToday(docId);

        // Cập nhật DB
        await service.updateMedicine(med);

        // Đặt lại lịch theo giờ & tần suất mới
        await _scheduleAllForDoc(
          docId: docId,
          name: med.name,
          dosage: med.dosage,
          hhmm: hhmm,
          frequency: med.frequency,
        );

        if (mounted) _return('updated');
      } else {
        // Thêm mới -> lấy docId
        final docId = await service.addMedicine(med);

        // Đặt lịch cho docId mới
        await _scheduleAllForDoc(
          docId: docId,
          name: med.name,
          dosage: med.dosage,
          hhmm: hhmm,
          frequency: med.frequency,
        );

        if (mounted) _return('added');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCurrent() async {
    if (!_isEditing || widget.medicine?.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text("Xoá '${widget.medicine!.name}'?"),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Xoá')),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    try {
      final docId = widget.medicine!.id!;
      await _cancelOldSchedulesToday(docId);
      await service.deleteMedicine(docId);
      if (mounted) _return('deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xoá: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa thuốc' : 'Thêm thuốc mới'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteCurrent,
              tooltip: 'Xoá',
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên thuốc', prefixIcon: Icon(Icons.medication),
                ),
                validator: (v)=> (v==null||v.trim().isEmpty)?'Nhập tên thuốc':null,
              ),
              const SizedBox(height:12),

              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText:'Liều lượng', prefixIcon: Icon(Icons.straighten), suffixText:'mg/ml',
                ),
                validator: (v)=> (v==null||v.trim().isEmpty)?'Nhập liều lượng':null,
              ),
              const SizedBox(height:12),

              TextFormField(
                controller: _timeController,
                readOnly: true,
                onTap: _pickTime,
                decoration: const InputDecoration(
                  labelText:'Giờ uống (HH:mm)', prefixIcon: Icon(Icons.access_time),
                ),
                validator: (v)=> (v==null||v.trim().isEmpty)?'Chọn giờ':null,
              ),
              const SizedBox(height:12),

              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                items: _frequencies
                    .map((e)=>DropdownMenuItem(value:e,child:Text(e)))
                    .toList(),
                onChanged: (v)=> setState(()=> _selectedFrequency = v ?? 'Hàng ngày'),
                decoration: const InputDecoration(
                  labelText:'Tần suất', prefixIcon: Icon(Icons.repeat),
                ),
              ),
              const SizedBox(height:12),

              // Nếu dùng type trong model:
              DropdownButtonFormField<String>(
                value: _selectedMedicineType,
                items: const [
                  DropdownMenuItem(value:'Viên nén', child: Text('Viên nén')),
                  DropdownMenuItem(value:'Viên nang', child: Text('Viên nang')),
                  DropdownMenuItem(value:'Siro', child: Text('Siro')),
                  DropdownMenuItem(value:'Thuốc bôi', child: Text('Thuốc bôi')),
                  DropdownMenuItem(value:'Thuốc nhỏ mắt', child: Text('Thuốc nhỏ mắt')),
                  DropdownMenuItem(value:'Thuốc xịt', child: Text('Thuốc xịt')),
                  DropdownMenuItem(value:'Thuốc tiêm', child: Text('Thuốc tiêm')),
                ],
                onChanged: (v)=> setState(()=> _selectedMedicineType = v ?? 'Viên nén'),
                decoration: const InputDecoration(
                  labelText:'Loại thuốc', prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height:24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading? null : _save,
                  icon: Icon(isEditing? Icons.update : Icons.save),
                  label: Text(isEditing? 'Cập nhật & đặt nhắc' : 'Lưu & đặt nhắc'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
