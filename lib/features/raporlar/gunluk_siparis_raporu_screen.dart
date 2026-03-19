import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class GunlukSiparisRaporuScreen extends StatefulWidget {
  const GunlukSiparisRaporuScreen({super.key});
  @override
  State<GunlukSiparisRaporuScreen> createState() => _State();
}

class _State extends State<GunlukSiparisRaporuScreen> {
  static const _color = Color(0xFF6366F1);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange    _range   = RaporlarService.defaultRange();
  List<_DayRow>    _rows    = [];
  bool             _loading = false;
  String?          _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await _svc.fetchOrdersInRange(_bay, _range);
      if (!mounted) return;
      setState(() { _rows = _buildRows(orders); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  static List<_DayRow> _buildRows(List<OrderModel> orders) {
    final map = <String, _DayRow>{};
    final fmt = DateFormat('yyyy-MM-dd');
    for (final o in orders) {
      if (o.sCdate == null) continue;
      final key = fmt.format(o.sCdate!);
      map.putIfAbsent(key, () => _DayRow(date: o.sCdate!));
      map[key]!.add(o);
    }
    return map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get _totalAll       => _rows.fold(0, (s, r) => s + r.total);
  int get _totalDelivered => _rows.fold(0, (s, r) => s + r.delivered);
  int get _totalCancelled => _rows.fold(0, (s, r) => s + r.cancelled);

  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title:          'Günlük Sipariş Raporu',
      color:          _color,
      icon:           Icons.calendar_month_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte sipariş verisi yok.',
              icon:    Icons.calendar_month_rounded,
              color:   _color,
            ) :
            Column(children: [
              RStatsRow(stats: [
                RStat(label: 'Toplam',  value: '$_totalAll',       color: _color,                icon: Icons.list_alt_rounded),
                RStat(label: 'Teslim',  value: '$_totalDelivered', color: const Color(0xFF276749), icon: Icons.check_circle_rounded),
                RStat(label: 'İptal',   value: '$_totalCancelled', color: AppColors.error,         icon: Icons.cancel_rounded),
                RStat(label: 'Gün',     value: '${_rows.length}',  color: const Color(0xFF0891B2), icon: Icons.today_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => _DayCard(row: _rows[i]),
                ),
              ),
            ]),
    );
  }
}

class _DayRow {
  final DateTime date;
  int total = 0, delivered = 0, cancelled = 0, returned = 0;
  double totalAmount = 0;

  _DayRow({required this.date});

  void add(OrderModel o) {
    total++;
    if (o.sStat == 2) delivered++;
    if (o.sStat == 3) cancelled++;
    if (o.sStat == 5) returned++;
    totalAmount += double.tryParse(o.sPay.ssPaycount?.toString() ?? '0') ?? 0;
  }

  double get deliveryRate => total == 0 ? 0 : delivered / total * 100;
}

class _DayCard extends StatelessWidget {
  final _DayRow row;
  const _DayCard({required this.row});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF6366F1);
    final pct = row.deliveryRate;
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              DateFormat('dd MMMM yyyy, EEEE', 'tr').format(row.date),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
            ),
          ),
          const Spacer(),
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: pct >= 80 ? const Color(0xFF276749) : AppColors.error)),
        ]),
        const SizedBox(height: 10),
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: row.total == 0 ? 0 : row.delivered / row.total,
            backgroundColor: AppColors.background,
            color: const Color(0xFF276749),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _chip('${row.total}',     'Toplam',  c),
          _chip('${row.delivered}', 'Teslim',  const Color(0xFF276749)),
          _chip('${row.cancelled}', 'İptal',   AppColors.error),
          if (row.returned > 0)
            _chip('${row.returned}', 'İade',   const Color(0xFFF59E0B)),
          const Spacer(),
          if (row.totalAmount > 0)
            Text(fMoney(row.totalAmount),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
        ]),
      ]),
    );
  }

  Widget _chip(String v, String l, Color c) => Container(
    margin: const EdgeInsets.only(right: 8),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
      const SizedBox(width: 3),
      Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
    ]),
  );
}
