import 'package:flutter/material.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';   // ⬅️ THÊM
import '../models/medicine.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine; // For editing existing medicine
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController = TextEditingController(); // luôn giữ dạng HH:mm
  final _notesController = TextEditingController();

  final MedicineService service = MedicineService();

  bool _isLoading = false;
  TimeOfDay? _selectedTime;
  String _selectedFrequency = 'Hàng ngày';
  String _selectedMedicineType = 'Viên nén';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _frequencies = [
    'Hàng ngày',
    '2 lần/ngày',
    '3 lần/ngày',
    'Khi cần thiết',
    'Tuần 3 lần'
  ];

  final List<String> _medicineTypes = [
    'Viên nén',
    'Viên nang',
    'Siro',
    'Thuốc bôi',
    'Thuốc nhỏ mắt',
    'Thuốc xịt',
    'Thuốc tiêm'
  ];

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (_isEditing) {
      _nameController.text = widget.medicine!.name;
      _dosageController.text = widget.medicine!.dosage;
      _timeController.text = widget.medicine!.time; // kỳ vọng HH:mm
      try {
        final parts = widget.medicine!.time.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              dayPeriodShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _toHHmm(picked); // luôn lưu HH:mm
      });
    }
  }

  // Quay về Home
  void _returnToHome(String result) {
    bool popped = false;
    try { Navigator.of(context).pop(result); popped = true; } catch (_) {}
    if (!popped) {
      try { Navigator.of(context, rootNavigator: true).pop(result); popped = true; } catch (_) {}
    }
    if (!popped) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // Helper: parse HH:mm an toàn
  ({int hour, int minute}) _parseHHmm(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 8;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Chuẩn hóa HH:mm
      var hhmm = _timeController.text.trim();
      final hm = _parseHHmm(hhmm);
      hhmm = '${hm.hour.toString().padLeft(2,'0')}:${hm.minute.toString().padLeft(2,'0')}';

      final medicine = Medicine(
        id: _isEditing ? widget.medicine!.id : null,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        time: hhmm,
        // notes/frequency/type nếu model có, bạn map thêm:
        // notes: _notesController.text.trim(),
        // frequency: _selectedFrequency,
        // type: _selectedMedicineType,
      );

      if (_isEditing) {
        // Hủy lịch cũ (nếu có id)
        if (medicine.id != null) {
          await NotificationService.instance.cancel(medicine.id!.hashCode);
        }

        await service.updateMedicine(medicine);

        // Đặt lịch mới (hằng ngày đúng giờ)
        await NotificationService.instance.scheduleDaily(
          id: medicine.id!.hashCode,
          title: 'Nhắc uống thuốc',
          body: '${medicine.name} - ${medicine.dosage}',
          hour: hm.hour,
          minute: hm.minute,
        );

        if (mounted) _returnToHome('updated');
      } else {
        // Thêm mới → nhận docId
        final docId = await service.addMedicine(medicine);

        await NotificationService.instance.scheduleDaily(
          id: docId.hashCode,
          title: 'Nhắc uống thuốc',
          body: '${medicine.name} - ${medicine.dosage}',
          hour: hm.hour,
          minute: hm.minute,
        );

        if (mounted) _returnToHome('added');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("Lỗi: $e")),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMedicine() async {
    if (!_isEditing || widget.medicine?.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text("Bạn có chắc muốn xoá '${widget.medicine!.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    try {
      // Hủy lịch noti trước
      await NotificationService.instance.cancel(widget.medicine!.id!.hashCode);
      await service.deleteMedicine(widget.medicine!.id!);
      if (mounted) _returnToHome('deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("Không thể xoá: $e")),
            ],
          ),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.green[700], size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          prefixIcon: Icon(icon, color: Colors.green[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[600]!, width: 2),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey[50] : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items
            .map((String item) =>
            DropdownMenuItem<String>(value: item, child: Text(item)))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Chỉnh sửa thuốc" : "Thêm thuốc mới"),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteMedicine,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green[50]!, Colors.white]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Thông tin cơ bản", Icons.info_outline),

                          _buildTextField(
                            controller: _nameController,
                            label: "Tên thuốc",
                            icon: Icons.medication,
                            validator: (value) => value == null || value.isEmpty ? "Vui lòng nhập tên thuốc" : null,
                          ),

                          _buildDropdown(
                            label: "Loại thuốc",
                            value: _selectedMedicineType,
                            items: _medicineTypes,
                            icon: Icons.category,
                            onChanged: (value) => setState(() => _selectedMedicineType = value!),
                          ),

                          _buildTextField(
                            controller: _dosageController,
                            label: "Liều lượng",
                            icon: Icons.straighten,
                            suffixText: "mg/ml",
                            validator: (value) => value == null || value.isEmpty ? "Vui lòng nhập liều lượng" : null,
                          ),

                          _buildSectionTitle("Thời gian uống thuốc", Icons.schedule),

                          _buildTextField(
                            controller: _timeController,
                            label: "Giờ uống thuốc (HH:mm)",
                            icon: Icons.access_time,
                            readOnly: true,
                            onTap: _selectTime,
                            validator: (value) => value == null || value.isEmpty ? "Vui lòng chọn giờ uống thuốc" : null,
                          ),

                          _buildDropdown(
                            label: "Tần suất",
                            value: _selectedFrequency,
                            items: _frequencies,
                            icon: Icons.repeat,
                            onChanged: (value) => setState(() => _selectedFrequency = value!),
                          ),

                          _buildSectionTitle("Ghi chú (Tùy chọn)", Icons.note_add),

                          _buildTextField(
                            controller: _notesController,
                            label: "Ghi chú thêm",
                            icon: Icons.notes,
                            keyboardType: TextInputType.multiline,
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveMedicine,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isEditing ? Icons.update : Icons.save),
                                  const SizedBox(width: 8),
                                  Text(isEditing ? "Cập nhật & đặt nhắc" : "Lưu & đặt nhắc",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
