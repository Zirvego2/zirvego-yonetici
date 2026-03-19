import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class KuryeNakitleriScreen extends StatefulWidget {
  const KuryeNakitleriScreen({super.key});
  @override
  State<KuryeNakitleriScreen> createState() => _State();
}

class _State extends State<KuryeNakitleriScreen> {
  static const _color = Color(0xFFEF4444);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange              _range  = RaporlarService.defaultRange();
  List<Map<String, dynamic>> _txs    = [];
  Map<int, String>           _cNames = {};
  Map<int, String>           _wNames = {};
  bool                       _loading = false;
  String?                    _error;
  String                     _search  = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchCashTransactions(_bay, _range),
        _svc.fetchCourierNames(_bay),
        _svc.fetchWorkNames(_bay),
      ]);
      if (!mounted) return;
      setState(() {
        _txs    = res[0] as List<Map<String, dynamic>>;
        _cNames = res[1] as Map<int, String>;
        _wNames = res[2] as Map<int, String>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _txs;
    final q = _search.toLowerCase();
    return _txs.where((t) {
      final cId  = (t['courier_id'] as num?)?.toInt() ?? 0;
      final wId  = (t['work_id']    as num?)?.toInt() ?? 0;
      return (_cNames[cId] ?? '').toLowerCase().contains(q) ||
             (_wNames[wId] ?? '').toLowerCase().contains(q) ||
             (t['order_id']?.toString() ?? '').contains(q);
    }).toList();
  }

  double get _totalCash =>
      _txs.fold(0.0, (s, t) => s + (double.tryParse(t['cash_amount']?.toString() ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ReportScaffold(
      title:          'Kurye Üzerindeki Nakit',
      color:          _color,
      icon:           Icons.payments_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _txs.isEmpty ? const REmpty(
              message: 'Seçilen tarihte nakit işlem kaydı yok.',
              icon:    Icons.payments_rounded,
              color:   _color,
            ) :
            Column(children: [
              RStatsRow(stats: [
                RStat(label: 'İşlem',        value: '${_txs.length}',           color: _color,                icon: Icons.receipt_rounded),
                RStat(label: 'Toplam Nakit', value: fMoney(_totalCash),         color: const Color(0xFF276749), icon: Icons.attach_money_rounded),
              ]),
              const Divider(height: 1, color: AppColors.divider),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Kurye, işletme veya sipariş ara…',
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
                        itemBuilder: (_, i) => _TxCard(
                          tx:     filtered[i],
                          cNames: _cNames,
                          wNames: _wNames,
                        ),
                      ),
              ),
            ]),
    );
  }
}

class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final Map<int, String>     cNames;
  final Map<int, String>     wNames;
  const _TxCard({required this.tx, required this.cNames, required this.wNames});

  @override
  Widget build(BuildContext context) {
    const c      = Color(0xFFEF4444);
    final cId    = (tx['courier_id'] as num?)?.toInt() ?? 0;
    final wId    = (tx['work_id']    as num?)?.toInt() ?? 0;
    final amt    = double.tryParse(tx['cash_amount']?.toString() ?? '0') ?? 0.0;
    final txDate = tx['transaction_date'] as DateTime?;
    final type   = _txTypeLabel(tx['transaction_type']?.toString() ?? '');

    return RCard(
      borderLeft: c,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.payments_rounded, size: 22, color: Color(0xFFEF4444)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(cNames[cId] ?? 'Kurye #$cId',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(fMoney(amt),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFFEF4444))),
          ]),
          const SizedBox(height: 3),
          if (wId > 0)
            Row(children: [
              const Icon(Icons.store_rounded, size: 11, color: AppColors.textHint),
              const SizedBox(width: 3),
              Text(wNames[wId] ?? 'İşletme #$wId',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: c.withAlpha(12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type, style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
            ),
            const Spacer(),
            Text(fDateTime(txDate),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
        ])),
      ]),
    );
  }

  String _txTypeLabel(String type) {
    if (type.isEmpty) return 'Nakit';
    const map = {
      'delivery':    'Teslim',
      'adjustment':  'Düzeltme',
      'transfer':    'Transfer',
      'return':      'İade',
    };
    return map[type.toLowerCase()] ?? type;
  }
}
