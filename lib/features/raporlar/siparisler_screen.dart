import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/order_model.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class SiparislerScreen extends StatefulWidget {
  const SiparislerScreen({super.key});
  @override
  State<SiparislerScreen> createState() => _SiparislerScreenState();
}

class _SiparislerScreenState extends State<SiparislerScreen> {
  static const _color = AppColors.primary;

  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange        _range        = RaporlarService.defaultRange();
  List<OrderModel>     _orders       = [];
  Map<int, String>     _cNames       = {};
  bool                 _loading      = false;
  String?              _error;
  int?                 _statFilter;   // null = tümü
  String               _search       = '';

  static const _statOptions = [
    (label: 'Tümü',   value: null),
    (label: 'Teslim', value: 2),
    (label: 'İptal',  value: 3),
    (label: 'İade',   value: 5),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchOrdersInRange(_bay, _range, filterStats: [2, 3, 5]),
        _svc.fetchCourierNames(_bay),
      ]);
      if (!mounted) return;
      setState(() {
        _orders  = res[0] as List<OrderModel>;
        _cNames  = res[1] as Map<int, String>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  List<OrderModel> get _filtered {
    var list = _statFilter == null
        ? _orders
        : _orders.where((o) => o.sStat == _statFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((o) =>
        o.sCustomer.ssFullname.toLowerCase().contains(q) ||
        (_cNames[o.sCourier] ?? '').toLowerCase().contains(q) ||
        o.sId.toString().contains(q),
      ).toList();
    }
    return list;
  }

  int _countStat(int s) => _orders.where((o) => o.sStat == s).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ReportScaffold(
      title:          'Teslim & İptal Siparişler',
      color:          _color,
      icon:           Icons.receipt_long_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _orders.isEmpty ? const REmpty(
              message: 'Seçilen tarihte teslim/iptal sipariş yok.',
              icon:    Icons.receipt_long_rounded,
              color:   _color,
            ) :
            Column(children: [
              // İstatistik
              RStatsRow(stats: [
                RStat(label: 'Toplam',  value: '${_orders.length}', color: _color,                          icon: Icons.list_alt_rounded),
                RStat(label: 'Teslim',  value: '${_countStat(2)}',  color: const Color(0xFF276749),          icon: Icons.check_circle_rounded),
                RStat(label: 'İptal',   value: '${_countStat(3)}',  color: AppColors.error,                  icon: Icons.cancel_rounded),
                RStat(label: 'İade',    value: '${_countStat(5)}',  color: const Color(0xFFF59E0B),           icon: Icons.keyboard_return_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),

              // Filtre + arama
              _buildFilterBar(),
              const Divider(height: 1, color: AppColors.divider),

              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Filtre sonucu bulunamadı.',
                        style: TextStyle(color: AppColors.textHint)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 6, bottom: 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order:   filtered[i],
                          cName:   _cNames[filtered[i].sCourier],
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Arama
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Müşteri, kurye veya sipariş no ara…',
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        ),
        const SizedBox(height: 7),
        // Durum filtresi
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _statOptions.map((opt) {
            final sel = _statFilter == opt.value;
            return GestureDetector(
              onTap: () => setState(() => _statFilter = opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color:  sel ? _color : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _color : AppColors.border),
                ),
                child: Text(opt.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel  order;
  final String?     cName;
  const _OrderCard({required this.order, this.cName});

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(order.sPay.ssPaycount?.toString() ?? '0') ?? 0;
    final amtStr = amount > 0 ? '₺${amount.toStringAsFixed(2)}' : '-';

    return RCard(
      borderLeft: orderStatColor(order.sStat),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          orderStatBadge(order.sStat),
          const SizedBox(width: 6),
          payTypeBadge(order.sPay.ssPaytype),
          const Spacer(),
          Text(fDateTime(order.sCdate),
              style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person_rounded, size: 13, color: AppColors.textHint),
          const SizedBox(width: 4),
          Expanded(
            child: Text(order.sCustomer.ssFullname.isEmpty
                    ? 'Bilinmeyen Müşteri'
                    : order.sCustomer.ssFullname,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Text(amtStr,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
        if (order.sCustomer.ssAdres.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 11, color: AppColors.textHint),
            const SizedBox(width: 3),
            Expanded(
              child: Text(order.sCustomer.ssAdres,
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
        if (cName != null) ...[
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.delivery_dining_rounded, size: 11, color: AppColors.textHint),
            const SizedBox(width: 3),
            Text(cName!,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
      ]),
    );
  }
}
