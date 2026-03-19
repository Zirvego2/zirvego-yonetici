import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/operation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/courier_model.dart';
import '../../shared/models/order_model.dart';
import '../operasyon/widgets/assign_courier_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Harita Sekmesi — Yeniden Yazıldı
//
// Layout  : Tam ekran GoogleMap + altta DraggableScrollableSheet
// Veriler : watchAllActiveOrders (s_bay+s_stat index) — anlık
//           watchActiveCouriersStream — anlık
//           watchDailySequences — anlık
//           fetchWorkInfos — tek seferlik
//
// Sekmeler: Tümü / Bekleyen / Atanan / Yolda / Randevulu
// Dokunma : sipariş kartına tek dokunuş → haritada odakla
//           uzun basış → kurye atama sayfası
//           kurye marker'ına dokunuş → kurye bilgi paneli
// ─────────────────────────────────────────────────────────────────────────────

// ── Tab tanımı ────────────────────────────────────────────────────────────────

enum _Tab { all, pending, assigned, onRoad, scheduled }

extension _TabX on _Tab {
  String get label {
    switch (this) {
      case _Tab.all:       return 'Tümü';
      case _Tab.pending:   return 'Bekleyen';
      case _Tab.assigned:  return 'Atanan';
      case _Tab.onRoad:    return 'Yolda';
      case _Tab.scheduled: return 'Randevulu';
    }
  }

  Color get color {
    switch (this) {
      case _Tab.all:       return const Color(0xFF6B7280);
      case _Tab.pending:   return const Color(0xFF10B981);
      case _Tab.assigned:  return const Color(0xFF3B82F6);
      case _Tab.onRoad:    return const Color(0xFFF59E0B);
      case _Tab.scheduled: return const Color(0xFF9333EA);
    }
  }
}

// ── Ana widget ────────────────────────────────────────────────────────────────

class HaritaScreen extends StatefulWidget {
  const HaritaScreen({super.key});

  @override
  State<HaritaScreen> createState() => _HaritaScreenState();
}

class _HaritaScreenState extends State<HaritaScreen> {
  // Servisler
  final _service = OperationService.instance;
  int get _bayId => AuthService.instance.currentUser?.sId ?? 0;

  // Harita
  GoogleMapController? _mapController;

  // Veriler
  List<OrderModel>   _orders   = [];
  List<CourierModel> _couriers = [];
  List<WorkInfo>     _works    = [];
  Map<String, int>   _seqMap   = {};
  Map<int, String>   _courierNames = {};

  // Stream abonelikleri
  StreamSubscription<List<OrderModel>>?   _ordersSub;
  StreamSubscription<List<CourierModel>>? _couriersSub;
  StreamSubscription<Map<String, int>>?   _seqSub;

  // Marker state
  Set<Marker> _markers    = {};
  bool        _mkBuilding = false;
  Timer?      _mkTimer;

  /// Marker ikon cache'i — aynı renk+metin kombinasyonu için bitmap yeniden oluşturulmaz.
  /// Key formatı: "order_{colorValue}_{seqText}_{isSelected}" veya
  ///              "courier_{colorValue}_{initials}_{pkgCount}"  veya
  ///              "work_{initial}"
  /// Sınır: 200 girdi — aşılırsa en eski half temizlenir (bellek önlemi).
  final Map<String, BitmapDescriptor> _iconCache = {};

  void _cacheSet(String key, BitmapDescriptor icon) {
    if (_iconCache.length >= 200) {
      // En eski 100 girdiyi temizle (FIFO — insertion order korunur)
      final toRemove = _iconCache.keys.take(100).toList();
      for (final k in toRemove) {
        _iconCache.remove(k);
      }
    }
    _iconCache[key] = icon;
  }

  // UI state
  _Tab       _activeTab  = _Tab.all;
  String?    _selOrderId;   // seçili sipariş docId
  bool       _loading    = true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_bayId == 0) return;
    _startStreams();
    _loadWorks();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _couriersSub?.cancel();
    _seqSub?.cancel();
    _mkTimer?.cancel();
    _mapController?.dispose();
    _iconCache.clear();
    super.dispose();
  }

  // ── Stream kurulumu ────────────────────────────────────────────────────────

  void _startStreams() {
    // Siparişler — mevcut s_bay+s_stat composite index kullanılır
    _ordersSub = _service.watchAllActiveOrders(_bayId).listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders
            ..sort((a, b) =>
                (b.sCdate ?? DateTime(0)).compareTo(a.sCdate ?? DateTime(0)));
          _loading = false;
        });
        _schedMk();
      },
      onError: (e) {
        debugPrint('[HaritaScreen] Sipariş stream hatası: $e');
        if (mounted) setState(() => _loading = false);
      },
    );

    // Kuryeler
    _couriersSub = _service.watchActiveCouriersStream(_bayId).listen(
      (couriers) {
        if (!mounted) return;
        setState(() {
          _couriers     = couriers;
          _courierNames = {for (final c in couriers) c.sId: c.fullName};
        });
        _schedMk();
      },
      onError: (e) => debugPrint('[HaritaScreen] Kurye stream hatası: $e'),
    );

    // Sıra numaraları
    _seqSub = _service.watchDailySequences(_bayId).listen(
      (map) {
        if (!mounted) return;
        setState(() => _seqMap = map);
        _schedMk();
      },
      onError: (e) => debugPrint('[HaritaScreen] Sıra stream hatası: $e'),
    );
  }

  Future<void> _loadWorks() async {
    try {
      final works = await _service.fetchWorkInfos(_bayId);
      if (!mounted) return;
      setState(() => _works = works);
      _schedMk();
    } catch (e) {
      debugPrint('[HaritaScreen] İşletmeler yüklenemedi: $e');
    }
  }

  // ── Marker yönetimi ────────────────────────────────────────────────────────

  void _schedMk() {
    _mkTimer?.cancel();
    _mkTimer = Timer(const Duration(milliseconds: 250), _rebuildMarkers);
  }

  Future<void> _rebuildMarkers() async {
    if (_mkBuilding || !mounted) return;
    _mkBuilding = true;

    final newMarkers = <Marker>{};
    final displayed  = _filteredOrders;

    // Sipariş marker'ları
    for (final order in displayed) {
      final loc = order.sCustomer.ssLoc;
      if (loc == null) continue;
      try {
        final icon = await _orderIcon(order);
        newMarkers.add(Marker(
          markerId: MarkerId('o_${order.docId}'),
          position: LatLng(loc.latitude, loc.longitude),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _onOrderTap(order),
        ));
      } catch (_) {}
    }

    // Kurye marker'ları
    for (final c in _couriers) {
      final loc = c.parsedLocation;
      if (loc == null) continue;
      try {
        final cOrders     = _orders.where((o) => o.sCourier == c.sId).toList();
        final hasOnRoad   = cOrders.any((o) => o.sStat == 1);
        final icon        = await _courierIcon(c, cOrders.length, hasOnRoad);
        newMarkers.add(Marker(
          markerId: MarkerId('c_${c.sId}'),
          position: LatLng(loc.lat, loc.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showCourierPanel(c, cOrders),
        ));
      } catch (_) {}
    }

    // İşletme marker'ları (konumu olmayan işletmeler haritada gösterilmez)
    for (final w in _works) {
      if (w.location == null) continue;
      try {
        final icon = await _workIcon(w.name);
        newMarkers.add(Marker(
          markerId: MarkerId('w_${w.id}'),
          position: LatLng(w.location!.latitude, w.location!.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
        ));
      } catch (_) {}
    }

    _mkBuilding = false;
    if (mounted) setState(() => _markers = newMarkers);
  }

  // ── Filtrelenmiş sipariş listesi ───────────────────────────────────────────

  List<OrderModel> get _filteredOrders {
    switch (_activeTab) {
      case _Tab.all:       return _orders;
      case _Tab.pending:   return _orders.where((o) => o.sCourier == 0).toList();
      case _Tab.assigned:  return _orders.where((o) => o.sCourier > 0 && o.sStat == 0).toList();
      case _Tab.onRoad:    return _orders.where((o) => o.sStat == 1).toList();
      case _Tab.scheduled: return _orders.where((o) => o.sIsScheduled).toList();
    }
  }

  int _count(_Tab t) {
    switch (t) {
      case _Tab.all:       return _orders.length;
      case _Tab.pending:   return _orders.where((o) => o.sCourier == 0).length;
      case _Tab.assigned:  return _orders.where((o) => o.sCourier > 0 && o.sStat == 0).length;
      case _Tab.onRoad:    return _orders.where((o) => o.sStat == 1).length;
      case _Tab.scheduled: return _orders.where((o) => o.sIsScheduled).length;
    }
  }

  // ── Marker dokunma işlemleri ───────────────────────────────────────────────

  void _onOrderTap(OrderModel order) {
    final prevId = _selOrderId;
    setState(() => _selOrderId = order.docId);

    // Seçici cache temizliği: sadece ETKİLENEN 2 girdi kaldırılır (~150 değil).
    // ① Önceki seçili sipariş:  '_true' ile biten cache girdisini sil
    if (prevId != null && prevId != order.docId) {
      final prevList = _orders.where((o) => o.docId == prevId).toList();
      if (prevList.isNotEmpty) {
        final prev  = prevList.first;
        final pCol  = _orderColor(prev);
        final pLbl  = (_seqMap[prevId] ?? 0).toString();
        _iconCache.remove('order_${pCol.value}_${pLbl}_true');
      }
    }
    // ② Yeni seçilen sipariş: '_false' ile biten cache girdisini sil
    final nCol = _orderColor(order);
    final nLbl = (_seqMap[order.docId] ?? 0).toString();
    _iconCache.remove('order_${nCol.value}_${nLbl}_false');

    final loc = order.sCustomer.ssLoc;
    if (loc != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 16),
      );
    }
    _schedMk();
  }

  void _showCourierPanel(CourierModel courier, List<OrderModel> cOrders) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourierPanel(
        courier:    courier,
        orders:     cOrders,
        seqMap:     _seqMap,
        allOrders:  _orders,
      ),
    );
  }

  // ── Marker çiziciler ───────────────────────────────────────────────────────

  Color _orderColor(OrderModel o) {
    if (o.sIsScheduled && o.sCourier == 0) return const Color(0xFF9333EA);
    if (o.sCourier == 0) return const Color(0xFF10B981); // bekleyen → yeşil
    if (o.sStat == 1)    return const Color(0xFFF59E0B); // yolda → sarı
    return const Color(0xFF3B82F6); // atanan → mavi
  }

  Future<BitmapDescriptor> _orderIcon(OrderModel order) async {
    final color    = _orderColor(order);
    final isSelect = order.docId == _selOrderId;
    final label    = _seqMap[order.docId]?.toString() ?? '?';
    final cacheKey = 'order_${color.value}_${label}_$isSelect';

    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    const sz = 38.0; // Küçültüldü (46→38) — bellek tasarrufu
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    final fill = Paint()..color = isSelect ? Colors.white : color;
    final ring = Paint()
      ..color       = isSelect ? color : Colors.white.withAlpha(220)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = isSelect ? 2.5 : 1.5;

    canvas.drawCircle(const Offset(sz / 2, sz / 2), sz / 2 - 1.5, fill);
    canvas.drawCircle(const Offset(sz / 2, sz / 2), sz / 2 - 1.5, ring);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelect ? color : Colors.white,
          fontSize: label.length > 2 ? 10 : 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sz / 2 - tp.width / 2, sz / 2 - tp.height / 2));

    final img   = await recorder.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose(); // dart:ui.Image kaynağını hemen serbest bırak
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cacheSet(cacheKey, icon);
    return icon;
  }

  Color _courierColor(CourierModel c, int cnt, bool hasOnRoad) {
    final code = c.effectiveStatCode(orderCount: cnt, hasOnRoadOrder: hasOnRoad);
    switch (code) {
      case 1: return const Color(0xFF10B981); // müsait  → yeşil
      case 2: return const Color(0xFF5964FF); // meşgul  → mor-mavi
      case 3: return const Color(0xFFF59E0B); // molada  → sarı
      case 4: return const Color(0xFFEF4444); // kaza    → kırmızı
      case 5: return const Color(0xFF0891B2); // yolda   → cyan
      default: return const Color(0xFF6B7280);
    }
  }

  Future<BitmapDescriptor> _courierIcon(
      CourierModel c, int cnt, bool hasOnRoad) async {
    final color    = _courierColor(c, cnt, hasOnRoad);
    final initials = c.fullName.isNotEmpty
        ? c.fullName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : '?';
    final cacheKey = 'courier_${color.value}_${initials}_$cnt';

    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    const sz = 44.0; // Küçültüldü (52→44) — bellek tasarrufu
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    // Dış halka (ince)
    canvas.drawCircle(const Offset(sz / 2, sz / 2), sz / 2,
        Paint()..color = color.withAlpha(60));
    // İç daire
    canvas.drawCircle(const Offset(sz / 2, sz / 2), sz / 2 - 4,
        Paint()..color = color);

    // Baş harfler
    final tp = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sz / 2 - tp.width / 2, sz / 2 - tp.height / 2));

    // Paket sayısı rozeti (sadece cnt > 0 ise)
    if (cnt > 0) {
      const r = 8.0;
      const cx = sz - r - 1;
      const cy = r + 1;
      canvas.drawCircle(
          const Offset(cx, cy), r, Paint()..color = Colors.white);
      canvas.drawCircle(
          const Offset(cx, cy), r - 1.5,
          Paint()..color = const Color(0xFFEF4444));
      final np = TextPainter(
        text: TextSpan(
          text: '$cnt',
          style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      np.paint(canvas, Offset(cx - np.width / 2, cy - np.height / 2));
    }

    final img   = await recorder.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose(); // dart:ui.Image kaynağını hemen serbest bırak
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cacheSet(cacheKey, icon);
    return icon;
  }

  Future<BitmapDescriptor> _workIcon(String name) async {
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : 'İ';
    final cacheKey = 'work_$initial';

    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    const sz = 32.0; // Küçültüldü (38→32)
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 1, sz - 2, sz - 2), const Radius.circular(6)),
      Paint()..color = const Color(0xFFFF6B35),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: initial,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sz / 2 - tp.width / 2, sz / 2 - tp.height / 2));

    final img   = await recorder.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cacheSet(cacheKey, icon);
    return icon;
  }

  // ── Başlangıç kamera konumu ────────────────────────────────────────────────

  LatLng get _initPos {
    final gp = AuthService.instance.currentUser?.sLoc.ssLocationGeoPoint;
    if (gp != null) return LatLng(gp.latitude, gp.longitude);
    final firstWithLoc = _works.firstWhere(
      (w) => w.location != null,
      orElse: () => const WorkInfo(id: 0, name: ''),
    );
    if (firstWithLoc.location != null) {
      return LatLng(firstWithLoc.location!.latitude, firstWithLoc.location!.longitude);
    }
    return const LatLng(39.9334, 32.8597); // Ankara
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Google Harita ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _initPos, zoom: 13),
            onMapCreated: (ctrl) => _mapController = ctrl,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) {
              if (_selOrderId != null) {
                setState(() => _selOrderId = null);
                _schedMk();
              }
            },
          ),

          // ── Yükleniyor göstergesi (ilk açılışta) ─────────────────────────
          if (_loading)
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 8),
                        Text('Yükleniyor…',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Alt panel (sipariş listesi) ───────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.33,
            minChildSize: 0.12,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.12, 0.33, 0.92],
            builder: (ctx, scrollCtrl) => _BottomPanel(
              orders:       _filteredOrders,
              allOrders:    _orders,
              couriers:     _couriers,
              seqMap:       _seqMap,
              courierNames: _courierNames,
              activeTab:    _activeTab,
              selOrderId:   _selOrderId,
              count:        _count,
              scrollCtrl:   scrollCtrl,
              bayId:        _bayId,
              onTabChange: (t) {
                setState(() => _activeTab = t);
                _schedMk();
              },
              onOrderTap: _onOrderTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt Panel (DraggableScrollableSheet içeriği)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final List<OrderModel>   orders;
  final List<OrderModel>   allOrders;
  final List<CourierModel> couriers;
  final Map<String, int>   seqMap;
  final Map<int, String>   courierNames;
  final _Tab               activeTab;
  final String?            selOrderId;
  final int Function(_Tab) count;
  final ScrollController   scrollCtrl;
  final int                bayId;
  final void Function(_Tab)                 onTabChange;
  final void Function(OrderModel)           onOrderTap;

  const _BottomPanel({
    required this.orders,
    required this.allOrders,
    required this.couriers,
    required this.seqMap,
    required this.courierNames,
    required this.activeTab,
    required this.selOrderId,
    required this.count,
    required this.scrollCtrl,
    required this.bayId,
    required this.onTabChange,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x28000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        children: [
          // Sürükleme tutacağı
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Tab çubuğu
          _TabBar(activeTab: activeTab, count: count, onTabChange: onTabChange),

          const Divider(height: 1, color: AppColors.divider),

          // Sipariş listesi
          Expanded(
            child: orders.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _OrderCard(
                      order:       orders[i],
                      seqNo:       seqMap[orders[i].docId],
                      courierName: courierNames[orders[i].sCourier],
                      isSelected:  orders[i].docId == selOrderId,
                      bayId:       bayId,
                      onTap:       () => onOrderTap(orders[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text('Bu kategoride sipariş yok',
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Çubuğu
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final _Tab               activeTab;
  final int Function(_Tab) count;
  final void Function(_Tab) onTabChange;

  const _TabBar({
    required this.activeTab,
    required this.count,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: _Tab.values.map((tab) {
          final isActive = tab == activeTab;
          final n        = count(tab);
          return GestureDetector(
            onTap: () => onTabChange(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 7),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color:  isActive ? tab.color : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isActive ? tab.color : AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withAlpha(45)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : tab.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sipariş Kartı (liste içinde)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final int?       seqNo;
  final String?    courierName;
  final bool       isSelected;
  final int        bayId;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.seqNo,
    required this.courierName,
    required this.isSelected,
    required this.bayId,
    required this.onTap,
  });

  Color get _markerColor {
    if (order.sIsScheduled && order.sCourier == 0) return const Color(0xFF9333EA);
    if (order.sCourier == 0) return const Color(0xFF10B981);
    if (order.sStat == 1)    return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = order.sCdate != null
        ? DateTime.now().difference(order.sCdate!).inMinutes
        : 0;

    Color elapsedColor = const Color(0xFF10B981);
    if (elapsed >= 20)      elapsedColor = const Color(0xFFEF4444);
    else if (elapsed >= 10) elapsedColor = const Color(0xFFF59E0B);

    // Statü renk ve metin
    Color  statColor;
    String statText;
    switch (order.sStat) {
      case 0: statColor = const Color(0xFF10B981); statText = 'Hazır';      break;
      case 1: statColor = const Color(0xFFF59E0B); statText = 'Yolda';      break;
      case 4: statColor = const Color(0xFFF59E0B); statText = 'İşletmede'; break;
      default: statColor = AppColors.textHint;     statText = order.statusText;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: () =>
          AssignCourierSheet.show(context, order: order, bayId: bayId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? _markerColor.withAlpha(18)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _markerColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              // Sıra no rozeti
              Container(
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _markerColor, shape: BoxShape.circle),
                child: Text(
                  seqNo != null ? '$seqNo' : '?',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 9),

              // Orta bilgi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Adres
                    Text(
                      order.sCustomer.ssAdres,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Alt satır: statü + kurye
                    Row(
                      children: [
                        _badge(statText, statColor),
                        const SizedBox(width: 6),
                        if (courierName != null) ...[
                          const Icon(Icons.delivery_dining_rounded,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              courierName!,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          Text('Atanmadı',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFFEF4444).withAlpha(200))),
                      ],
                    ),
                  ],
                ),
              ),

              // Sağ: saat + süre
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.sCdate != null)
                    Text(
                      DateFormat('HH:mm').format(order.sCdate!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: elapsedColor.withAlpha(22),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      '${elapsed}dk',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: elapsedColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:  color.withAlpha(22),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Kurye Bilgi Paneli (modal bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _CourierPanel extends StatelessWidget {
  final CourierModel       courier;
  final List<OrderModel>   orders;    // Bu kuryenin siparişleri
  final Map<String, int>   seqMap;
  final List<OrderModel>   allOrders; // effectiveStatCode için

  const _CourierPanel({
    required this.courier,
    required this.orders,
    required this.seqMap,
    required this.allOrders,
  });

  int get _cnt       => orders.length;
  bool get _hasRoad  => orders.any((o) => o.sStat == 1);

  Color get _color {
    final code = courier.effectiveStatCode(
        orderCount: _cnt, hasOnRoadOrder: _hasRoad);
    switch (code) {
      case 1: return const Color(0xFF10B981);
      case 2: return const Color(0xFF5964FF);
      case 3: return const Color(0xFFF59E0B);
      case 4: return const Color(0xFFEF4444);
      case 5: return const Color(0xFF0891B2);
      default: return const Color(0xFF6B7280);
    }
  }

  String get _statusText => courier.effectiveStatusText(
      orderCount: _cnt, hasOnRoadOrder: _hasRoad);

  String get _initials => courier.fullName.isNotEmpty
      ? courier.fullName
          .split(' ')
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0])
          .join()
          .toUpperCase()
      : '?';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Kurye bilgisi
          Row(
            children: [
              // Avatar
              Container(
                width: 52, height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courier.fullName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _statusChip(_statusText, _color),
                        const SizedBox(width: 8),
                        Text('$_cnt paket',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Siparişler listesi
          if (orders.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final o      = orders[i];
                  final seqNo  = seqMap[o.docId];
                  final isRoad = o.sStat == 1;
                  final color  = isRoad
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF3B82F6);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                          child: Text(
                            seqNo != null ? '$seqNo' : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            o.sCustomer.ssAdres,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          o.statusText,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:  color.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}
