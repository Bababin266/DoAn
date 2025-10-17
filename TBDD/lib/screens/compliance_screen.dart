// lib/screens/compliance_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../services/medicine_service.dart';
import '../services/language_service.dart';
import '../models/compliance_data.dart'; // Sẽ tạo file này ở bước tiếp theo

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  final MedicineService _medicineService = MedicineService();
  final PageController _pageController = PageController();

  // Dữ liệu tuân thủ cho biểu đồ
  final Map<int, double> _weeklyCompliance = {};
  bool _isLoadingChart = true;

  // Dữ liệu cho lịch
  final Map<DateTime, List<ComplianceData>> _complianceEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoadingCalendar = true;

  String t(String vi, String en) => LanguageService.instance.isVietnamese.value ? vi : en;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
    _fetchCalendarDataForMonth(_focusedDay);
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoadingChart = true);
    final now = DateTime.now();
    // Lấy dữ liệu 7 ngày qua
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final compliance = await _medicineService.getComplianceForDay(day);
      // Dùng timestamp làm key để đảm bảo không bị trùng lặp
      _weeklyCompliance[day.millisecondsSinceEpoch] = compliance;
    }
    if (mounted) {
      setState(() => _isLoadingChart = false);
    }
  }

  Future<void> _fetchCalendarDataForMonth(DateTime month) async {
    setState(() => _isLoadingCalendar = true);
    final data = await _medicineService.getComplianceForMonth(month);
    _complianceEvents.clear();
    _complianceEvents.addAll(data);

    if (mounted) {
      setState(() => _isLoadingCalendar = false);
    }
  }

  List<ComplianceData> _getEventsForDay(DateTime day) {
    // `isSameDay` từ table_calendar rất quan trọng để so sánh ngày mà không tính đến giờ
    return _complianceEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageService.instance.isVietnamese,
      builder: (context, isVietnamese, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Thống kê Tuân thủ', 'Compliance Statistics')),
          ),
          body: PageView(
            controller: _pageController,
            children: [
              _buildChartView(isVietnamese),
              _buildCalendarView(isVietnamese),
            ],
          ),
        );
      },
    );
  }

  // Giao diện Biểu đồ
  Widget _buildChartView(bool isVietnamese) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Tuân thủ trong 7 ngày qua', 'Compliance Over Last 7 Days'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _isLoadingChart
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(
            height: 250,
            child: BarChart(_buildBarChartData(isVietnamese)),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: Text(t('Xem Lịch sử Chi tiết', 'View Full History')),
              onPressed: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // Giao diện Lịch
  Widget _buildCalendarView(bool isVietnamese) {
    return Column(
      children: [
        TableCalendar<ComplianceData>(
          locale: isVietnamese ? 'vi_VN' : 'en_US',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _fetchCalendarDataForMonth(focusedDay);
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final compliance = events.first.compliance; // Chỉ cần 1 event để lấy màu
              Color markerColor;
              if (compliance >= 1.0) {
                markerColor = Colors.green; // 100%
              } else if (compliance > 0.5) {
                markerColor = Colors.orange; // >50%
              } else {
                markerColor = Colors.red; // <=50%
              }
              return Positioned(
                bottom: 1,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: markerColor,
                  ),
                ),
              );
            },
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
        const Divider(),
        Expanded(
          child: _isLoadingCalendar
              ? const Center(child: CircularProgressIndicator())
              : _buildEventList(),
        ),
      ],
    );
  }

  // Danh sách ghi chú chi tiết khi chọn 1 ngày trên lịch
  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay);
    if (events.isEmpty) {
      return Center(
        child: Text(t('Không có dữ liệu cho ngày này', 'No data for this day')),
      );
    }
    final data = events.first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t('Chi tiết ngày ', 'Details for ') + DateFormat.yMd(LanguageService.instance.isVietnamese.value ? 'vi_VN' : 'en_US').format(_selectedDay),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(t('Liều đã uống', 'Doses Taken')),
          trailing: Text('${data.dosesTaken}', style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red),
          title: Text(t('Liều đã bỏ lỡ', 'Doses Missed')),
          trailing: Text('${data.dosesMissed}', style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.pie_chart, color: Colors.blue),
          title: Text(t('Tỷ lệ tuân thủ', 'Compliance Rate')),
          trailing: Text('${(data.compliance * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Tính toán dữ liệu tổng hợp
  Widget _buildSummaryCard() {
    if (_weeklyCompliance.isEmpty) return const SizedBox.shrink();
    final totalDoses = _weeklyCompliance.length; // Giả sử 1 liều/ngày
    final takenDoses = _weeklyCompliance.values.where((c) => c > 0).length;
    final average = (takenDoses / totalDoses * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(t('Tổng liều', 'Total Doses'), style: const TextStyle(color: Colors.grey)),
                Text('$totalDoses', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            Column(
              children: [
                Text(t('Đã uống', 'Taken'), style: const TextStyle(color: Colors.grey)),
                Text('$takenDoses', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green)),
              ],
            ),
            Column(
              children: [
                Text(t('Trung bình', 'Average'), style: const TextStyle(color: Colors.grey)),
                Text('$average%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Hàm tạo dữ liệu cho BarChart
  BarChartData _buildBarChartData(bool isVietnamese) {
    final sortedEntries = _weeklyCompliance.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final day = DateTime.fromMillisecondsSinceEpoch(sortedEntries[groupIndex].key);
            final dayOfWeek = DateFormat.E(isVietnamese ? 'vi_VN' : 'en_US').format(day);
            final compliance = (rod.toY * 100).toStringAsFixed(0);
            return BarTooltipItem(
              '$dayOfWeek\n$compliance%',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final day = DateTime.fromMillisecondsSinceEpoch(sortedEntries[value.toInt()].key);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat.E(isVietnamese ? 'vi_VN' : 'en_US').format(day).substring(0,1)),
              );
            },
            reservedSize: 28,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const Text('0%');
              if (value == 0.5) return const Text('50%');
              if (value == 1) return const Text('100%');
              return const Text('');
            },
            reservedSize: 32,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: sortedEntries.asMap().entries.map((entry) {
        final index = entry.key;
        final compliance = entry.value.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: compliance,
              color: compliance >= 0.9 ? Colors.green : (compliance > 0.5 ? Colors.orange : Colors.red),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5, dashArray: [5, 5]);
          }
      ),
    );
  }
}
