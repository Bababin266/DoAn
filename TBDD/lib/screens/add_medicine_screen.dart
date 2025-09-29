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

class _AddMedicineScreenState extends State<AddMedicineScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController   = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController   = TextEditingController(); // luôn HH:mm
  final _notesController  = TextEditingController();

  final MedicineService service = MedicineService();

  bool _isLoading = false;
  TimeOfDay? _selectedTime;
  String _selectedFrequency = 'Hàng ngày';
  String _selectedMedicineType = 'Viên nén';

  late AnimationController _ac;
  late Animation<double> _fade;

  final _frequencies = ['Hàng ngày','2 lần/ngày','3 lần/ngày','Khi cần thiết'];

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

    if (_isEditing) {
      _nameController.text   = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _timeController.text   = widget.medicine!.time; // HH:mm
      final p = widget.medicine!.time.split(':');
      if (p.length == 2) {
        _selectedTime = TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p[1]) ?? 0);
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

  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (t != null) setState(() { _selectedTime = t; _timeController.text = _toHHmm(t); });
  }

  ({int hour,int minute}) _parseHHmm(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 8;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (hour: h.clamp(0,23), minute: m.clamp(0,59));
  }

  Future<void> _scheduleByFrequency({
    required String notiIdBase,
    required String name,
    required String dosage,
    required String hhmm,
    required String frequency,
  }) async {
    final p = _parseHHmm(hhmm);
    final h0 = p.hour, m0 = p.minute;

    Future<void> setAt(int idx, int h, int m) async {
      await NotificationService.instance.scheduleDaily(
        id: (notiIdBase + '_$idx').hashCode,
        title: 'Nhắc uống thuốc',
        body: '$name - $dosage',
        hour: h, minute: m,
      );
    }

    switch (frequency) {
      case 'Hàng ngày':
        await setAt(0, h0, m0);
        break;
      case '2 lần/ngày':
        await setAt(0, h0, m0);
        await setAt(1, (h0 + 12) % 24, m0);
        break;
      case '3 lần/ngày':
        await setAt(0, h0, m0);
        await setAt(1, (h0 + 8) % 24, m0);
        await setAt(2, (h0 + 16) % 24, m0);
        break;
      case 'Khi cần thiết':
      // không lặp tự động
        break;
      default:
        await setAt(0, h0, m0);
    }
  }

  void _return(String result) {
    bool popped = false;
    try { Navigator.of(context).pop(result); popped = true; } catch (_) {}
    if (!popped) {
      try { Navigator.of(context, rootNavigator: true).pop(result); popped = true; } catch (_) {}
    }
    if (!popped) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      var hhmm = _timeController.text.trim();
      final hm = _parseHHmm(hhmm);
      hhmm = '${hm.hour.toString().padLeft(2,'0')}:${hm.minute.toString().padLeft(2,'0')}';

      final med = Medicine(
        id: _isEditing ? widget.medicine!.id : null,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        time: hhmm,
      );

      if (_isEditing) {
        // huỷ tối đa 3 lịch cũ (nếu có)
        for (var i=0;i<3;i++) {
          await NotificationService.instance.cancel((med.id! + '_$i').hashCode);
        }
        await service.updateMedicine(med);
        await _scheduleByFrequency(
          notiIdBase: med.id!, name: med.name, dosage: med.dosage,
          hhmm: hhmm, frequency: _selectedFrequency,
        );
        if (mounted) _return('updated');
      } else {
        final docId = await service.addMedicine(med);
        await _scheduleByFrequency(
          notiIdBase: docId, name: med.name, dosage: med.dosage,
          hhmm: hhmm, frequency: _selectedFrequency,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa thuốc' : 'Thêm thuốc mới'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : () async {
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
                for (var i=0;i<3;i++) {
                  await NotificationService.instance.cancel((widget.medicine!.id! + '_$i').hashCode);
                }
                await service.deleteMedicine(widget.medicine!.id!);
                if (mounted) _return('deleted');
              },
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
                decoration: const InputDecoration(labelText: 'Tên thuốc', prefixIcon: Icon(Icons.medication)),
                validator: (v)=> (v==null||v.isEmpty)?'Nhập tên thuốc':null,
              ),
              const SizedBox(height:12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText:'Liều lượng', prefixIcon: Icon(Icons.straighten), suffixText:'mg/ml'),
                validator: (v)=> (v==null||v.isEmpty)?'Nhập liều lượng':null,
              ),
              const SizedBox(height:12),
              TextFormField(
                controller: _timeController,
                readOnly: true,
                onTap: _pickTime,
                decoration: const InputDecoration(labelText:'Giờ uống (HH:mm)', prefixIcon: Icon(Icons.access_time)),
                validator: (v)=> (v==null||v.isEmpty)?'Chọn giờ':null,
              ),
              const SizedBox(height:12),
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                items: _frequencies.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                onChanged: (v)=> setState(()=> _selectedFrequency = v!),
                decoration: const InputDecoration(labelText:'Tần suất', prefixIcon: Icon(Icons.repeat)),
              ),
              const SizedBox(height:24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading?null:_save,
                  icon: Icon(_isEditing?Icons.update:Icons.save),
                  label: Text(_isEditing? 'Cập nhật & đặt nhắc':'Lưu & đặt nhắc'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
