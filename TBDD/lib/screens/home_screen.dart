// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import 'add_medicine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Services
  final MedicineService service = MedicineService();
  final AuthService _authService = AuthService();

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // 🌐 Ngôn ngữ cục bộ cho HomeScreen
  bool _isVietnamese = true; // mặc định: Tiếng Việt

  // Helper chọn text theo ngôn ngữ
  String t(String vi, String en) => _isVietnamese ? vi : en;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
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

  // Toggle ngôn ngữ
  void _toggleLanguage() {
    setState(() => _isVietnamese = !_isVietnamese);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Đã chuyển sang Tiếng Việt', 'Switched to English')),
        duration: const Duration(seconds: 1),
      ),
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
    if (_searchQuery.isEmpty) return medicines;
    final q = _searchQuery.toLowerCase();
    return medicines.where((m) =>
    m.name.toLowerCase().contains(q) ||
        m.dosage.toLowerCase().contains(q) ||
        m.time.toLowerCase().contains(q)
    ).toList();
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
            "Are you sure you want to delete '${medicine.name}'?"
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Xóa', 'Delete')),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    final id = medicine.id;
    if (id == null) return;
    try {
      await service.deleteMedicine(id);
      // Hủy thông báo nếu bạn dùng docId.hashCode làm notification id
      await NotificationService.instance.cancel(id.hashCode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t("Đã xóa '${medicine.name}'", "Deleted '${medicine.name}'")))
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
        content: Text(t('Bạn có chắc chắn muốn đăng xuất?', 'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Đăng xuất', 'Logout')),
          ),
        ],
      ),
    ) ?? false;

    if (ok) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Bảng test notification
  void _openNotiTester() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(t('Test thông báo', 'Notification test')),
                subtitle: Text(t('Kiểm tra quyền & hiển thị', 'Check permissions & display')),
              ),
              ListTile(
                leading: const Icon(Icons.flash_on_outlined),
                title: Text(t('Hiện thông báo NGAY', 'Show NOW')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await NotificationService.instance.showNow(
                    id: 9001,
                    title: t('Thông báo test', 'Test notification'),
                    body: t('Hiển thị tức thì để kiểm tra quyền', 'Shown instantly to check permission'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(t('Đặt thông báo SAU 1 PHÚT', 'Schedule IN 1 MINUTE')),
                subtitle: Text(t('Dùng scheduleOnce để kiểm tra hẹn giờ', 'Use scheduleOnce to test scheduling')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final when = DateTime.now().add(const Duration(minutes: 1));
                  await NotificationService.instance.scheduleOnce(
                    id: 9002,
                    title: t('Thông báo test sau 1 phút', 'Test after 1 minute'),
                    body: t('Nếu thấy trong ~1 phút là OK', 'If you see it in ~1 minute it works'),
                    whenLocal: when,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('Đã hẹn: $when', 'Scheduled at: $when'))),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
          Text(
            t('Chưa có thuốc nào', 'No medicines yet'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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

  Widget _buildSearchEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off, size: 64, color: Colors.grey),
        const SizedBox(height: 10),
        Text(t('Không tìm thấy thuốc', 'No results')),
        const SizedBox(height: 6),
        Text(t('Thử từ khóa khác', 'Try another keyword'),
            style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildMedicineCard(Medicine medicine, int index) {
    final start = min(index * 0.08, 0.8);
    final end = min(start + 0.5, 1.0);
    final slide = Tween<Offset>(begin: Offset(0, 0.15 * (index + 1)), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Interval(start, end, curve: Curves.easeOut)));

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
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.medication, color: Colors.blue[800]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          medicine.dosage,
                          style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            t("Uống lúc: ${medicine.time}", "Time: ${medicine.time}"),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                          MaterialPageRoute(builder: (_) => AddMedicineScreen(medicine: medicine)),
                        );
                        if (!mounted) return;
                        if (result == 'updated') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('Đã cập nhật thuốc', 'Medicine updated'))),
                          );
                        } else if (result == 'deleted') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('Đã xoá thuốc', 'Medicine deleted'))),
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
    final title = t('Danh sách thuốc', 'Medicine List');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blue[50]!, Colors.white]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.medical_services, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                        IconButton(
                          tooltip: t('Thông báo', 'Notifications'),
                          onPressed: _openNotiTester,
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                        IconButton(
                          tooltip: t('Ngôn ngữ', 'Language'),
                          onPressed: _toggleLanguage,
                          icon: const Icon(Icons.language),
                        ),
                        IconButton(
                          tooltip: t('Đăng xuất', 'Logout'),
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: t('Tìm kiếm thuốc...', 'Search medicine...'),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: StreamBuilder<List<Medicine>>(
                  stream: service.getMedicines(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          t('Lỗi tải dữ liệu:\n', 'Failed to load:\n') + '${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filtered = _filterMedicines(snapshot.data!);
                    if (filtered.isEmpty) {
                      return _searchQuery.isNotEmpty ? _buildSearchEmpty() : _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final m = filtered[index];
                        return Dismissible(
                          key: ValueKey('med_${m.id ?? m.name}_$index'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(m),
                          onDismissed: (_) => _deleteMedicine(m),
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                          child: _buildMedicineCard(m, index),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
          );
          if (!mounted) return;
          if (result == 'added') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('Đã thêm thuốc', 'Medicine added'))),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(t('Thêm thuốc', 'Add medicine')),
      ),
    );
  }
}
