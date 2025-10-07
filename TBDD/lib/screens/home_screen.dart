// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/medicine_service.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';
import '../services/dose_state_service.dart'; // lấy giờ 1-2-3
import 'add_medicine_screen.dart';

enum MedFilter { all, notTaken, taken }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MedicineService service = MedicineService();
  final AuthService _authService = AuthService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  MedFilter _filter = MedFilter.all;

  String t(String vi, String en) =>
      LanguageService.instance.isVietnamese.value ? vi : en;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleLanguage() {
    final ln = LanguageService.instance.isVietnamese;
    ln.value = !ln.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ln.value ? 'Đã chuyển sang Tiếng Việt' : 'Switched to English')),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  List<Medicine> _filterMedicines(List<Medicine> medicines) {
    List<Medicine> list = medicines;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((m) =>
      m.name.toLowerCase().contains(q) ||
          m.dosage.toLowerCase().contains(q) ||
          m.time.toLowerCase().contains(q))
          .toList();
    }

    switch (_filter) {
      case MedFilter.notTaken:
        return list.where((m) => !m.taken).toList();
      case MedFilter.taken:
        return list.where((m) => m.taken).toList();
      case MedFilter.all:
      default:
        return list;
    }
  }

  Future<bool> _confirmDelete(Medicine medicine) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(t('Xác nhận xóa', 'Confirm delete')),
          ],
        ),
        content: Text(t(
            "Bạn có chắc chắn muốn xóa '${medicine.name}' không?",
            "Are you sure you want to delete '${medicine.name}'?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Xóa', 'Delete')),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final id = medicine.id;
    if (id == null) return;
    try {
      await service.deleteMedicine(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t("Đã xóa '${medicine.name}'", "Deleted '${medicine.name}'"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t("Không thể xóa: $e", "Cannot delete: $e")),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (!mounted) return;
    if (result == 'added') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Lưu thành công', 'Saved successfully'))),
      );
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(t('Đăng xuất', 'Logout')),
        content:
        Text(t('Bạn có chắc chắn muốn đăng xuất?', 'Are you sure you want to log out?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('Hủy', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Đăng xuất', 'Logout')),
          ),
        ],
      ),
    ) ??
        false;

    if (ok) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildEmptyState() => FadeTransition(
    opacity: _fadeAnimation,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 60,
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(Icons.medication_outlined, size: 60, color: Color(0xFF93C5FD)),
          ),
          const SizedBox(height: 20),
          Text(t('Chưa có thuốc nào', 'No medicines yet'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(t('Hãy thêm thuốc đầu tiên của bạn!', 'Add your first medicine!'),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add),
            label: Text(t('Thêm thuốc mới', 'Add new medicine')),
          ),
        ],
      ),
    ),
  );

  int _countByFreq(String freqCode) {
    switch (freqCode) {
      case 'twice':
        return 2;
      case 'thrice':
        return 3;
      case 'once':
      default:
        return 1;
    }
  }

  Widget _buildMedicineCard(Medicine medicine, int index) {
    final start = min(index * 0.08, 0.8);
    final end = min(start + 0.5, 1.0);
    final slide = Tween<Offset>(begin: Offset(0, 0.15 * (index + 1)), end: Offset.zero).animate(
        CurvedAnimation(parent: _animationController, curve: Interval(start, end, curve: Curves.easeOut)));

    final count = _countByFreq(medicine.frequency);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: slide,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon trái
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),

                // Nội dung + per-occurrence checks
                Expanded(
                  child: (medicine.id == null)
                      ? _MedicineStaticInfo(
                    name: medicine.name,
                    dosage: medicine.dosage,
                    time: medicine.time,
                    allDone: medicine.taken,
                    t: t,
                  )
                      : StreamBuilder(
                    stream: service.watchMedicineDoc(medicine.id!),
                    builder: (context, snap) {
                      List<bool> takenToday = List<bool>.filled(count, false);
                      bool allDone = false;

                      if (snap.hasData && (snap.data as dynamic).exists) {
                        takenToday = service.getTodayArrayFromDoc(snap.data as dynamic, count);
                        allDone = takenToday.every((e) => e);
                      } else {
                        allDone = (count == 1) ? medicine.taken : false; // fallback
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tiêu đề + tích lớn nếu xong
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  medicine.name,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (allDone)
                                const Icon(Icons.verified, color: Colors.green, size: 20),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Liều lượng
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              medicine.dosage,
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🕓 Hiển thị giờ 1-2-3 (nếu có)
                          FutureBuilder<List<String>>(
                            future: medicine.id == null
                                ? Future.value([medicine.time])
                                : DoseStateService.instance.getSavedTimes(medicine.id!),
                            builder: (context, snap) {
                              final times =
                              (snap.data != null && snap.data!.isNotEmpty)
                                  ? snap.data!
                                  : [medicine.time];
                              final text = times.join(', ');
                              return Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      t("Uống lúc: $text", "Time: $text"),
                                      style:
                                      const TextStyle(color: Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // ✅ Hàng tích nhỏ theo số lần
                          Wrap(
                            spacing: 10,
                            children: List.generate(count, (i) {
                              final on = takenToday[i] == true;
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  if (medicine.id == null) return;
                                  try {
                                    final newVal = !on;
                                    // Tính thử xem sau khi đổi có hoàn thành hết không
                                    final nextArr = [...takenToday]..[i] = newVal;
                                    final willAllDone =
                                    nextArr.every((e) => e == true);

                                    await service.toggleTodayIntake(
                                      medId: medicine.id!,
                                      index: i,
                                      count: count,
                                      value: newVal,
                                    );

                                    // Nếu lần này vừa hoàn thành tất cả → huỷ follow-ups hôm nay
                                    if (willAllDone) {
                                      await NotificationService.instance
                                          .cancelTodayFollowUps(medicine.id!);
                                    }

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(newVal
                                            ? t('Đã uống lần ${i + 1}',
                                            'Marked dose ${i + 1}')
                                            : t('Bỏ tích lần ${i + 1}',
                                            'Unchecked dose ${i + 1}')),
                                        duration:
                                        const Duration(milliseconds: 900),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      on
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: on ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(t('Lần ${i + 1}', 'Dose ${i + 1}')),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Cột nút phải
                Column(
                  children: [
                    IconButton(
                      tooltip: t('Xoá', 'Delete'),
                      onPressed: () async {
                        final ok = await _confirmDelete(medicine);
                        if (ok) _deleteMedicine(medicine);
                      },
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                    ),
                    IconButton(
                      tooltip: t('Sửa', 'Edit'),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddMedicineScreen(medicine: medicine)),
                        );
                        if (!mounted) return;
                        if (result == 'updated') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    t('Đã cập nhật thuốc', 'Medicine updated'))),
                          );
                        } else if (result == 'deleted') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                Text(t('Đã xoá thuốc', 'Medicine deleted'))),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVI, _) {
        final title = t('Danh sách thuốc', 'Medicine List');

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header + tìm kiếm
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.medical_services,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                          // 🌞/🌚 Nút chỉnh sáng-tối
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: ThemeService.instance.mode,
                            builder: (context, mode, _) {
                              final isDark = mode == ThemeMode.dark ||
                                  (mode == ThemeMode.system &&
                                      MediaQuery.of(context).platformBrightness ==
                                          Brightness.dark);
                              return IconButton(
                                tooltip: t('Chế độ sáng/tối', 'Light/Dark mode'),
                                onPressed: () => ThemeService.instance.toggle(),
                                icon: Icon(isDark
                                    ? Icons.dark_mode
                                    : Icons.light_mode),
                              );
                            },
                          ),
                          // 🌐 Đổi ngôn ngữ
                          IconButton(
                            tooltip: t('Ngôn ngữ', 'Language'),
                            onPressed: _toggleLanguage,
                            icon: const Icon(Icons.language),
                          ),
                          // 🚪 Đăng xuất
                          IconButton(
                            tooltip: t('Đăng xuất', 'Logout'),
                            onPressed: _logout,
                            icon:
                            const Icon(Icons.logout, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Ô tìm kiếm
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: t('Tìm kiếm thuốc...', 'Search medicine...'),
                            prefixIcon: const Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách + bộ lọc trạng thái (có đếm)
                Expanded(
                  child: StreamBuilder<List<Medicine>>(
                    stream: service.getMedicines(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                t('Lỗi tải dữ liệu:\n', 'Failed to load:\n') +
                                    '${snapshot.error}',
                                textAlign: TextAlign.center));
                      }
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snapshot.data ?? [];

                      // 🧮 Đếm số đã uống / chưa uống để hiển thị lên chip
                      final takenCount =
                          data.where((m) => m.taken).length;
                      final notTakenCount = data.length - takenCount;

                      // Lọc theo từ khoá + bộ lọc trạng thái hiện tại
                      final filtered = _filterMedicines(data);

                      // Nếu CẢ DANH SÁCH trống hoàn toàn
                      if (data.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Có dữ liệu → hiển thị CHIP + LIST
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 🔘 Bộ lọc trạng thái + đếm
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ChoiceChip(
                                  label: Text(
                                      t('Tất cả', 'All') +
                                          ' (${data.length})'),
                                  selected: _filter == MedFilter.all,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.all),
                                ),
                                ChoiceChip(
                                  label: Text(
                                      t('Chưa uống', 'Not taken') +
                                          ' ($notTakenCount)'),
                                  selected: _filter == MedFilter.notTaken,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.notTaken),
                                ),
                                ChoiceChip(
                                  label: Text(
                                      t('Đã uống', 'Taken') +
                                          ' ($takenCount)'),
                                  selected: _filter == MedFilter.taken,
                                  onSelected: (_) => setState(
                                          () => _filter = MedFilter.taken),
                                ),
                              ],
                            ),
                          ),

                          // Kết quả sau khi lọc
                          if (filtered.isEmpty)
                            Expanded(
                              child: Center(
                                child: Text(
                                  t('Không có thuốc phù hợp với bộ lọc',
                                      'No medicines match the filter'),
                                  style:
                                  const TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final m = filtered[index];
                                  return Dismissible(
                                    key: ValueKey(
                                        'med_${m.id ?? m.name}_$index'),
                                    direction:
                                    DismissDirection.endToStart,
                                    confirmDismiss: (_) =>
                                        _confirmDelete(m),
                                    onDismissed: (_) =>
                                        _deleteMedicine(m),
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius:
                                          BorderRadius.circular(15)),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      child: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red),
                                    ),
                                    child: _buildMedicineCard(m, index),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAdd,
            icon: const Icon(Icons.add),
            label: Text(t('Thêm thuốc', 'Add medicine')),
          ),
        );
      },
    );
  }
}

// Widget nhỏ hiển thị tĩnh khi chưa có id
class _MedicineStaticInfo extends StatelessWidget {
  final String name;
  final String dosage;
  final String time;
  final bool allDone;
  final String Function(String, String) t;

  const _MedicineStaticInfo({
    required this.name,
    required this.dosage,
    required this.time,
    required this.allDone,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (allDone)
              const Icon(Icons.verified, color: Colors.green, size: 20),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            dosage,
            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(t("Uống lúc: $time", "Time: $time"),
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ],
    );
  }
}
