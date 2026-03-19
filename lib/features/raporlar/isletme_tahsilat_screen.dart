import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class IsletmeTahsilatScreen extends StatefulWidget {
  const IsletmeTahsilatScreen({super.key});
  @override
  State<IsletmeTahsilatScreen> createState() => _State();
}

class _State extends State<IsletmeTahsilatScreen> {
  static const _color = Color(0xFF9333EA);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange    _range   = RaporlarService.defaultRange();
  List<_WRow>      _rows    = [];
  bool             _loading = false;
  String?          _error;
  String           _search  = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchOrdersInRange(_bay, _range),
        _svc.fetchWorkNames(_bay),
      ]);
      if (!mounted) return;
      final orders = res[0] as List<OrderModel>;
      final names  = res[1] as Map<int, String>;
      setState(() { _rows = _buildRows(orders, names); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  static List<_WRow> _buildRows(List<OrderModel> orders, Map<int, String> names) {
    final map = <int, _WRow>{};
    for (final o in orders) {
      if (o.sWork <= 0) continue;
      map.putIfAbsent(o.sWork, () => _WRow(id: o.sWork, name: names[o.sWork] ?? 'İşletme #${o.sWork}'));
      map[o.sWork]!.add(o);
    }
    return map.values.toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  List<_WRow> get _filtered => _search.isEmpty
      ? _rows
      : _rows.where((r) => r.name.toLowerCase().contains(_search.toLowerCase())).toList();

  double get _grandTotal => _rows.fold(0.0, (s, r) => s + r.totalAmount);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ReportScaffold(
      title:          'İşletme Tahsilat',
      color:          _color,
      icon:           Icons.store_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte işletme verisi yok.',
              icon:    Icons.store_rounded,
              color:   _color,
            ) :
            Column(children: [
              RStatsRow(stats: [
                RStat(label: 'Toplam Tutar',  value: fMoney(_grandTotal),  color: _color,                icon: Icons.attach_money_rounded),
                RStat(label: 'İşletme',       value: '${_rows.length}',    color: const Color(0xFF0891B2), icon: Icons.store_rounded),
                RStat(label: 'Toplam Sipariş',value: '${_rows.fold(0, (s, r) => s + r.total)}', color: AppColors.textSecondary, icon: Icons.list_alt_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'İşletme ara…',
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                    filled: true, fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Sonuç bulunamadı.',
                        style: TextStyle(color: AppColors.textHint)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 6, bottom: 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _WCard(row: filtered[i]),
                      ),
              ),
            ]),
    );
  }
}

class _WRow {
  final int    id;
  final String name;
  int    total = 0, delivered = 0, cancelled = 0;
  int    cashCount = 0, cardCount = 0;
  double totalAmount = 0, cashAmount = 0;

  _WRow({required this.id, required this.name});

  void add(OrderModel o) {
    total++;
    if (o.sStat == 2) delivered++;
    if (o.sStat == 3) cancelled++;
    final amt = double.tryParse(o.sPay.ssPaycount?.toString() ?? '0') ?? 0;
    totalAmount += amt;
    if (o.sPay.ssPaytype == 0) {
      cashCount++;
      cashAmount += amt;
    } else {
      cardCount++;
    }
  }
}

class _WCard extends StatelessWidget {
  final _WRow row;
  const _WCard({required this.row});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF9333EA);
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: c.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded, size: 20, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(row.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fMoney(row.totalAmount),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
            const Text('Toplam', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, children: [
          _chip('${row.total}',     'Sipariş',  AppColors.textSecondary),
          _chip('${row.delivered}', 'Teslim',   const Color(0xFF276749)),
          if (row.cancelled > 0)
            _chip('${row.cancelled}', 'İptal',  AppColors.error),
          if (row.cashCount > 0)
            _chip(fMoney(row.cashAmount), 'Nakit',  const Color(0xFF10B981)),
          if (row.cardCount > 0)
            _chip('${row.cardCount}x', 'Kart', const Color(0xFF6366F1)),
        ]),
      ]),
    );
  }

  Widget _chip(String v, String l, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      const SizedBox(width: 3),
      Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
    ],
  );
}
