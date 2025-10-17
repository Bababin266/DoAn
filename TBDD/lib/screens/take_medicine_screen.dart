// lib/screens/take_medicine_screen.dart
import 'package:flutter/material.dart';import '../models/medicine.dart';
import '../services/language_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';

class TakeMedicineScreen extends StatefulWidget {
  const TakeMedicineScreen({super.key});

  @override
  State<TakeMedicineScreen> createState() => _TakeMedicineScreenState();
}

class _TakeMedicineScreenState extends State<TakeMedicineScreen> {
  final MedicineService _service = MedicineService();
  bool _busy = false;
  String? _medId;
  Medicine? _medicine;

  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  // ✅ HÀM MỚI: Helper để lấy count từ frequency
  int _countByFreq(String freqCode) {
    switch (freqCode) {
      case 'twice':
        return 2;
      case 'thrice':
        return 3;
      default:
        return 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && _medId == null) {
      _medId = arg;
      _loadMedicineInfo();
    }
  }

  Future<void> _loadMedicineInfo() async {
    if (_medId == null) return;
    try {
      final doc = await _service.watchMedicineDoc(_medId!).first;
      if (doc.exists && mounted) {
        setState(() {
          _medicine = Medicine.fromMap(doc.data()!, id: doc.id);
        });
      }
    } catch (e) {
      // Bỏ qua lỗi ở đây
    }
  }

  Future<void> _markTaken() async {
    if (_medId == null || _busy) return;
    setState(() => _busy = true);

    try {
      final doc = await _service.watchMedicineDoc(_medId!).first;
      if (!doc.exists) {
        throw Exception(t('Thuốc không còn tồn tại.', 'Medicine no longer exists.'));
      }
      final medicineData = Medicine.fromMap(doc.data()!, id: doc.id);

      // ✅ SỬA LỖI TẠI ĐÂY: Lấy count từ tần suất của thuốc
      final count = _countByFreq(medicineData.frequency);

      // Lấy mảng trạng thái các liều đã uống trong ngày
      final takenArray = _service.getTodayArrayFromDoc(doc, count);

      // Tìm liều đầu tiên chưa được uống
      final firstUnTakenIndex = takenArray.indexWhere((taken) => !taken);

      if (firstUnTakenIndex == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('Tất cả các liều hôm nay đã được uống!', 'All doses for today have been taken!'))),
          );
        }
      } else {
        // Đánh dấu liều đó là đã uống
        // Dùng hàm có sẵn trong extension để đảm bảo logic nhất quán
        await _service.markDoseAsTakenById(_medId!, firstUnTakenIndex);

        // Huỷ các thông báo nhắc lại trong ngày (nếu có)
        // Dòng sửa lỗi
        await NotificationService.instance.cancelRemindersForDose(_medId!, firstUnTakenIndex);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t('Đã xác nhận uống', 'Confirmed dose for')} ${medicineData.name}')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, 'taken');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('Lỗi', 'Error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVietnamese, _) {
        final title = _medId == null
            ? t('Xác nhận', 'Confirm')
            : t('Xác nhận uống thuốc', 'Confirm Dose');

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.medication_outlined, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  if (_medicine != null)
                    Text(
                      _medicine!.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _medId == null
                        ? t('Thiếu thông tin thuốc', 'Missing medicine information')
                        : t('Bạn đã uống liều thuốc này chưa? Nhấn để xác nhận liều tiếp theo.', 'Have you taken this dose? Press to confirm the next dose.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: _busy ? null : _markTaken,
                    icon: _busy
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                    label: Text(t('Đã uống', 'Mark as Taken')),
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
