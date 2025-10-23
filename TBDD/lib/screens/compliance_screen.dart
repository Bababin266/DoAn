import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../services/medicine_service.dart';
import '../services/language_service.dart';
import '../models/compliance_data.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  final MedicineService _medicineService = MedicineService();
  final PageController _pageController = PageController();

  final Map<int, double> _weeklyCompliance = {};
  bool _isLoadingChart = true;

  final Map<DateTime, List<ComplianceData>> _complianceEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoadingCalendar = true;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
    _fetchCalendarDataForMonth(_focusedDay);
  }

  // Map ngôn ngữ → locale cho Calendar/DateFormat
  String _calendarLocale(String code) {
    switch (code) {
      case 'vi':
        return 'vi_VN';
      case 'en':
        return 'en_US';
      case 'ja':
        return 'ja_JP';
      case 'ko':
        return 'ko_KR';
      case 'fr':
        return 'fr_FR';
      case 'es':
        return 'es_ES';
      case 'de':
        return 'de_DE';
      case 'zh-Hans':
        return 'zh_CN';
      case 'zh-Hant':
        return 'zh_TW';
      case 'ru':
        return 'ru_RU';
      case 'ar':
        return 'ar_SA';
      case 'hi':
        return 'hi_IN';
      case 'th':
        return 'th_TH';
      case 'id':
        return 'id_ID';
      case 'tr':
        return 'tr_TR';
      default:
        return 'en_US';
    }
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoadingChart = true);
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final compliance = await _medicineService.getComplianceForDay(day);
      _weeklyCompliance[day.millisecondsSinceEpoch] = compliance;
    }
    if (mounted) setState(() => _isLoadingChart = false);
  }

  Future<void> _fetchCalendarDataForMonth(DateTime month) async {
    setState(() => _isLoadingCalendar = true);
    final data = await _medicineService.getComplianceForMonth(month);
    _complianceEvents
      ..clear()
      ..addAll(data);
    if (mounted) setState(() => _isLoadingCalendar = false);
  }

  List<ComplianceData> _getEventsForDay(DateTime day) {
    return _complianceEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final L = LanguageService.instance;
    return ValueListenableBuilder<String>(
      valueListenable: L.langCode,
      builder: (_, code, __) {
        final calLocale = _calendarLocale(code);
        return Scaffold(
          appBar: AppBar(title: Text(L.tr('stats.title'))),
          body: PageView(
            controller: _pageController,
            children: [
              _buildChartView(L, calLocale),
              _buildCalendarView(L, calLocale),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartView(LanguageService L, String calLocale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L.tr('stats.last7'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          _isLoadingChart
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(height: 250, child: BarChart(_buildBarChartData(L, calLocale))),
          const SizedBox(height: 24),
          _buildSummaryCard(L),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: Text(L.tr('stats.viewHistory')),
              onPressed: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(LanguageService L, String calLocale) {
    return Column(
      children: [
        TableCalendar<ComplianceData>(
          locale: calLocale,
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
              final compliance = events.first.compliance;
              final markerColor = compliance >= 1.0
                  ? Colors.green
                  : (compliance > 0.5 ? Colors.orange : Colors.red);
              return Positioned(
                bottom: 1,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: markerColor),
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
              : _buildEventList(L, calLocale),
        ),
      ],
    );
  }

  Widget _buildEventList(LanguageService L, String calLocale) {
    final events = _getEventsForDay(_selectedDay);
    if (events.isEmpty) {
      return Center(child: Text(L.tr('stats.noDataDay')));
    }
    final data = events.first;
    final dateStr = DateFormat.yMd(calLocale).format(_selectedDay);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(L.tr('stats.detailsFor') + dateStr, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(L.tr('stats.dosesTaken')),
          trailing: Text('${data.dosesTaken}', style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red),
          title: Text(L.tr('stats.dosesMissed')),
          trailing: Text('${data.dosesMissed}', style: const TextStyle(fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.pie_chart, color: Colors.blue),
          title: Text(L.tr('stats.rate')),
          trailing: Text('${(data.compliance * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(LanguageService L) {
    if (_weeklyCompliance.isEmpty) return const SizedBox.shrink();
    final totalDoses = _weeklyCompliance.length;
    final takenDoses = _weeklyCompliance.values.where((c) => c > 0).length;
    final average = (takenDoses / totalDoses * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(L.tr('stats.total'), style: const TextStyle(color: Colors.grey)),
                Text('$totalDoses', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            Column(
              children: [
                Text(L.tr('stats.taken'), style: const TextStyle(color: Colors.grey)),
                Text('$takenDoses',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green)),
              ],
            ),
            Column(
              children: [
                Text(L.tr('stats.average'), style: const TextStyle(color: Colors.grey)),
                Text('$average%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChartData(LanguageService L, String calLocale) {
    final sortedEntries = _weeklyCompliance.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String dayLabel(DateTime d) => DateFormat.E(calLocale).format(d).substring(0, 1);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, i, rod, __) {
            final day = DateTime.fromMillisecondsSinceEpoch(sortedEntries[i].key);
            final dayOfWeek = DateFormat.E(calLocale).format(day);
            final compliance = (rod.toY * 100).toStringAsFixed(0);
            return BarTooltipItem('$dayOfWeek\n$compliance%',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt().clamp(0, sortedEntries.length - 1);
              final day = DateTime.fromMillisecondsSinceEpoch(sortedEntries[idx].key);
              return SideTitleWidget(axisSide: meta.axisSide, child: Text(dayLabel(day)));
            },
            reservedSize: 28,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value == 0) return Text(L.tr('stats.axis0'));
              if (value == 0.5) return Text(L.tr('stats.axis50'));
              if (value == 1) return Text(L.tr('stats.axis100'));
              return const Text('');
            },
            reservedSize: 36,
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
              color: compliance >= 0.9
                  ? Colors.green
                  : (compliance > 0.5 ? Colors.orange : Colors.red),
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
        getDrawingHorizontalLine: (_) =>
        const FlLine(color: Colors.grey, strokeWidth: 0.5, dashArray: [5, 5]),
      ),
    );
  }
}
