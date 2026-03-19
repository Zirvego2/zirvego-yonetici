import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/operation_service.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/courier_model.dart';

// Randevulu uyarı renkleri
const _kSchedPurple = Color(0xFF6D28D9);
const _kSchedPurpleLight = Color(0xFFEDE9FE);

// ── Kurye + hesaplanmış mesafe + sipariş özeti ───────────────────────────────
class _CourierWithDistance {
  final CourierModel courier;
  RouteDistance? distance;
  int orderCount;
  bool hasOnRoadOrder; // Yolda (s_stat==1) siparişi var mı?

  _CourierWithDistance({
    required this.courier,
    this.distance,
    this.orderCount = 0,
    this.hasOnRoadOrder = false,
  });

  /// Etkin durum kodu (siparişlere göre hesaplanır)
  int get effStatCode => courier.effectiveStatCode(
        orderCount: orderCount,
        hasOnRoadOrder: hasOnRoadOrder,
      );

  String get effStatusText => courier.effectiveStatusText(
        orderCount: orderCount,
        hasOnRoadOrder: hasOnRoadOrder,
      );
}

/// Kurye atama / sipariş detay bottom sheet
class AssignCourierSheet extends StatefulWidget {
  final OrderModel order;
  final int bayId;
  final VoidCallback? onAssigned;

  const AssignCourierSheet({
    super.key,
    required this.order,
    required this.bayId,
    this.onAssigned,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required int bayId,
    VoidCallback? onAssigned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignCourierSheet(
        order: order,
        bayId: bayId,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignCourierSheet> createState() => _AssignCourierSheetState();
}

class _AssignCourierSheetState extends State<AssignCourierSheet> {
  final _service = OperationService.instance;

  List<_CourierWithDistance> _couriers = [];
  bool _loading = true;
  bool _assigning = false;
  String? _error;

  /// Teslimatçının gideceği varış noktası (işletme konumu)
  GeoPoint? _pickupLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ── Paralel: işletme konumu + aktif kuryeler + bay bazlı sipariş detayları ──
      final pickupFuture   = _service.fetchWorkLocation(widget.order.sWork);
      final couriersFuture = _service.fetchActiveCouriers(widget.bayId);
      final ordersFuture   = _service.fetchCourierOrderDetailsBatch(widget.bayId);

      // Hepsini aynı anda bekle (3 Firestore sorgusu paralel çalışır)
      final pickupLoc    = await pickupFuture;
      final couriers     = await couriersFuture;
      final orderDetails = await ordersFuture;

      if (!mounted) return;
      _pickupLocation = pickupLoc;

      // Her kurye için birleşik model oluştur
      final withDist = couriers.map((c) {
        final detail = orderDetails[c.sId];
        return _CourierWithDistance(
          courier: c,
          orderCount: detail?.count ?? 0,
          hasOnRoadOrder: detail?.hasOnRoad ?? false,
        );
      }).toList()
        // Etkin duruma göre sırala: Müsait→Meşgul→Yolda→Molada→Kaza
        ..sort((a, b) {
          const order = {1: 0, 2: 1, 5: 2, 3: 3, 4: 4};
          return (order[a.effStatCode] ?? 9)
              .compareTo(order[b.effStatCode] ?? 9);
        });

      setState(() {
        _couriers = withDist;
        _loading = false;
      });

      // Mesafeleri arka planda TEK bir API çağrısıyla hesapla
      _calculateDistancesBatch(withDist, pickupLoc);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kuryeler yüklenemedi: $e';
          _loading = false;
        });
      }
    }
  }

  /// Tüm kuryeler için mesafeyi TEK bir Distance Matrix API çağrısıyla hesaplar.
  Future<void> _calculateDistancesBatch(
    List<_CourierWithDistance> list,
    GeoPoint? pickup,
  ) async {
    if (pickup == null || list.isEmpty) return;

    final origins = list.map((item) => item.courier.parsedLocation).toList();

    final distances = await _service.calculateBatchDistances(
      origins: origins,
      toLat: pickup.latitude,
      toLng: pickup.longitude,
    );

    if (!mounted) return;
    setState(() {
      for (int i = 0; i < list.length && i < distances.length; i++) {
        if (distances[i] != null) {
          list[i].distance = distances[i];
        }
      }
    });
  }

  Future<void> _assign(CourierModel courier) async {
    // Randevulu sipariş kontrolü → onay dialogu göster
    if (widget.order.sIsScheduled) {
      final confirmed = await _showScheduledConfirmDialog(courier);
      if (!confirmed) return;
    }

    setState(() => _assigning = true);
    final ok = await _service.assignCourier(
      orderDocId: widget.order.docId,
      courierId: courier.sId,
      courierToken: courier.pushToken,
      orderName: widget.order.sId.toString(),
      previousCourierId: widget.order.sCourier, // 0 = atanmamış, >0 = yeniden atama
    );
    if (!mounted) return;

    if (ok) {
      widget.onAssigned?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ #${widget.order.sId} → ${courier.fullName} atandı'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _assigning = false;
        _error = 'Atama işlemi başarısız. Tekrar deneyin.';
      });
    }
  }

  // ── Randevulu sipariş onay dialogu ───────────────────────────────────────

  Future<bool> _showScheduledConfirmDialog(CourierModel courier) async {
    final readyTime = widget.order.sReadyTime?.toDate();
    final remaining = readyTime != null
        ? readyTime.difference(DateTime.now())
        : null;

    final isOverdue = remaining == null || remaining.isNegative;

    // Kalan süre metni
    String remainText;
    if (isOverdue) {
      remainText = 'Randevu zamanı geldi / geçti!';
    } else {
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      if (h > 0) {
        remainText = '$h saat${m > 0 ? ' $m dakika' : ''} kaldı';
      } else if (m > 0) {
        remainText = '$m dakika kaldı';
      } else {
        remainText = 'Az kaldı!';
      }
    }

    // Tarih/saat metni
    String dateText = '—';
    if (readyTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rtDay = DateTime(readyTime.year, readyTime.month, readyTime.day);
      final diff = rtDay.difference(today).inDays;
      final dayStr = diff == 0
          ? 'Bugün'
          : diff == 1
              ? 'Yarın'
              : DateFormat('d MMMM', 'tr_TR').format(readyTime);
      dateText = '$dayStr  •  ${DateFormat('HH:mm').format(readyTime)}';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst başlık bandı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4C1D95), _kSchedPurple],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Randevulu Sipariş',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Column(
                children: [
                  // Tarih/saat kutusu
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _kSchedPurpleLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kSchedPurple.withAlpha(60)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 16,
                                color: isOverdue
                                    ? AppColors.error
                                    : _kSchedPurple),
                            const SizedBox(width: 6),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isOverdue
                                    ? AppColors.error
                                    : _kSchedPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? AppColors.errorLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOverdue
                                  ? AppColors.error.withAlpha(80)
                                  : _kSchedPurple.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOverdue
                                    ? Icons.alarm_on_rounded
                                    : Icons.timer_outlined,
                                size: 13,
                                color: isOverdue
                                    ? AppColors.error
                                    : _kSchedPurple,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                remainText,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isOverdue
                                      ? AppColors.error
                                      : _kSchedPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Soru
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5),
                      children: [
                        TextSpan(
                          text: courier.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                            text:
                                ' kuryesine şimdi atamak istiyor musunuz?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // İptal
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textHint,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('İptal',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          // Ata
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Evet, Ata',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSchedPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _unassign() async {
    setState(() => _assigning = true);
    final ok = await _service.unassignCourier(
      orderDocId: widget.order.docId,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Kurye ataması kaldırıldı'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _assigning = false;
        _error = 'İşlem başarısız. Tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Sipariş Özeti ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildOrderSummary(order),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider, height: 1),

              // ── İçerik ──────────────────────────────────
              Expanded(
                child: _assigning
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: AppColors.primary),
                            SizedBox(height: 12),
                            Text('İşlem yapılıyor...',
                                style:
                                    TextStyle(color: AppColors.textHint)),
                          ],
                        ),
                      )
                    : _buildContent(scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Sipariş özet kartı ────────────────────────────────────────────────────
  Widget _buildOrderSummary(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Row(
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 17, color: AppColors.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '#${order.sId}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(order),
            const SizedBox(width: 8),
            _infoChip(
              '${order.elapsedMinutes} dk',
              Icons.access_time_rounded,
              AppColors.warningLight,
              AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Detay satırları
        _detailRow(Icons.person_outline,
            order.sCustomer.ssFullname.isNotEmpty
                ? order.sCustomer.ssFullname
                : '—'),
        const SizedBox(height: 4),
        _detailRow(Icons.phone_outlined, order.sCustomer.ssPhone),
        const SizedBox(height: 4),
        _detailRow(Icons.location_on_outlined, order.sCustomer.ssAdres),
        const SizedBox(height: 4),
        Row(
          children: [
            _infoChip(
              order.sPay.payTypeName,
              Icons.payment_outlined,
              AppColors.infoLight,
              AppColors.info,
            ),
            const SizedBox(width: 8),
            _infoChip(
              order.orderSourceName,
              Icons.storefront_outlined,
              AppColors.background,
              AppColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(OrderModel order) {
    Color bg;
    Color fg;
    switch (order.sStat) {
      case 0:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 1:
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
      case 4:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      default:
        bg = AppColors.background;
        fg = AppColors.textHint;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(order.statusText,
          style: TextStyle(
              fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoChip(String text, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Liste içeriği ────────────────────────────────────────────────────────
  Widget _buildContent(ScrollController scrollCtrl) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 44, color: AppColors.error),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _loadData,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Atama kaldır butonu
          if (widget.order.isAssigned)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: OutlinedButton.icon(
                onPressed: _unassign,
                icon: const Icon(Icons.person_remove_outlined,
                    color: AppColors.error, size: 18),
                label: const Text('Kurye Atamasını Kaldır',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),

          // Başlık + kurye sayısı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Text(
                  'Kuryeler',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!_loading && _couriers.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_couriers.length} aktif',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_pickupLocation == null && !_loading)
                  const Text(
                    '⚠️ Pickup konumu yok',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textHint),
                  ),
              ],
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_couriers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.delivery_dining_outlined,
                        size: 52, color: AppColors.textHint),
                    SizedBox(height: 10),
                    Text(
                      'Aktif kurye bulunamadı',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: _couriers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _courierTile(_couriers[i]),
            ),
        ],
      ),
    );
  }

  Widget _courierTile(_CourierWithDistance item) {
    final courier = item.courier;
    final effCode = item.effStatCode;
    final statusColor = _statusColor(effCode);
    final statusBg = _statusBg(effCode);

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _assign(courier),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 21,
                backgroundColor: statusColor.withAlpha(28),
                child: Text(
                  courier.fullName.isNotEmpty
                      ? courier.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // İsim + ID + hız + paket sayısı
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İsim satırı
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            courier.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Üzerindeki paket sayısı badge
                        _packageCountBadge(item.orderCount),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'ID: ${courier.sId}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                        // Hız bilgisi varsa göster
                        if (courier.parsedLocation?.speed != null &&
                            (courier.parsedLocation!.speed) > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${courier.parsedLocation!.speed.toStringAsFixed(0)} km/h',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Sağ: Durum + Mesafe
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Etkin durum etiketi (sipariş bazlı hesaplanır)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusColor.withAlpha(80), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(effCode), size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          item.effStatusText,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Rota mesafesi
                  _buildDistanceBadge(item),
                ],
              ),

              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Kuryenin üzerindeki aktif paket sayısı badge'i
  Widget _packageCountBadge(int count) {
    if (count == 0) {
      return const SizedBox.shrink();
    }
    // Yük arttıkça renk koyulaşır: 1=yeşil, 2-3=turuncu, 4+=kırmızı
    final Color bg;
    final Color fg;
    if (count == 1) {
      bg = AppColors.successLight;
      fg = AppColors.success;
    } else if (count <= 3) {
      bg = AppColors.warningLight;
      fg = AppColors.warning;
    } else {
      bg = AppColors.errorLight;
      fg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            '$count paket',
            style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBadge(_CourierWithDistance item) {
    final loc = item.courier.parsedLocation;

    // Konum yoksa
    if (loc == null) {
      return const Text(
        'Konum yok',
        style: TextStyle(fontSize: 10.5, color: AppColors.textHint),
      );
    }

    // Pickup konumu yoksa
    if (_pickupLocation == null) {
      return const Text(
        '—',
        style: TextStyle(fontSize: 11, color: AppColors.textHint),
      );
    }

    // Mesafe hesaplanıyor
    if (item.distance == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.textHint,
        ),
      );
    }

    final dist = item.distance!;
    final icon =
        dist.isRouteBased ? Icons.route_rounded : Icons.straighten_rounded;
    final color =
        dist.km < 1.5 ? AppColors.success : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          dist.displayText,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Etkin statü renk / ikon yardımcıları ─────────────────────────────────
  // effCode: 1=Müsait 2=Meşgul 3=Molada 4=Kaza 5=Yolda

  Color _statusColor(int effCode) {
    switch (effCode) {
      case 1: return AppColors.success;           // Müsait — yeşil
      case 2: return const Color(0xFF5964FF);     // Meşgul — mavi-mor
      case 3: return AppColors.warning;           // Molada — turuncu
      case 4: return AppColors.error;             // Kaza   — kırmızı
      case 5: return const Color(0xFF6D28D9);     // Yolda  — mor
      default: return AppColors.textHint;
    }
  }

  Color _statusBg(int effCode) {
    switch (effCode) {
      case 1: return AppColors.successLight;
      case 2: return const Color(0xFFEEEFFF);
      case 3: return AppColors.warningLight;
      case 4: return AppColors.errorLight;
      case 5: return const Color(0xFFEDE9FE);     // Yolda — açık mor
      default: return AppColors.background;
    }
  }

  IconData _statusIcon(int effCode) {
    switch (effCode) {
      case 1: return Icons.check_circle_outline_rounded;  // Müsait
      case 2: return Icons.inventory_2_outlined;          // Meşgul
      case 3: return Icons.pause_circle_outline_rounded;  // Molada
      case 4: return Icons.warning_amber_rounded;         // Kaza
      case 5: return Icons.delivery_dining_rounded;       // Yolda
      default: return Icons.circle_outlined;
    }
  }
}
