/// Tüm rapor sayfaları tarafından paylaşılan base widget'lar.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tarih formatlayıcılar
// ─────────────────────────────────────────────────────────────────────────────

final _dmyFmt  = DateFormat('dd.MM.yyyy', 'tr');
final _dmyhFmt = DateFormat('dd.MM.yyyy HH:mm', 'tr');

String fDate(DateTime? dt)   => dt == null ? '-' : _dmyFmt.format(dt);
String fDateTime(DateTime? dt) => dt == null ? '-' : _dmyhFmt.format(dt);

// ─────────────────────────────────────────────────────────────────────────────
// ReportScaffold — Tüm rapor sayfalarının ortak iskeleti
// ─────────────────────────────────────────────────────────────────────────────

class ReportScaffold extends StatefulWidget {
  final String         title;
  final Color          color;
  final IconData       icon;
  final DateTimeRange  range;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final VoidCallback   onRefresh;
  final bool           loading;
  final Widget         body;
  final List<Widget>?  extraActions;

  const ReportScaffold({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.range,
    required this.onRangeChanged,
    required this.onRefresh,
    required this.loading,
    required this.body,
    this.extraActions,
  });

  @override
  State<ReportScaffold> createState() => _ReportScaffoldState();
}

class _ReportScaffoldState extends State<ReportScaffold> {
  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate:          DateTime(2023),
      lastDate:           DateTime.now(),
      initialDateRange:   widget.range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:    widget.color,
            onPrimary:  Colors.white,
            surface:    AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (r != null && mounted) {
      widget.onRangeChanged(DateTimeRange(
        start: DateTime(r.start.year, r.start.month, r.start.day, 0,  0,  0),
        end:   DateTime(r.end.year,   r.end.month,   r.end.day,   23, 59, 59),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        elevation:       0,
        titleSpacing:    0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            margin:  const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        actions: [
          if (widget.extraActions != null) ...widget.extraActions!,
          IconButton(
            icon: widget.loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded),
            onPressed: widget.loading ? null : widget.onRefresh,
          ),
        ],
      ),
      body: Column(children: [
        // Tarih çubuğu
        _DateBar(range: widget.range, color: widget.color, onTap: _pickRange),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(child: widget.body),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarih çubuğu
// ─────────────────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final DateTimeRange range;
  final Color         color;
  final VoidCallback  onTap;

  const _DateBar({required this.range, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = range.end.difference(range.start).inDays + 1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.date_range_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${fDate(range.start)}  –  ${fDate(range.end)}  ($days gün)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_calendar_rounded, size: 11, color: color),
              const SizedBox(width: 3),
              Text('Değiştir',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yükleniyor
// ─────────────────────────────────────────────────────────────────────────────

class RLoading extends StatelessWidget {
  final Color color;
  const RLoading({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: 14),
          const Text('Veriler yükleniyor…',
              style: TextStyle(color: AppColors.textHint)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Boş durum
// ─────────────────────────────────────────────────────────────────────────────

class REmpty extends StatelessWidget {
  final String   message;
  final IconData icon;
  final Color    color;
  final VoidCallback? onRefresh;

  const REmpty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    required this.color,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: color.withAlpha(120)),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Farklı bir tarih aralığı seçmeyi deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(foregroundColor: color),
              ),
            ],
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hata durumu
// ─────────────────────────────────────────────────────────────────────────────

class RError extends StatelessWidget {
  final VoidCallback onRetry;
  const RError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Veri yüklenemedi',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('İnternet bağlantınızı kontrol edin.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Özet istatistik chip'i
// ─────────────────────────────────────────────────────────────────────────────

class RStat extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  const RStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textHint)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik satırı (yatay scroll)
// ─────────────────────────────────────────────────────────────────────────────

class RStatsRow extends StatelessWidget {
  final List<RStat> stats;
  const RStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stats
                .expand((s) => [s, const SizedBox(width: 8)])
                .toList(),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Kart container (her listedeki kart için)
// ─────────────────────────────────────────────────────────────────────────────

class RCard extends StatelessWidget {
  final Widget child;
  final Color? borderLeft;
  final VoidCallback? onTap;

  const RCard({super.key, required this.child, this.borderLeft, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: borderLeft != null
              ? Border(left: BorderSide(color: borderLeft!, width: 4))
              : null,
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                    padding: const EdgeInsets.all(12), child: child),
              )
            : Padding(padding: const EdgeInsets.all(12), child: child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Durum rozetleri  (siparişler için)
// ─────────────────────────────────────────────────────────────────────────────

Widget orderStatBadge(int stat) {
  final (label, color) = switch (stat) {
    0 => ('Hazır',         const Color(0xFF10B981)),
    1 => ('Yolda',         const Color(0xFF0891B2)),
    2 => ('Teslim',        const Color(0xFF276749)),
    3 => ('İptal',         const Color(0xFFEF4444)),
    4 => ('İşletmede',     const Color(0xFF6366F1)),
    5 => ('İade',          const Color(0xFFF59E0B)),
    _ => ('Bilinmeyen',    AppColors.textHint),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color)),
  );
}

Color orderStatColor(int stat) => switch (stat) {
      0 => const Color(0xFF10B981),
      1 => const Color(0xFF0891B2),
      2 => const Color(0xFF276749),
      3 => const Color(0xFFEF4444),
      4 => const Color(0xFF6366F1),
      5 => const Color(0xFFF59E0B),
      _ => AppColors.textHint,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Ödeme tipi etiketi
// ─────────────────────────────────────────────────────────────────────────────

Widget payTypeBadge(int type) {
  final (label, color) = switch (type) {
    0 => ('Nakit',        const Color(0xFF10B981)),
    1 => ('Kredi Kartı',  const Color(0xFF6366F1)),
    _ => ('Online',       const Color(0xFF0891B2)),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Kurye baş harfli avatar
// ─────────────────────────────────────────────────────────────────────────────

Widget courierAvatar(String name, Color color, {double size = 40}) {
  final initials = name.trim().split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      shape: BoxShape.circle,
      border: Border.all(color: color.withAlpha(80), width: 1.5),
    ),
    child: Center(
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.w800,
              color: color)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Para formatı
// ─────────────────────────────────────────────────────────────────────────────

String fMoney(double v) => '₺${v.toStringAsFixed(2)}';
String fMin(double v)   => '${v.toStringAsFixed(1)} dk';
