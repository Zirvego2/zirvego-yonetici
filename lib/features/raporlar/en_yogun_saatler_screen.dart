import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'raporlar_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _HourData {
  final int hour;   // 0..23
  int count;
  _HourData(this.hour) : count = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// EKRAN
// ─────────────────────────────────────────────────────────────────────────────

class EnYogunSaatlerScreen extends StatefulWidget {
  const EnYogunSaatlerScreen({super.key});

  @override
  State<EnYogunSaatlerScreen> createState() => _State();
}

class _State extends State<EnYogunSaatlerScreen> {
  static const _color = Color(0xFFF59E0B);

  final _svc = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTime _day = DateTime.now();
  List<_HourData> _hours = List.generate(24, (i) => _HourData(i));
  bool _loading = false;
  String? _error;

  // Hafta ve ay isimlerini Türkçe göster
  final _dayFmt   = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
  final _shortFmt = DateFormat('dd.MM.yyyy', 'tr_TR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final range = DateTimeRange(
        start: DateTime(_day.year, _day.month, _day.day, 0,  0,  0),
        end:   DateTime(_day.year, _day.month, _day.day, 23, 59, 59),
      );
      final orders = await _svc.fetchOrdersInRange(_bay, range);
      if (!mounted) return;

      final hours = List.generate(24, (i) => _HourData(i));
      for (final o in orders) {
        if (o.sCdate == null) continue;
        final h = o.sCdate!.hour;
        hours[h].count++;
      }
      setState(() { _hours = hours; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  // ── Gün seçici ──────────────────────────────────────────────────────────
  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate:   DateTime(2023),
      lastDate:    DateTime.now(),
      locale:      const Locale('tr'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   _color,
            onPrimary: Colors.white,
            surface:   Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _day = picked);
      _load();
    }
  }

  // ── Hesaplamalar ─────────────────────────────────────────────────────────
  int get _total => _hours.fold(0, (s, h) => s + h.count);

  int get _maxCount {
    final m = _hours.map((h) => h.count).fold(0, (a, b) => a > b ? a : b);
    return m < 1 ? 1 : m;
  }

  List<_HourData> get _busiest {
    final sorted = [..._hours]..sort((a, b) => b.count.compareTo(a.count));
    return sorted.where((h) => h.count > 0).take(3).toList();
  }

  // En yoğun saat numaraları (top-3 renklendirme için)
  late final Set<int> _topHours = {};

  void _computeTopHours() {
    _topHours
      ..clear()
      ..addAll(_busiest.map((h) => h.hour));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _computeTopHours();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.access_time_rounded, color: _color, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'En Yoğun Saatlerim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _color),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Gün Seçici ──────────────────────────────────────────────────
          _buildDayPicker(),
          // ── İçerik ──────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Gün seçici bandı ──────────────────────────────────────────────────────
  Widget _buildDayPicker() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Önceki gün
          _DayNavBtn(
            icon: Icons.chevron_left_rounded,
            enabled: _day.isAfter(DateTime(2023, 1, 2)),
            onTap: () {
              setState(() => _day = _day.subtract(const Duration(days: 1)));
              _load();
            },
          ),
          const SizedBox(width: 10),
          // Tarih göstergesi
          Expanded(
            child: GestureDetector(
              onTap: _pickDay,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _color.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _color.withAlpha(60)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 15, color: _color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _dayFmt.format(_day),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: _color, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Sonraki gün
          _DayNavBtn(
            icon: Icons.chevron_right_rounded,
            enabled: !_isSameDay(_day, DateTime.now()),
            onTap: () {
              setState(() => _day = _day.add(const Duration(days: 1)));
              _load();
            },
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Ana içerik ──────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _color),
            const SizedBox(height: 12),
            const Text('Yükleniyor...',
                style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.error),
            const SizedBox(height: 10),
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    if (_total == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 56, color: _color.withAlpha(80)),
            const SizedBox(height: 12),
            const Text(
              'Bu güne ait sipariş verisi yok.',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              _shortFmt.format(_day),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // ── Özet kartları ────────────────────────────────────
          _buildStats(),
          const SizedBox(height: 16),
          // ── Saat bazlı bar chart ─────────────────────────────
          _buildChart(),
          const SizedBox(height: 16),
          // ── En yoğun saatler listesi ─────────────────────────
          _buildBusiestList(),
        ],
      ),
    );
  }

  // ── Özet kartları ─────────────────────────────────────────────────────────
  Widget _buildStats() {
    final busiest = _busiest.isNotEmpty ? _busiest.first : null;
    final avgActive = _hours.where((h) => h.count > 0).length;
    final avgVal = avgActive > 0 ? (_total / avgActive).toStringAsFixed(1) : '—';

    return Row(
      children: [
        _StatCard(
          label: 'Toplam Sipariş',
          value: '$_total',
          icon: Icons.receipt_long_rounded,
          color: _color,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'En Yoğun',
          value: busiest != null ? '${busiest.hour}:00' : '—',
          icon: Icons.trending_up_rounded,
          color: AppColors.error,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Ort/Aktif Saat',
          value: avgVal,
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────────────
  Widget _buildChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 14),
            child: Text(
              'Saat Bazlı Sipariş Dağılımı',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: (_maxCount * 1.25).ceilToDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, _, rod, __) {
                      final h = group.x;
                      final cnt = rod.toY.toInt();
                      return BarTooltipItem(
                        '$h:00\n$cnt sipariş',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (_maxCount / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final h = v.toInt();
                        // Her 4 saatte bir etiket göster
                        if (h % 4 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$h',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textHint),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _hours.map((h) {
                  final isTop = _topHours.contains(h.hour);
                  final color = isTop
                      ? (h.hour == _busiest.firstOrNull?.hour
                          ? AppColors.error
                          : _color)
                      : AppColors.primary.withAlpha(160);
                  return BarChartGroupData(
                    x: h.hour,
                    barRods: [
                      BarChartRodData(
                        toY: h.count.toDouble(),
                        color: h.count == 0
                            ? AppColors.divider
                            : color,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Renk açıklaması
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.error, label: 'En yoğun saat'),
              const SizedBox(width: 14),
              _LegendDot(color: _color, label: 'Top 3 saat'),
              const SizedBox(width: 14),
              _LegendDot(
                  color: AppColors.primary.withAlpha(160), label: 'Diğer'),
            ],
          ),
        ],
      ),
    );
  }

  // ── En yoğun saatler listesi ──────────────────────────────────────────────
  Widget _buildBusiestList() {
    final ranked = [..._hours]..sort((a, b) => b.count.compareTo(a.count));
    final topItems = ranked.where((h) => h.count > 0).take(10).toList();
    if (topItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sıralama (En Yoğun → En Az)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...topItems.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final h    = entry.value;
            final isFirst  = rank == 1;
            final isSecond = rank == 2;
            final isThird  = rank == 3;

            Color rankColor;
            if (isFirst)       rankColor = AppColors.error;
            else if (isSecond) rankColor = _color;
            else if (isThird)  rankColor = const Color(0xFF6366F1);
            else               rankColor = AppColors.textHint;

            final pct = _total > 0 ? (h.count / _total * 100) : 0.0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Sıra badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rankColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: rankColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Saat
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${h.hour.toString().padLeft(2, '0')}:00'
                            ' – '
                            '${h.hour.toString().padLeft(2, '0')}:59',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${h.count} sipariş  •  %${pct.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Kısa bar
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${h.count}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: rankColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: h.count / _maxCount,
                                minHeight: 5,
                                backgroundColor: rankColor.withAlpha(20),
                                color: rankColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key < topItems.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YARDIMCI WIDGET'LAR
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayNavBtn extends StatelessWidget {
  final IconData icon;
  final bool     enabled;
  final VoidCallback onTap;

  const _DayNavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFF59E0B).withAlpha(18)
              : AppColors.divider.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? const Color(0xFFF59E0B).withAlpha(60)
                : AppColors.divider,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? const Color(0xFFF59E0B) : AppColors.textHint,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, color: AppColors.textSecondary)),
      ],
    );
  }
}
