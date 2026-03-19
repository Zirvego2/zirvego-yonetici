import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class KuryeKazancScreen extends StatefulWidget {
  const KuryeKazancScreen({super.key});
  @override
  State<KuryeKazancScreen> createState() => _State();
}

class _State extends State<KuryeKazancScreen> {
  static const _color = Color(0xFF10B981);
  final _svc    = RaporlarService.instance;
  final _auth   = AuthService.instance;
  int    get _bay    => _auth.currentUser?.sId    ?? 0;
  String get _docId  => _auth.currentUser?.docId  ?? '';

  DateTimeRange    _range    = RaporlarService.defaultRange();
  List<_EarnRow>   _rows     = [];
  double           _perOrder = 0;
  bool             _loading  = false;
  String?          _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchOrdersInRange(_bay, _range, filterStats: [2]), // sadece teslim
        _svc.fetchCourierNames(_bay),
        _svc.fetchBayPaySettings(_docId),
      ]);
      if (!mounted) return;
      final orders   = res[0] as List<OrderModel>;
      final names    = res[1] as Map<int, String>;
      final pay      = res[2] as ({double perOrder, double perKm});
      setState(() {
        _perOrder = pay.perOrder;
        _rows     = _buildRows(orders, names, pay.perOrder);
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  static List<_EarnRow> _buildRows(
    List<OrderModel> orders,
    Map<int, String> names,
    double perOrder,
  ) {
    final map = <int, _EarnRow>{};
    for (final o in orders) {
      if (o.sCourier <= 0) continue;
      map.putIfAbsent(o.sCourier, () => _EarnRow(
        id:       o.sCourier,
        name:     names[o.sCourier] ?? 'Kurye #${o.sCourier}',
        perOrder: perOrder,
      ));
      map[o.sCourier]!.count++;
    }
    return map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  double get _grandTotal => _rows.fold(0.0, (s, r) => s + r.total);
  int    get _totalCount => _rows.fold(0, (s, r) => s + r.count);

  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title:          'Kurye Kazanç',
      color:          _color,
      icon:           Icons.savings_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte teslim edilen sipariş yok.',
              icon:    Icons.savings_rounded,
              color:   _color,
            ) :
            Column(children: [
              // Birim ücret bilgisi
              if (_perOrder > 0)
                Container(
                  width: double.infinity,
                  color: _color.withAlpha(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: _color),
                    const SizedBox(width: 6),
                    Text('Birim ücret: ${fMoney(_perOrder)} / sipariş',
                        style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500)),
                  ]),
                ),
              RStatsRow(stats: [
                RStat(label: 'Toplam Kazanç',  value: fMoney(_grandTotal), color: _color,                icon: Icons.savings_rounded),
                RStat(label: 'Teslim Edilen',  value: '$_totalCount',      color: const Color(0xFF276749), icon: Icons.check_circle_rounded),
                RStat(label: 'Aktif Kurye',    value: '${_rows.length}',   color: const Color(0xFF0891B2), icon: Icons.delivery_dining_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => _EarnCard(row: _rows[i], rank: i + 1),
                ),
              ),
            ]),
    );
  }
}

class _EarnRow {
  final int    id;
  final String name;
  final double perOrder;
  int count = 0;
  double get total => count * perOrder;

  _EarnRow({required this.id, required this.name, required this.perOrder});
}

class _EarnCard extends StatelessWidget {
  final _EarnRow row;
  final int      rank;
  const _EarnCard({required this.row, required this.rank});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF10B981);
    return RCard(
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: rank <= 3 ? const Color(0xFFD4A017).withAlpha(20) : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('#$rank',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: rank <= 3 ? const Color(0xFFD4A017) : AppColors.textHint))),
        ),
        const SizedBox(width: 8),
        courierAvatar(row.name, c, size: 42),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF276749)),
            const SizedBox(width: 4),
            Text('${row.count} teslim',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fMoney(row.total),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c)),
          const Text('Kazanç', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
        ]),
      ]),
    );
  }
}
