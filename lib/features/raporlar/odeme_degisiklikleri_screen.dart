import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class OdemeDegisiklikleriScreen extends StatefulWidget {
  const OdemeDegisiklikleriScreen({super.key});
  @override
  State<OdemeDegisiklikleriScreen> createState() => _State();
}

class _State extends State<OdemeDegisiklikleriScreen> {
  static const _color = Color(0xFFB7860B);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange              _range   = RaporlarService.defaultRange();
  List<Map<String, dynamic>> _items   = [];
  Map<int, String>           _cNames  = {};
  bool                       _loading = false;
  String?                    _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Future.wait([
        _svc.fetchPaymentChanges(_bay, _range),
        _svc.fetchCourierNames(_bay),
      ]);
      if (!mounted) return;
      setState(() {
        _items  = res[0] as List<Map<String, dynamic>>;
        _cNames = res[1] as Map<int, String>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Veri yüklenemedi'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReportScaffold(
      title:          'Ödeme Değişiklikleri',
      color:          _color,
      icon:           Icons.currency_exchange_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _items.isEmpty ? _buildEmpty() :
            ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              itemCount: _items.length,
              itemBuilder: (_, i) => _PCard(item: _items[i], cNames: _cNames, color: _color),
            ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _color.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.currency_exchange_rounded, size: 52, color: _color.withAlpha(120)),
        ),
        const SizedBox(height: 20),
        const Text('Ödeme değişikliği kaydı bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          'Farklı bir tarih aralığı seçin veya\nbilgi için web panelini inceleyin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ]),
    ),
  );
}

class _PCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<int, String>     cNames;
  final Color                color;
  const _PCard({required this.item, required this.cNames, required this.color});

  @override
  Widget build(BuildContext context) {
    final cId     = (item['courier_id'] ?? item['s_courier']) as num?;
    final name    = cNames[cId?.toInt() ?? 0] ?? (cId != null ? 'Kurye #${cId.toInt()}' : 'Bilinmeyen');
    final amount  = double.tryParse(item['amount']?.toString() ?? item['change_amount']?.toString() ?? '0') ?? 0;
    final reason  = item['reason']?.toString() ?? item['note']?.toString() ?? item['description']?.toString() ?? '';
    final date    = item['date'] ?? item['created_at'] ?? item['s_cdate'];
    final isPlus  = amount >= 0;

    return RCard(
      borderLeft: isPlus ? const Color(0xFF276749) : AppColors.error,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isPlus ? const Color(0xFF276749) : AppColors.error).withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPlus ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
            size: 22,
            color: isPlus ? const Color(0xFF276749) : AppColors.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              '${isPlus ? '+' : ''}${fMoney(amount)}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: isPlus ? const Color(0xFF276749) : AppColors.error),
            ),
          ]),
          const SizedBox(height: 3),
          if (reason.isNotEmpty)
            Text(reason,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          if (date != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 10, color: AppColors.textHint),
              const SizedBox(width: 3),
              Text(date is DateTime ? fDateTime(date) : date.toString(),
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ]),
          ],
        ])),
      ]),
    );
  }
}
