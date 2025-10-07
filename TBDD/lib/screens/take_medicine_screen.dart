// lib/screens/take_medicine_screen.dart
import 'package:flutter/material.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // nhận docId từ payload 'take:<docId>'
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) _medId = arg;
  }

  Future<void> _markTaken() async {
    if (_medId == null || _busy) return;
    setState(() => _busy = true);
    try {
      // 1) Đánh dấu đã uống
      await _service.setTaken(_medId!, true);

      // 2) HỦY TẤT CẢ follow-ups trong NGÀY HÔM NAY (mọi mốc)
      await NotificationService.instance.cancelTodayFollowUps(_medId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu đã uống & dừng nhắc hôm nay')),
      );
      Navigator.pop(context, 'taken');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _medId == null ? 'Xác nhận' : 'Xác nhận uống thuốc';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication, size: 64),
              const SizedBox(height: 12),
              Text(
                _medId == null
                    ? 'Thiếu thông tin thuốc'
                    : 'Bạn đã uống thuốc này chưa?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _busy ? null : _markTaken,
                icon: const Icon(Icons.check_circle),
                label: const Text('Đã uống'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
