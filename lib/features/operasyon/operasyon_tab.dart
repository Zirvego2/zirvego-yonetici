import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/operation_service.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/courier_model.dart';
import 'widgets/order_card.dart';
import 'widgets/assign_courier_sheet.dart';

/// Operasyon Ana Sekmesi
class OperasyonTab extends StatefulWidget {
  const OperasyonTab({super.key});

  @override
  State<OperasyonTab> createState() => _OperasyonTabState();
}

class _OperasyonTabState extends State<OperasyonTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = OperationService.instance;

  int get _bayId => AuthService.instance.currentUser?.sId ?? 0;

  // ── ValueNotifier'lar ─────────────────────────────────────
  // null = henüz yüklenmedi (loading göster)
  // []   = yüklendi, boş
  // [..] = sipariş listesi
  //
  // Tüm setState() çağrıları ortadan kalktı;
  // yalnızca ilgili ValueListenableBuilder yeniden çizilir.
  final _unassignedNotifier = ValueNotifier<List<OrderModel>?>(null);
  final _assignedNotifier   = ValueNotifier<List<OrderModel>?>(null);
  final _sequenceMapNotifier  = ValueNotifier<Map<String, int>>({});
  final _courierNamesNotifier = ValueNotifier<Map<int, String>>({});
  // workId → işletme adı (t_work, tek seferlik yüklenir)
  final _workNamesNotifier    = ValueNotifier<Map<int, String>>({});

  // Stream abonelikleri
  // Tek bir stream (watchAllActiveOrders) ile hem atanmayan hem atanan
  // listeyi güncelliyoruz. Bu sayede s_stat değiştiğinde (teslim, iptal vb.)
  // Firestore snapshot KESİNLİKLE tetiklenir; iki ayrı query kullanmanın
  // getirdiği range-filter gecikme sorunu ortadan kalkar.
  StreamSubscription<List<OrderModel>>? _allOrdersSub;
  StreamSubscription<Map<String, int>>? _sequenceSub;
  StreamSubscription<List<CourierModel>>? _courierNamesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (_bayId == 0) return;

    // ── TEK STREAM: tüm aktif siparişleri dinle, client-side'da böl ──────
    // watchAllActiveOrders:  s_bay + orderBy(s_cdate) + limit(300)
    // Bu query'de herhangi bir sipariş değiştiğinde (s_stat, s_courier vs.)
    // Firestore anlık snapshot gönderir → teslim edilen sipariş hemen kalkar.
    _allOrdersSub = _service.watchAllActiveOrders(_bayId).listen(
      (allOrders) {
        // Atanmayan: kurye atanmamış
        _unassignedNotifier.value = allOrders
            .where((o) => o.sCourier == 0)
            .toList()
          ..sort((a, b) =>
              (b.sCdate ?? DateTime(0)).compareTo(a.sCdate ?? DateTime(0)));

        // Atanan: kurye atanmış
        _assignedNotifier.value = allOrders
            .where((o) => o.sCourier > 0)
            .toList()
          ..sort((a, b) =>
              (b.sCdate ?? DateTime(0)).compareTo(a.sCdate ?? DateTime(0)));
      },
      onError: (_) {
        _unassignedNotifier.value ??= [];
        _assignedNotifier.value ??= [];
      },
    );

    // Sıra numaraları
    _sequenceSub = _service.watchDailySequences(_bayId).listen(
      (map) => _sequenceMapNotifier.value = map,
    );

    // Kurye isimleri
    _courierNamesSub = _service.watchActiveCouriersStream(_bayId).listen(
      (couriers) => _courierNamesNotifier.value = {
        for (final c in couriers) c.sId: c.fullName,
      },
    );

    // İşletme isimleri (tek seferlik yükle; t_work nadiren değişir)
    _service.fetchWorkInfos(_bayId).then((infos) {
      if (mounted) {
        _workNamesNotifier.value = {for (final w in infos) w.id: w.name};
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allOrdersSub?.cancel();
    _sequenceSub?.cancel();
    _courierNamesSub?.cancel();
    _unassignedNotifier.dispose();
    _assignedNotifier.dispose();
    _sequenceMapNotifier.dispose();
    _courierNamesNotifier.dispose();
    _workNamesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── İstatistik Çubuğu (bağımsız StatefulWidget) ──────
        _StatsBar(service: _service, bayId: _bayId),

        // ── Tab Bar ───────────────────────────────────────────
        _buildTabBar(),

        // ── Tab İçerikleri ────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OrderList(
                ordersNotifier: _unassignedNotifier,
                sequenceMapNotifier: _sequenceMapNotifier,
                courierNamesNotifier: _courierNamesNotifier,
                workNamesNotifier: _workNamesNotifier,
                isAssigned: false,
                bayId: _bayId,
                emptyMessage: 'Atanmayan sipariş yok 🎉',
                emptySubMessage: 'Tüm siparişler kuryelere atanmış durumda',
              ),
              _OrderList(
                ordersNotifier: _assignedNotifier,
                sequenceMapNotifier: _sequenceMapNotifier,
                courierNamesNotifier: _courierNamesNotifier,
                workNamesNotifier: _workNamesNotifier,
                isAssigned: true,
                bayId: _bayId,
                emptyMessage: 'Atanan sipariş yok',
                emptySubMessage: 'Henüz kurye atanmış sipariş bulunmuyor',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          _buildTab('Atanmayan', Icons.hourglass_empty_rounded, _unassignedNotifier),
          _buildTab('Atanan',    Icons.delivery_dining_rounded,  _assignedNotifier),
        ],
      ),
    );
  }

  Widget _buildTab(
    String label,
    IconData icon,
    ValueNotifier<List<OrderModel>?> notifier,
  ) {
    return Tab(
      child: ValueListenableBuilder<List<OrderModel>?>(
        valueListenable: notifier,
        builder: (_, orders, __) {
          final count = orders?.length ?? 0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik Çubuğu
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBar extends StatefulWidget {
  final OperationService service;
  final int bayId;
  const _StatsBar({required this.service, required this.bayId});

  @override
  State<_StatsBar> createState() => _StatsBarState();
}

class _StatsBarState extends State<_StatsBar> with WidgetsBindingObserver {
  CourierStats _cStats = const CourierStats(available: 0, busy: 0, onBreak: 0, onRoad: 0, accident: 0);
  DailyDeliveryStats _dStats = const DailyDeliveryStats(delivered: 0, returned: 0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// Uygulama arka plandan öne gelince yenile; arka planda timer dursun.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    if (widget.bayId == 0) return;
    final res = await Future.wait([
      widget.service.fetchCourierStats(widget.bayId),
      widget.service.fetchDailyStats(widget.bayId),
    ]);
    if (mounted) {
      setState(() {
        _cStats = res[0] as CourierStats;
        _dStats = res[1] as DailyDeliveryStats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('Müsait', _cStats.available,
              Icons.check_circle_outline_rounded, AppColors.success, AppColors.successLight),
          const SizedBox(width: 8),
          _chip('Meşgul', _cStats.busy,
              Icons.delivery_dining_rounded, const Color(0xFF5964FF), const Color(0xFFEEEFFF)),
          const SizedBox(width: 8),
          _chip('Yolda', _cStats.onRoad,
              Icons.directions_bike_rounded, const Color(0xFF0891B2), const Color(0xFFE0F7FA)),
          const SizedBox(width: 8),
          _chip('Molada', _cStats.onBreak,
              Icons.pause_circle_outline_rounded, AppColors.warning, AppColors.warningLight),
          if (_cStats.accident > 0) ...[
            const SizedBox(width: 8),
            _chip('Kaza', _cStats.accident,
                Icons.warning_amber_rounded, AppColors.error, AppColors.errorLight),
          ],
          const SizedBox(width: 16),
          Container(width: 1, height: 28, color: AppColors.border),
          const SizedBox(width: 16),
          _chip('Teslim', _dStats.delivered,
              Icons.check_rounded, AppColors.primary, AppColors.primary.withAlpha(18)),
          const SizedBox(width: 8),
          _chip('İade', _dStats.returned,
              Icons.keyboard_return_rounded, AppColors.error, AppColors.errorLight),
        ]),
      ),
    );
  }

  Widget _chip(String label, int value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(width: 5),
        Text('$value',
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sipariş Listesi
// StatefulWidget + addListener → anlık güncelleme garantili.
// ValueNotifier her değiştiğinde setState() tetiklenir, UI hemen yenilenir.
// ─────────────────────────────────────────────────────────────────────────────

class _OrderList extends StatefulWidget {
  final ValueNotifier<List<OrderModel>?> ordersNotifier;
  final ValueNotifier<Map<String, int>> sequenceMapNotifier;
  final ValueNotifier<Map<int, String>> courierNamesNotifier;
  final ValueNotifier<Map<int, String>> workNamesNotifier;
  final bool isAssigned;
  final int bayId;
  final String emptyMessage;
  final String emptySubMessage;

  const _OrderList({
    required this.ordersNotifier,
    required this.sequenceMapNotifier,
    required this.courierNamesNotifier,
    required this.workNamesNotifier,
    required this.isAssigned,
    required this.bayId,
    required this.emptyMessage,
    required this.emptySubMessage,
  });

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  List<OrderModel>? _orders;
  Map<String, int> _seqMap = {};
  Map<int, String> _courierNames = {};
  Map<int, String> _workNames = {};

  @override
  void initState() {
    super.initState();
    // Mevcut değerleri al
    _orders       = widget.ordersNotifier.value;
    _seqMap       = widget.sequenceMapNotifier.value;
    _courierNames = widget.courierNamesNotifier.value;
    _workNames    = widget.workNamesNotifier.value;

    // Her notifier'a ayrı listener ekle → setState garantili
    widget.ordersNotifier.addListener(_onOrders);
    widget.sequenceMapNotifier.addListener(_onSeqMap);
    widget.courierNamesNotifier.addListener(_onCourierNames);
    widget.workNamesNotifier.addListener(_onWorkNames);
  }

  @override
  void dispose() {
    widget.ordersNotifier.removeListener(_onOrders);
    widget.sequenceMapNotifier.removeListener(_onSeqMap);
    widget.courierNamesNotifier.removeListener(_onCourierNames);
    widget.workNamesNotifier.removeListener(_onWorkNames);
    super.dispose();
  }

  void _onOrders()       { if (mounted) setState(() => _orders       = widget.ordersNotifier.value); }
  void _onSeqMap()       { if (mounted) setState(() => _seqMap       = widget.sequenceMapNotifier.value); }
  void _onCourierNames() { if (mounted) setState(() => _courierNames = widget.courierNamesNotifier.value); }
  void _onWorkNames()    { if (mounted) setState(() => _workNames    = widget.workNamesNotifier.value); }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;

    // Henüz ilk veri gelmedi → yükleniyor
    if (orders == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Siparişler yükleniyor…',
                style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    // Boş liste
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: AppColors.background, shape: BoxShape.circle),
                child: Icon(
                  widget.isAssigned
                      ? Icons.delivery_dining_outlined
                      : Icons.inbox_outlined,
                  size: 52,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.emptyMessage,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(widget.emptySubMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textHint)),
            ],
          ),
        ),
      );
    }

    // Sipariş listesi
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 300)),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 20),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final order = orders[i];
          return OrderCard(
            key: ValueKey(order.docId),
            order: order,
            isAssigned: widget.isAssigned,
            sequenceNumber: _seqMap[order.docId],
            courierName: _courierNames[order.sCourier],
            workName: _workNames[order.sWork],
            onTap: () => AssignCourierSheet.show(
              context,
              order: order,
              bayId: widget.bayId,
            ),
          );
        },
      ),
    );
  }
}
