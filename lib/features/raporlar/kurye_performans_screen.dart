import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class KuryePerformansScreen extends StatefulWidget {
  const KuryePerformansScreen({super.key});
  @override
  State<KuryePerformansScreen> createState() => _State();
}

class _State extends State<KuryePerformansScreen> {
  static const _color = Color(0xFF0891B2);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange          _range   = RaporlarService.defaultRange();
  List<_PerfRow>         _rows    = [];
  bool                   _loading = false;
  String?                _error;
  _SortBy                _sortBy  = _SortBy.rate;

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

  static List<_PerfRow> _buildRows(List<OrderModel> orders, Map<int, String> names) {
    final map = <int, _PerfRow>{};
    for (final o in orders) {
      if (o.sCourier <= 0) continue;
      map.putIfAbsent(o.sCourier, () => _PerfRow(id: o.sCourier, name: names[o.sCourier] ?? 'Kurye #${o.sCourier}'));
      map[o.sCourier]!.add(o);
    }
    return map.values.toList();
  }

  List<_PerfRow> get _sorted {
    final list = List<_PerfRow>.from(_rows);
    switch (_sortBy) {
      case _SortBy.rate:    list.sort((a, b) => b.deliveryRate.compareTo(a.deliveryRate));
      case _SortBy.orders:  list.sort((a, b) => b.total.compareTo(a.total));
      case _SortBy.speed:   list.sort((a, b) => a.avgReadyMin.compareTo(b.avgReadyMin));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    return ReportScaffold(
      title:          'Kurye Performans',
      color:          _color,
      icon:           Icons.leaderboard_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte performans verisi yok.',
              icon:    Icons.leaderboard_rounded,
              color:   _color,
            ) :
            Column(children: [
              RStatsRow(stats: [
                RStat(label: 'Kurye',  value: '${_rows.length}',    color: _color,                icon: Icons.delivery_dining_rounded),
                RStat(label: 'Ort. Teslimat', value: '${_avgRate.toStringAsFixed(0)}%', color: const Color(0xFF276749), icon: Icons.check_circle_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              // Sıralama
              _buildSortBar(),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _PerfCard(row: sorted[i], rank: i + 1),
                ),
              ),
            ]),
    );
  }

  double get _avgRate => _rows.isEmpty ? 0
      : _rows.fold(0.0, (s, r) => s + r.deliveryRate) / _rows.length;

  Widget _buildSortBar() => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      const Text('Sırala:', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
      const SizedBox(width: 8),
      ..._SortBy.values.map((s) {
        final sel = _sortBy == s;
        return GestureDetector(
          onTap: () => setState(() => _sortBy = s),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? _color : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? _color : AppColors.border),
            ),
            child: Text(s.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        );
      }),
    ]),
  );
}

enum _SortBy {
  rate('Teslimat %'),
  orders('Sipariş Sayısı'),
  speed('Hız');

  final String label;
  const _SortBy(this.label);
}

class _PerfRow {
  final int    id;
  final String name;
  int    total = 0, delivered = 0, cancelled = 0;
  int    readyCount = 0;
  double readySum = 0;

  _PerfRow({required this.id, required this.name});

  void add(OrderModel o) {
    total++;
    if (o.sStat == 2) delivered++;
    if (o.sStat == 3) cancelled++;
    if (o.sCdate != null && o.sOnRoadTime != null) {
      readySum += o.sOnRoadTime!.difference(o.sCdate!).inMinutes.abs().toDouble();
      readyCount++;
    }
  }

  double get deliveryRate   => total == 0 ? 0 : delivered / total * 100;
  double get avgReadyMin    => readyCount == 0 ? 0 : readySum / readyCount;
}

class _PerfCard extends StatelessWidget {
  final _PerfRow row;
  final int      rank;
  const _PerfCard({required this.row, required this.rank});

  @override
  Widget build(BuildContext context) {
    const c   = Color(0xFF0891B2);
    final pct = row.deliveryRate;
    final pctColor = pct >= 90 ? const Color(0xFF276749)
        : pct >= 70 ? const Color(0xFFF59E0B)
        : AppColors.error;
    return RCard(
      child: Row(children: [
        // Sıra
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: rank <= 3 ? const Color(0xFFD4A017).withAlpha(20) : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('#$rank',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: rank <= 3 ? const Color(0xFFD4A017) : AppColors.textHint))),
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
            _stat('${row.total}',     'Sipariş', AppColors.textSecondary),
            _stat('${row.delivered}', 'Teslim',  const Color(0xFF276749)),
            if (row.cancelled > 0)
              _stat('${row.cancelled}', 'İptal', AppColors.error),
            if (row.avgReadyMin > 0)
              _stat(fMin(row.avgReadyMin), 'Ort. Süre', c),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(children: [
          Text('${pct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pctColor)),
          const Text('Başarı', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
          const SizedBox(height: 4),
          SizedBox(
            width: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                color: pctColor,
                backgroundColor: AppColors.background,
                minHeight: 5,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _stat(String v, String l, Color c) => Container(
    margin: const EdgeInsets.only(right: 10),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      const SizedBox(width: 2),
      Text(l, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
    ]),
  );
}
