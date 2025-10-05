import 'package:flutter/material.dart';
import '../services/medicine_service.dart';

class TakeMedicineScreen extends StatefulWidget {
  const TakeMedicineScreen({super.key});

  @override
  State<TakeMedicineScreen> createState() => _TakeMedicineScreenState();
}

class _TakeMedicineScreenState extends State<TakeMedicineScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final String? medicineId = (args is String) ? args : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đã uống')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication, size: 64, color: Colors.teal),
              const SizedBox(height: 12),
              Text(
                medicineId == null
                    ? 'Không tìm thấy thuốc'
                    : 'Đánh dấu “đã uống” cho thuốc có ID:\n$medicineId',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Đang lưu...' : 'Đã uống'),
                onPressed: (medicineId == null || _saving)
                    ? null
                    : () async {
                  setState(() => _saving = true);
                  try {
                    // Cập nhật cờ taken = true
                    await MedicineService().setTaken(medicineId, true);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đánh dấu “đã uống”')),
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                    );
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
