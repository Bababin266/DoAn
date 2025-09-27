import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../services/medicine_service.dart';
import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart'; // ⬅️ THÊM
import 'add_medicine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final MedicineService service = MedicineService();
  final AuthService _authService = AuthService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
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
    return medicines
        .where((m) =>
    m.name.toLowerCase().contains(q) ||
        m.dosage.toLowerCase().contains(q) ||
        m.time.toLowerCase().contains(q))
        .toList();
  }

  Future<bool> _confirmDelete(Medicine medicine) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text("Xác nhận xóa"),
          ],
        ),
        content:
        Text("Bạn có chắc chắn muốn xóa '${medicine.name}' không?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Xóa"),
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

      // ⬅️ HỦY luôn thông báo (nếu bạn dùng docId.hashCode làm id noti)
      await NotificationService.instance.cancel(id.hashCode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã xóa '${medicine.name}'")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Không thể xóa: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (result == 'added') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu thành công')),
      );
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc chắn muốn đăng xuất?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Đăng xuất"),
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

  // ⬅️ Bảng test thông báo mở từ nút "chuông"
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
              const ListTile(
                leading: Icon(Icons.notifications_active_outlined),
                title: Text('Test thông báo'),
                subtitle: Text('Dùng để kiểm tra quyền & hiển thị'),
              ),
              ListTile(
                leading: const Icon(Icons.flash_on_outlined),
                title: const Text('Hiện thông báo NGAY'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await NotificationService.instance.showNow(
                    id: 9001,
                    title: 'Thông báo test',
                    body: 'Hiển thị tức thì để kiểm tra quyền',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Đặt thông báo SAU 1 PHÚT'),
                subtitle: const Text('Dùng scheduleOnce để kiểm tra hẹn giờ'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final when = DateTime.now().add(const Duration(minutes: 1));
                  await NotificationService.instance.scheduleOnce(
                    id: 9002,
                    title: 'Thông báo test sau 1 phút',
                    body: 'Nếu thấy thông báo ~1 phút nữa là OK',
                    whenLocal: when,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã hẹn: ${when.toLocal()}'),
                    ),
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
            child: Icon(Icons.medication_outlined,
                size: 60, color: Color(0xFF93C5FD)),
          ),
          const SizedBox(height: 20),
          const Text("Chưa có thuốc nào",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text("Hãy thêm thuốc đầu tiên của bạn!",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddMedicineScreen()),
              );
              if (!mounted) return;
              if (result == 'added') {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã thêm thuốc')));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("Thêm thuốc mới"),
          ),
        ],
      ),
    ),
  );

  Widget _buildSearchEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.search_off, size: 64, color: Colors.grey),
        SizedBox(height: 10),
        Text("Không tìm thấy thuốc"),
        SizedBox(height: 6),
        Text("Thử từ khóa khác", style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildMedicineCard(Medicine medicine, int index) {
    final start = min(index * 0.08, 0.8);
    final end = min(start + 0.5, 1.0);
    final slide = Tween<Offset>(
        begin: Offset(0, 0.15 * (index + 1)), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(start, end, curve: Curves.easeOut)));

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: slide,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication, color: Colors.blue[800]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(medicine.dosage,
                            style: TextStyle(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text("Uống lúc: ${medicine.time}",
                              style:
                              const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Xoá',
                      onPressed: () async {
                        final ok = await _confirmDelete(medicine);
                        if (ok) _deleteMedicine(medicine);
                      },
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                    ),
                    IconButton(
                      tooltip: 'Sửa',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddMedicineScreen(medicine: medicine)),
                        );
                        if (!mounted) return;
                        if (result == 'updated') {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Đã cập nhật thuốc')));
                        } else if (result == 'deleted') {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã xoá thuốc')));
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[50]!, Colors.white]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar + Search
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.medical_services,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text("Danh sách thuốc",
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          tooltip: 'Thông báo',
                          onPressed: _openNotiTester, // ⬅️ MỞ TESTER
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                        IconButton(
                          tooltip: 'Đăng xuất',
                          onPressed: _logout,
                          icon:
                          const Icon(Icons.logout, color: Colors.red),
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
                        decoration: const InputDecoration(
                          hintText: "Tìm kiếm thuốc...",
                          prefixIcon:
                          Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                              'Lỗi tải dữ liệu:\n${snapshot.error}',
                              textAlign: TextAlign.center));
                    }
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final filtered = _filterMedicines(snapshot.data!);
                    if (filtered.isEmpty) {
                      return _searchQuery.isNotEmpty
                          ? _buildSearchEmpty()
                          : _buildEmptyState();
                    }

                    return ListView.builder(
                      padding:
                      const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final m = filtered[index];
                        return Dismissible(
                          key: ValueKey('med_${m.id ?? m.name}_$index'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(m),
                          onDismissed: (_) => _deleteMedicine(m),
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(15)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.red),
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
            context,
            MaterialPageRoute(
                builder: (_) => const AddMedicineScreen()),
          );
          if (!mounted) return;
          if (result == 'added') {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã thêm thuốc')));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Thêm thuốc"),
      ),
    );
  }
}
