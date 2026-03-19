import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class TeslimSureRaporuScreen extends StatefulWidget {
  const TeslimSureRaporuScreen({super.key});
  @override
  State<TeslimSureRaporuScreen> createState() => _State();
}

class _State extends State<TeslimSureRaporuScreen> {
  static const _color = Color(0xFFEC4899);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange   _range   = RaporlarService.defaultRange();
  List<_TimeRow>  _rows    = [];
  bool            _loading = false;
  String?         _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchOrdersInRange(_bay, _range),
        _svc.fetchCourierNames(_bay),
      ]);
      if (!mounted) return;
      final orders = res[0] as List<OrderModel>;
      final names  = res[1] as Map<int, String>;
      setState(() { _rows = _buildRows(orders, names); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  static List<_TimeRow> _buildRows(List<OrderModel> orders, Map<int, String> names) {
    final map = <int, _TimeRow>{};
    for (final o in orders) {
      if (o.sCourier <= 0) continue;
      if (o.sCdate == null) continue;
      map.putIfAbsent(o.sCourier, () => _TimeRow(
        id:   o.sCourier,
        name: names[o.sCourier] ?? 'Kurye #${o.sCourier}',
      ));
      map[o.sCourier]!.add(o);
    }
    return map.values.toList()
      ..sort((a, b) => a.avgTotalMin.compareTo(b.avgTotalMin));
  }

  double get _overallAvg {
    if (_rows.isEmpty) return 0;
    final withData = _rows.where((r) => r.avgTotalMin > 0).toList();
    if (withData.isEmpty) return 0;
    return withData.fold(0.0, (s, r) => s + r.avgTotalMin) / withData.length;
  }

  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title:          'Kurye Teslim Süre Raporu',
      color:          _color,
      icon:           Icons.timer_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte süre verisi yok.',
              icon:    Icons.timer_rounded,
              color:   _color,
            ) :
            Column(children: [
              Container(
                width: double.infinity,
                color: _color.withAlpha(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: _color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Oluşturma → Yola Çıkma süresi ölçülmektedir. En hızlıdan yavaşa sıralı.',
                      style: TextStyle(fontSize: 11, color: _color),
                    ),
                  ),
                ]),
              ),
              RStatsRow(stats: [
                RStat(label: 'Kurye',       value: '${_rows.length}',              color: _color,                icon: Icons.delivery_dining_rounded),
                RStat(label: 'Genel Ort.',  value: fMin(_overallAvg),             color: const Color(0xFF0891B2), icon: Icons.timer_rounded),
                RStat(label: 'En Hızlı',    value: fMin(_rows.first.avgTotalMin), color: const Color(0xFF276749), icon: Icons.flash_on_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => _TimeCard(row: _rows[i], rank: i + 1, overallAvg: _overallAvg),
                ),
              ),
            ]),
    );
  }
}

class _TimeRow {
  final int    id;
  final String name;
  int    totalOrders = 0, withTimeCount = 0;
  int    delivered = 0;
  double totalMins = 0;

  _TimeRow({required this.id, required this.name});

  void add(OrderModel o) {
    totalOrders++;
    if (o.sStat == 2) delivered++;
    // Sipariş oluşturma → yola çıkma süresi
    if (o.sCdate != null && o.sOnRoadTime != null) {
      final diff = o.sOnRoadTime!.difference(o.sCdate!).inMinutes;
      if (diff >= 0 && diff < 300) { // 5 saatten az makul değer
        totalMins += diff.toDouble();
        withTimeCount++;
      }
    }
  }

  double get avgTotalMin => withTimeCount == 0 ? 0 : totalMins / withTimeCount;
}

class _TimeCard extends StatelessWidget {
  final _TimeRow row;
  final int      rank;
  final double   overallAvg;
  const _TimeCard({required this.row, required this.rank, required this.overallAvg});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFEC4899);
    final avg   = row.avgTotalMin;
    final isFast = overallAvg > 0 && avg < overallAvg;
    final barColor = avg == 0   ? AppColors.textHint
        : isFast                ? const Color(0xFF276749)
        :                         AppColors.error;

    return RCard(
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: barColor.withAlpha(18),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('#$rank',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: barColor))),
        ),
        const SizedBox(width: 10),
        courierAvatar(row.name, c, size: 38),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            _mini('${row.totalOrders} sipariş',   AppColors.textSecondary),
            _mini('${row.delivered} teslim',      const Color(0xFF276749)),
          ]),
          if (avg > 0 && overallAvg > 0) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (avg / (overallAvg * 2)).clamp(0.0, 1.0),
                color: barColor,
                backgroundColor: AppColors.background,
                minHeight: 4,
              ),
            ),
          ],
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          avg == 0
              ? const Text('—', style: TextStyle(fontSize: 15, color: AppColors.textHint))
              : Text(fMin(avg),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: barColor)),
          const Text('Ort. Süre', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
          if (avg > 0 && isFast) ...[
            const SizedBox(height: 2),
            const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFF276749)),
          ],
        ]),
      ]),
    );
  }

  Widget _mini(String l, Color c) => Container(
    margin: const EdgeInsets.only(right: 8),
    child: Text(l, style: TextStyle(fontSize: 10, color: c)),
  );
}
