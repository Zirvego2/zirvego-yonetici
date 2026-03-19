import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class VardiyaTakipScreen extends StatefulWidget {
  const VardiyaTakipScreen({super.key});
  @override
  State<VardiyaTakipScreen> createState() => _State();
}

class _State extends State<VardiyaTakipScreen> {
  static const _color = Color(0xFF7C3AED);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange              _range   = RaporlarService.defaultRange();
  List<Map<String, dynamic>> _logs    = [];
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
        _svc.fetchDailyLogs(_bay, _range),
        _svc.fetchCourierNames(_bay),
      ]);
      if (!mounted) return;
      setState(() {
        _logs   = res[0] as List<Map<String, dynamic>>;
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
      title:          'Kurye Vardiya Takip',
      color:          _color,
      icon:           Icons.schedule_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _logs.isEmpty ? REmpty(
              message: 'Seçilen tarihte vardiya/mola kaydı yok.',
              icon:    Icons.schedule_rounded,
              color:   _color,
              onRefresh: _load,
            ) :
            ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              itemCount: _logs.length,
              itemBuilder: (_, i) => _VCard(log: _logs[i], cNames: _cNames, color: _color),
            ),
    );
  }
}

class _VCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Map<int, String>     cNames;
  final Color                color;
  const _VCard({required this.log, required this.cNames, required this.color});

  @override
  Widget build(BuildContext context) {
    final cId      = (log['courier_id'] ?? log['s_courier']) as num?;
    final name     = cNames[cId?.toInt() ?? 0] ?? (cId != null ? 'Kurye #${cId.toInt()}' : 'Bilinmeyen');
    final date     = log['date'] ?? log['s_date'];
    final type     = _typeLabel(log['type']?.toString() ?? log['s_stat']?.toString() ?? '');
    final typeIcon = _typeIcon(log['type']?.toString() ?? '');
    final typeClr  = _typeColor(log['type']?.toString() ?? '');
    final start    = log['start_time'] ?? log['shift_start'];
    final end      = log['end_time']   ?? log['shift_end'];
    final dur      = (log['duration_minutes'] ?? log['total_minutes']) as num?;

    return RCard(
      borderLeft: typeClr,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          courierAvatar(name, color, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            if (date != null)
              Text(date is DateTime
                      ? DateFormat('dd.MM.yyyy', 'tr').format(date)
                      : date.toString(),
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeClr.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(typeIcon, size: 12, color: typeClr),
              const SizedBox(width: 4),
              Text(type,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeClr)),
            ]),
          ),
        ]),
        if (start != null || end != null || dur != null) ...[
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 6),
          Row(children: [
            if (start != null) _timeChip(Icons.play_arrow_rounded, 'Başlangıç',
                start is DateTime ? DateFormat('HH:mm').format(start) : start.toString(), const Color(0xFF276749)),
            if (end   != null) _timeChip(Icons.stop_rounded, 'Bitiş',
                end is DateTime ? DateFormat('HH:mm').format(end) : end.toString(), AppColors.error),
            if (dur   != null) _timeChip(Icons.timer_rounded, 'Süre',
                '${dur.toInt()} dk', color),
          ]),
        ],
      ]),
    );
  }

  Widget _timeChip(IconData icon, String label, String value, Color c) => Container(
    margin: const EdgeInsets.only(right: 10),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: c),
      const SizedBox(width: 3),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
        Text(value,  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
    ]),
  );

  String _typeLabel(String t) {
    final lc = t.toLowerCase();
    if (lc.contains('shift') || lc.contains('vardiya')) return 'Vardiya';
    if (lc.contains('break') || lc.contains('mola'))    return 'Mola';
    if (lc.contains('leave') || lc.contains('izin'))    return 'İzin';
    if (lc.contains('overtime'))                        return 'Fazla Mesai';
    if (t.isEmpty)                                      return 'Log';
    return t;
  }

  IconData _typeIcon(String t) {
    final lc = t.toLowerCase();
    if (lc.contains('break') || lc.contains('mola'))  return Icons.coffee_rounded;
    if (lc.contains('leave') || lc.contains('izin'))  return Icons.beach_access_rounded;
    if (lc.contains('overtime'))                      return Icons.more_time_rounded;
    return Icons.schedule_rounded;
  }

  Color _typeColor(String t) {
    final lc = t.toLowerCase();
    if (lc.contains('shift')   || lc.contains('vardiya')) return const Color(0xFF7C3AED);
    if (lc.contains('break')   || lc.contains('mola'))    return const Color(0xFF0891B2);
    if (lc.contains('leave')   || lc.contains('izin'))    return const Color(0xFFF59E0B);
    if (lc.contains('overtime'))                          return const Color(0xFF276749);
    return AppColors.textHint;
  }
}
