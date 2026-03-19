import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '_report_widgets.dart';
import 'raporlar_service.dart';

class IzinPlaniScreen extends StatefulWidget {
  const IzinPlaniScreen({super.key});
  @override
  State<IzinPlaniScreen> createState() => _State();
}

class _State extends State<IzinPlaniScreen> {
  static const _color = Color(0xFFF59E0B);
  final _svc   = RaporlarService.instance;
  int get _bay => AuthService.instance.currentUser?.sId ?? 0;

  DateTimeRange              _range   = _weekRange();
  List<Map<String, dynamic>> _logs    = [];
  Map<int, String>           _cNames  = {};
  bool                       _loading = false;
  String?                    _error;

  static DateTimeRange _weekRange() {
    final now = DateTime.now();
    // Haftanın başı (Pazartesi)
    final start = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day, 0, 0, 0),
      end:   DateTime(start.year, start.month, start.day + 6, 23, 59, 59),
    );
  }

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
      final allLogs = res[0] as List<Map<String, dynamic>>;
      // Yalnızca izin tipi kayıtları filtrele
      final izin = allLogs.where((l) {
        final type = l['type']?.toString().toLowerCase() ?? '';
        final stat = l['s_stat'];
        return type.contains('izin') || type.contains('leave') ||
               type.contains('off')  || stat == 'leave' ||
               (l['is_leave'] == true);
      }).toList();
      setState(() {
        _logs   = izin;
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
      title:          'Kurye İzin Planı',
      color:          _color,
      icon:           Icons.event_available_rounded,
      range:          _range,
      loading:        _loading,
      onRangeChanged: (r) { setState(() => _range = r); _load(); },
      onRefresh:      _load,
      body: _loading ? const RLoading(color: _color) :
            _error  != null ? RError(onRetry: _load) :
            _logs.isEmpty ? _buildEmpty() :
            ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              itemCount: _logs.length,
              itemBuilder: (_, i) => _LogCard(log: _logs[i], cNames: _cNames, color: _color),
            ),
    );
  }

  Widget _buildEmpty() {
    final days = _range.end.difference(_range.start).inDays + 1;
    return REmpty(
      message: '$days günlük aralıkta izin kaydı bulunamadı.',
      icon:    Icons.event_available_rounded,
      color:   _color,
      onRefresh: _load,
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Map<int, String>     cNames;
  final Color                color;
  const _LogCard({required this.log, required this.cNames, required this.color});

  @override
  Widget build(BuildContext context) {
    final cId    = (log['courier_id'] ?? log['s_courier']) as num?;
    final name   = cNames[cId?.toInt() ?? 0] ?? (cId != null ? 'Kurye #${cId.toInt()}' : 'Bilinmeyen');
    final date   = log['date'] ?? log['s_date'];
    final reason = log['reason']?.toString() ?? log['note']?.toString() ?? '';

    return RCard(
      borderLeft: color,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.beach_access_rounded, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textHint),
            const SizedBox(width: 3),
            Text(date is DateTime ? DateFormat('dd.MM.yyyy', 'tr').format(date) : date?.toString() ?? '-',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(reason,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('İzin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}
