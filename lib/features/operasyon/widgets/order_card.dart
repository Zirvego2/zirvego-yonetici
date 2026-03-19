import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/order_color_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/order_model.dart';

// Randevulu sipariş banner renkleri
const _kScheduledBg = Color(0xFF4C1D95);     // derin mor
const _kScheduledLight = Color(0xFF7C3AED);  // açık mor
const _kScheduledOverdue = Color(0xFFC53030); // geçti → kırmızı

class OrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final bool isAssigned;

  /// Günlük sıra numarası (05:00'de sıfırlanır). null ise gösterilmez.
  final int? sequenceNumber;

  /// Atanan kuryenin adı. null ise ID gösterilir.
  final String? courierName;

  /// Siparişin geldiği işletmenin adı. null ise gösterilmez.
  final String? workName;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.isAssigned,
    this.sequenceNumber,
    this.courierName,
    this.workName,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;
  Timer? _elapsedTimer;
  int _elapsed = 0;

  // ── Servis referansı ───────────────────────────────────────────────────────
  final _colorSvc = OrderColorService.instance;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.order.elapsedMinutes;

    // repeat() başlangıçta çağrılmıyor; _updateBlinkState() gerektiğinde başlatır.
    // Bu sayede blink gerekmediği kartlarda (çoğunluk) ticker çalışmaz → CPU tasarrufu.
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _blinkAnim = Tween<double>(begin: 0.06, end: 0.38).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );

    _updateBlinkState();

    // Her 60 saniyede geçen süreyi güncelle (1dk gecikme kabul edilebilir;
    // kart sayısı fazla olduğunda gereksiz setState yükünü azaltır)
    _elapsedTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() => _elapsed = widget.order.elapsedMinutes);
        _updateBlinkState();
      }
    });
  }

  @override
  void didUpdateWidget(OrderCard old) {
    super.didUpdateWidget(old);
    _elapsed = widget.order.elapsedMinutes;
    _updateBlinkState();
  }

  void _updateBlinkState() {
    // Sadece atanmayan kartlar için son eşikte yanıp sönme
    final blink = !widget.isAssigned &&
        _colorSvc.isLastThreshold(elapsed: _elapsed, isAssigned: false);
    if (blink) {
      if (!_blinkCtrl.isAnimating) _blinkCtrl.repeat(reverse: true);
    } else {
      if (_blinkCtrl.isAnimating) _blinkCtrl.stop();
    }
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  // ── Randevulu Geri Sayım ───────────────────────────────────────────────────

  /// `sReadyTime`'a kalan süreyi döndürür. null → randevulu değil.
  Duration? get _scheduledRemaining {
    if (!widget.order.sIsScheduled) return null;
    final rt = widget.order.sReadyTime?.toDate();
    if (rt == null) return null;
    return rt.difference(DateTime.now());
  }

  /// Kalan süreyi okunabilir formatta döndürür.
  String _formatRemaining(Duration d) {
    if (d.isNegative || d.inSeconds <= 0) return 'Zamanı geldi!';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h saat ${m > 0 ? "$m dk" : ""}';
    if (m > 0) return '$m dk sonra';
    return 'Az kaldı!';
  }

  static const _trMonths = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
  ];

  /// Randevulu tarih/saati kısa biçimde döndürür (ör: "25 Mar · 14:30")
  String _formatScheduledDate() {
    final rt = widget.order.sReadyTime?.toDate();
    if (rt == null) return widget.order.sReadyTimeText ?? '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rtDay = DateTime(rt.year, rt.month, rt.day);
    final diff = rtDay.difference(today).inDays;
    final dayStr = diff == 0
        ? 'Bugün'
        : diff == 1
            ? 'Yarın'
            : '${rt.day} ${_trMonths[rt.month]}';
    final timeStr = DateFormat('HH:mm').format(rt);
    return '$dayStr · $timeStr';
  }

  // ── Renk Hesapları ─────────────────────────────────────────────────────────

  /// Kart arka planı / gölge / top-bar tonu için renk.
  ///
  /// • Atanan + Yolda (s_stat==1) → onRoadColor (kart renkli)
  /// • Atanan + diğer statüler    → nötr (kart rengi değişmez)
  /// • Atanmayan                  → eşik rengi
  Color get _activeColor {
    if (widget.isAssigned && widget.order.sStat == 1) {
      return _colorSvc.onRoadColor;
    }
    if (widget.isAssigned) {
      // Kartın rengi değişmez; nötr döndür
      return AppColors.surface;
    }
    return _colorSvc.colorFor(elapsed: _elapsed, isAssigned: false);
  }

  /// Sadece "Xdk" rozetinin rengi.
  ///
  /// • Atanan (Yolda dahil) → her zaman eşik rengi
  /// • Atanmayan            → kart rengiyle aynı (_activeColor)
  Color get _elapsedBadgeColor {
    if (widget.isAssigned) {
      return _colorSvc.colorFor(elapsed: _elapsed, isAssigned: true);
    }
    return _activeColor;
  }

  /// Son eşikte mi? (blink & kart vurgusu)
  /// Atanan kartlar için blink/vurgu devreye girmez.
  bool get _isLast {
    if (widget.isAssigned && widget.order.sStat != 1) return false;
    return _colorSvc.isLastThreshold(
        elapsed: _elapsed, isAssigned: widget.isAssigned);
  }

  @override
  Widget build(BuildContext context) {
    final color = _activeColor;
    final isLast = _isLast;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _blinkAnim,
        builder: (_, child) {
          final bgAlpha = (widget.isAssigned || !isLast)
              ? 14
              : (_blinkAnim.value * 255).toInt();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(bgAlpha),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isAssigned
                    ? AppColors.border
                    : color.withAlpha(isLast ? 130 : 90),
                width: isLast ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLast
                      ? color.withAlpha(55)
                      : AppColors.shadow,
                  blurRadius: isLast ? 10 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(color, isLast),
            if (widget.order.sIsScheduled) _buildScheduledBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İşletme adı chip (ID'nin üzerinde)
                  if (widget.workName != null &&
                      widget.workName!.isNotEmpty) ...[
                    _buildWorkNameChip(),
                    const SizedBox(height: 6),
                  ],

                  // Adres + sipariş ID
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${widget.order.sId}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                                fontFamily: 'Poppins',
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.order.sCustomer.ssAdres.isNotEmpty
                                  ? widget.order.sCustomer.ssAdres
                                  : 'Adres belirtilmemiş',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Müşteri + Ödeme
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.order.sCustomer.ssFullname.isNotEmpty
                                    ? widget.order.sCustomer.ssFullname
                                    : widget.order.sCustomer.ssPhone,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPaymentBadge(),
                    ],
                  ),

                  // Kurye + zaman (Atanan tab)
                  if (widget.isAssigned) ...[
                    const SizedBox(height: 6),
                    _buildAssignedCourierRow(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Randevulu Banner ──────────────────────────────────────────────────────

  Widget _buildScheduledBanner() {
    final remaining = _scheduledRemaining;
    final isOverdue = remaining == null || remaining.isNegative;
    final bg = isOverdue ? _kScheduledOverdue : _kScheduledBg;
    final bgLight = isOverdue ? const Color(0xFFE53E3E) : _kScheduledLight;
    final dateStr = _formatScheduledDate();
    final remainStr = remaining != null ? _formatRemaining(remaining) : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, bgLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          // İkon
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOverdue
                  ? Icons.alarm_on_rounded
                  : Icons.event_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),

          // Bilgi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık + "RANDEVULU" badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RANDEVULU',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withAlpha(230),
                          letterSpacing: 0.8,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Geri sayım chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(isOverdue ? 50 : 35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withAlpha(70), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOverdue
                      ? Icons.alarm_on_rounded
                      : Icons.timer_outlined,
                  size: 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  remainStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Üst Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(Color color, bool isLast) {
    final createTime = widget.order.sCdate != null
        ? DateFormat('HH:mm').format(widget.order.sCdate!)
        : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isAssigned
            ? AppColors.background
            : color.withAlpha(22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Günlük Sıra Numarası badge
          if (widget.sequenceNumber != null) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isAssigned
                      ? [AppColors.primary, AppColors.primaryLight]
                      : [color, color.withAlpha(190)],
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isAssigned ? AppColors.primary : color)
                        .withAlpha(55),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${widget.sequenceNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],

          // Platform badge
          _buildSourceBadge(),

          const Spacer(),

          // Durum badge
          _buildStatusBadge(),
          const SizedBox(width: 6),

          // Saat + süre
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: widget.isAssigned ? AppColors.textHint : color,
              ),
              const SizedBox(width: 3),
              Text(
                createTime,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isAssigned ? AppColors.textHint : color,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 5),
              // "Xdk" rozeti — atanan kartlarda rengi eşikten gelir
              Builder(builder: (_) {
                final badgeColor = _elapsedBadgeColor;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${_elapsed}dk',
                    style: TextStyle(
                      fontSize: 10,
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ── Platform badge ────────────────────────────────────────────────────────

  Widget _buildSourceBadge() {
    IconData icon;
    Color badgeColor;
    String label;

    switch (widget.order.sOrderscr) {
      case 1:
        icon = Icons.delivery_dining;
        badgeColor = const Color(0xFF5D3FD3);
        label = 'Getir';
        break;
      case 2:
        icon = Icons.restaurant_menu;
        badgeColor = const Color(0xFFE63946);
        label = 'Y.Sepeti';
        break;
      case 3:
        icon = Icons.shopping_bag_outlined;
        badgeColor = const Color(0xFFF27A1A);
        label = 'Trendyol';
        break;
      case 4:
        icon = Icons.store_outlined;
        badgeColor = const Color(0xFF0077B6);
        label = 'Migros';
        break;
      default:
        icon = Icons.edit_note_rounded;
        badgeColor = AppColors.textHint;
        label = 'Manuel';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                color: badgeColor,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Sipariş durum badge (Hazır / Yolda / İşletmede) ──────────────────────

  Widget _buildStatusBadge() {
    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (widget.order.sStat) {
      case 0: // Hazır
        bg = const Color(0xFFD1FAE5);
        border = const Color(0xFF34D399);
        textColor = const Color(0xFF065F46);
        icon = Icons.check_circle_rounded;
        break;
      case 1: // Yolda
        bg = const Color(0xFFDBEAFE);
        border = const Color(0xFF60A5FA);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.delivery_dining_rounded;
        break;
      case 4: // İşletmede
        bg = AppColors.warningLight;
        border = AppColors.warning;
        textColor = const Color(0xFF92400E);
        icon = Icons.store_rounded;
        break;
      default:
        bg = AppColors.background;
        border = AppColors.border;
        textColor = AppColors.textHint;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            widget.order.statusText,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ödeme badge ───────────────────────────────────────────────────────────

  Widget _buildPaymentBadge() {
    final pay = widget.order.sPay;
    final isNakit = pay.ssPaytype == 0;
    final color = isNakit ? AppColors.success : AppColors.info;
    final bg = isNakit ? AppColors.successLight : AppColors.infoLight;

    String amount = '';
    final raw = pay.ssPaycount;
    if (raw != null) {
      final num val = raw is num ? raw : num.tryParse(raw.toString()) ?? 0;
      if (val > 0) {
        amount = val % 1 == 0
            ? ' ₺${val.toInt()}'
            : ' ₺${val.toStringAsFixed(2)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment_outlined, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '${pay.payTypeName}$amount',
            style: TextStyle(
                fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── İşletme adı chip ─────────────────────────────────────────────────────

  Widget _buildWorkNameChip() {
    const chipColor = Color(0xFF0369A1); // koyu mavi
    const chipBg    = Color(0xFFE0F2FE); // açık mavi

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: chipColor.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded,
                  size: 12, color: chipColor),
              const SizedBox(width: 4),
              Text(
                widget.workName!,
                style: const TextStyle(
                  fontSize: 11,
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Atanan kurye satırı ───────────────────────────────────────────────────

  Widget _buildAssignedCourierRow() {
    final displayName = (widget.courierName != null &&
            widget.courierName!.isNotEmpty)
        ? widget.courierName!
        : 'Kurye #${widget.order.sCourier}';

    final assignedAt = widget.order.sAssignedTime != null
        ? DateFormat('HH:mm').format(widget.order.sAssignedTime!)
        : null;
    final onRoadAt = widget.order.sOnRoadTime != null
        ? DateFormat('HH:mm').format(widget.order.sOnRoadTime!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kurye adı + kabul saati
        Row(
          children: [
            const Icon(Icons.delivery_dining_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (assignedAt != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 10, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Kabul $assignedAt',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        // Yola çıkış saati
        if (onRoadAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_run_rounded,
                        size: 10, color: AppColors.info),
                    const SizedBox(width: 2),
                    Text(
                      'Yola çıktı $onRoadAt',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
