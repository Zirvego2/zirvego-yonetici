import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class KuryeRaporuScreen extends StatefulWidget {
  const KuryeRaporuScreen({super.key});
  @override
  State<KuryeRaporuScreen> createState() => _KuryeRaporuScreenState();
}

class _KuryeRaporuScreenState extends State<KuryeRaporuScreen> {
  static const _color = Color(0xFF276749);

  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange          _range   = RaporlarService.defaultRange();
  List<CourierReportRow> _rows    = [];
  bool                   _loading = false;
  String?                _error;
  String                 _search  = '';

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
      setState(() {
        _rows    = CourierReportRow.fromOrders(orders, names);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  List<CourierReportRow> get _filtered => _search.isEmpty
      ? _rows
      : _rows.where((r) =>
          r.courierName.toLowerCase().contains(_search.toLowerCase())).toList();

  int get _totalOrders    => _rows.fold(0, (s, r) => s + r.totalOrders);
  int get _totalDelivered => _rows.fold(0, (s, r) => s + r.delivered);
  int get _totalCancelled => _rows.fold(0, (s, r) => s + r.cancelled);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ReportScaffold(
      title:          'Kurye Raporu',
      color:          _color,
      icon:           Icons.bar_chart_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _rows.isEmpty ? const REmpty(
              message: 'Seçilen tarihte kurye verisi yok.',
              icon:    Icons.bar_chart_rounded,
              color:   _color,
            ) :
            Column(children: [
              RStatsRow(stats: [
                RStat(label: 'Toplam Sipariş', value: '$_totalOrders',    color: _color,                icon: Icons.list_alt_rounded),
                RStat(label: 'Teslim',         value: '$_totalDelivered', color: const Color(0xFF10B981), icon: Icons.check_circle_rounded),
                RStat(label: 'İptal',          value: '$_totalCancelled', color: AppColors.error,         icon: Icons.cancel_rounded),
                RStat(label: 'Aktif Kurye',    value: '${_rows.length}',  color: const Color(0xFF0891B2), icon: Icons.delivery_dining_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              // Arama
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Kurye ara…',
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
                        itemBuilder: (_, i) => _CRow(row: filtered[i]),
                      ),
              ),
            ]),
    );
  }
}

class _CRow extends StatelessWidget {
  final CourierReportRow row;
  const _CRow({required this.row});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF276749);
    final rate = row.deliveryRate.toStringAsFixed(1);
    return RCard(
      child: Row(children: [
        courierAvatar(row.courierName, c),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.courierName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _mini('${row.totalOrders} sipariş',  Icons.list_alt_rounded,         AppColors.textSecondary),
            _mini('${row.delivered} teslim',     Icons.check_circle_rounded,     c),
            if (row.cancelled > 0)
              _mini('${row.cancelled} iptal',    Icons.cancel_rounded,           AppColors.error),
            if (row.returned > 0)
              _mini('${row.returned} iade',      Icons.keyboard_return_rounded,  const Color(0xFFF59E0B)),
          ]),
          if (row.avgReadyMinutes > 0 || row.avgOnRoadMinutes > 0) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              if (row.avgReadyMinutes > 0)
                _mini('Ort. Bekleme ${fMin(row.avgReadyMinutes)}', Icons.timer_outlined, AppColors.textHint),
              if (row.avgOnRoadMinutes > 0)
                _mini('Ort. Hazırlık ${fMin(row.avgOnRoadMinutes)}', Icons.directions_bike_rounded, AppColors.textHint),
            ]),
          ],
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$rate%',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: row.deliveryRate >= 80 ? c : AppColors.error)),
          const Text('Teslimat', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
          if (row.totalCash > 0) ...[
            const SizedBox(height: 4),
            Text(fMoney(row.totalCash),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981))),
            const Text('Nakit', style: TextStyle(fontSize: 9, color: AppColors.textHint)),
          ],
        ]),
      ]),
    );
  }

  Widget _mini(String label, IconData icon, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ],
  );
}
