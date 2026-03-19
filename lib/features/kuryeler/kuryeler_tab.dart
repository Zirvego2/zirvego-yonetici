import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/operation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/courier_model.dart';
import '../../shared/models/order_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Durum tanımları
// ─────────────────────────────────────────────────────────────────────────────

class _SD {
  final int    code;
  final String label;
  final Color  color;
  final Color  bg;
  final IconData icon;
  const _SD({required this.code, required this.label,
      required this.color, required this.bg, required this.icon});
}

const _kAllStats = [
  _SD(code: 0, label: 'Offline',  color: Color(0xFF9CA3AF), bg: Color(0xFFF3F4F6), icon: Icons.power_off_rounded),
  _SD(code: 1, label: 'Müsait',   color: Color(0xFF10B981), bg: Color(0xFFD1FAE5), icon: Icons.check_circle_rounded),
  _SD(code: 2, label: 'Meşgul',   color: Color(0xFF5964FF), bg: Color(0xFFEEEFFF), icon: Icons.delivery_dining_rounded),
  _SD(code: 3, label: 'Molada',   color: Color(0xFFF59E0B), bg: Color(0xFFFEF3C7), icon: Icons.pause_circle_rounded),
  _SD(code: 4, label: 'Kaza',     color: Color(0xFFEF4444), bg: Color(0xFFFEE2E2), icon: Icons.warning_rounded),
  _SD(code: 5, label: 'Yolda',    color: Color(0xFF0891B2), bg: Color(0xFFE0F7FA), icon: Icons.directions_bike_rounded),
];

_SD _sd(int code) =>
    _kAllStats.firstWhere((s) => s.code == code, orElse: () => _kAllStats.first);

// ─────────────────────────────────────────────────────────────────────────────
// KuryelerTab — Ana Widget
// ─────────────────────────────────────────────────────────────────────────────

class KuryelerTab extends StatefulWidget {
  const KuryelerTab({super.key});
  @override
  State<KuryelerTab> createState() => _KuryelerTabState();
}

class _KuryelerTabState extends State<KuryelerTab> {
  final _service = OperationService.instance;
  int get _bayId => AuthService.instance.currentUser?.sId ?? 0;

  StreamSubscription<List<CourierModel>>? _courierSub;
  StreamSubscription<List<OrderModel>>?   _orderSub;

  List<CourierModel> _couriers    = [];
  Map<int, int>      _orderCounts = {}; // courierId → sipariş sayısı
  Map<int, bool>     _onRoadMap   = {}; // courierId → yolda sipariş var mı

  bool    _loading    = true;
  int?    _filterStat; // null=tümü  -1=aktif(online)  0-4=spesifik s_stat
  String  _search     = '';

  final _searchCtrl = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_bayId == 0) return;

    // Tüm kuryeler (offline dahil)
    _courierSub = _service.watchAllCouriers(_bayId).listen(
      (list) { if (mounted) setState(() { _couriers = list; _loading = false; }); },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );

    // Aktif siparişlerden sipariş sayısı çıkar
    _orderSub = _service.watchAllActiveOrders(_bayId).listen(
      (orders) {
        if (!mounted) return;
        final cnt   = <int, int>{};
        final onRd  = <int, bool>{};
        for (final o in orders) {
          if (o.sCourier <= 0) continue;
          cnt[o.sCourier]  = (cnt[o.sCourier]  ?? 0) + 1;
          if (o.sStat == 1) onRd[o.sCourier] = true;
        }
        setState(() { _orderCounts = cnt; _onRoadMap = onRd; });
      },
    );
  }

  @override
  void dispose() {
    _courierSub?.cancel();
    _orderSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Hesaplama yardımcıları ─────────────────────────────────────────────────

  int _eff(CourierModel c) => c.effectiveStatCode(
        orderCount:     _orderCounts[c.sId] ?? 0,
        hasOnRoadOrder: _onRoadMap[c.sId]   ?? false,
      );

  // ── İstatistik sayaçları ──────────────────────────────────────────────────

  int get _total   => _couriers.length;
  int get _online  => _couriers.where((c) => c.sStat != 0).length;
  int get _offline => _couriers.where((c) => c.sStat == 0).length;

  int _effCount(int effCode) =>
      _couriers.where((c) => c.sStat != 0 && _eff(c) == effCode).length;

  // ── Filtrelenmiş + sıralı liste ───────────────────────────────────────────

  List<CourierModel> get _filtered {
    var list = _couriers;

    if (_filterStat != null) {
      if (_filterStat == -1) {
        list = list.where((c) => c.sStat != 0).toList();
      } else {
        list = list.where((c) => c.sStat == _filterStat).toList();
      }
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        (c.sInfo.ssPhone ?? '').contains(q),
      ).toList();
    }

    // Sıralama: aktif önce → etkin durum → isim
    list.sort((a, b) {
      if (a.sStat == 0 && b.sStat != 0) return 1;
      if (a.sStat != 0 && b.sStat == 0) return -1;
      if (a.sStat == 0 && b.sStat == 0) return a.fullName.compareTo(b.fullName);
      const order = {1: 0, 5: 1, 2: 2, 3: 3, 4: 4};
      final diff = (order[_eff(a)] ?? 9).compareTo(order[_eff(b)] ?? 9);
      return diff != 0 ? diff : a.fullName.compareTo(b.fullName);
    });

    return list;
  }

  // ── Modal: durum değiştir ─────────────────────────────────────────────────

  Future<void> _showStatusSheet(CourierModel courier) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSheet(
        courier: courier,
        onSelect: (code) async {
          Navigator.pop(context);
          final ok = await _service.updateCourierStatus(
            docId: courier.docId, newStat: code);
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Durum güncellenemedi')));
          }
        },
      ),
    );
  }

  // ── Modal: ekle / düzenle ─────────────────────────────────────────────────

  Future<void> _showForm({CourierModel? editing}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourierForm(
        bayId: _bayId, editing: editing, service: _service),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _StatsRow(
              total:   _total,
              online:  _online,
              offline: _offline,
              musait:  _effCount(1),
              yolda:   _effCount(5),
              mesgul:  _effCount(2),
              molada:  _effCount(3),
              kaza:    _effCount(4),
            ),
            _SearchAndFilter(
              search:     _search,
              controller: _searchCtrl,
              filterStat: _filterStat,
              onSearch:   (v) => setState(() => _search = v),
              onFilter:   (v) => setState(() => _filterStat = v),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'courier_fab',
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        icon:  const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Kurye Ekle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 12),
          Text('Kuryeler yükleniyor…',
              style: TextStyle(color: AppColors.textHint)),
        ]),
      );
    }

    final list = _filtered;

    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppColors.background, shape: BoxShape.circle),
            child: const Icon(Icons.person_off_rounded,
                size: 52, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          const Text('Kurye bulunamadı',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Filtre veya arama kriterini değiştirin',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c       = list[i];
        final cnt     = _orderCounts[c.sId] ?? 0;
        final onRoad  = _onRoadMap[c.sId]   ?? false;
        final effCode = c.sStat == 0 ? 0 : c.effectiveStatCode(
          orderCount: cnt, hasOnRoadOrder: onRoad);
        return _CourierCard(
          key:          ValueKey(c.docId),
          courier:      c,
          statDef:      _sd(effCode),
          orderCount:   cnt,
          onStatusTap:  () => _showStatusSheet(c),
          onEditTap:    () => _showForm(editing: c),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik Çubuğu
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int total, online, offline, musait, yolda, mesgul, molada, kaza;

  const _StatsRow({
    required this.total,   required this.online,  required this.offline,
    required this.musait,  required this.yolda,   required this.mesgul,
    required this.molada,  required this.kaza,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('Toplam',  total,  const Color(0xFF6B7280), const Color(0xFFF3F4F6), Icons.people_rounded),
          _chip('Aktif',   online, const Color(0xFF10B981), const Color(0xFFD1FAE5), Icons.wifi_rounded),
          _chip('Müsait',  musait, const Color(0xFF10B981), const Color(0xFFD1FAE5), Icons.check_circle_rounded),
          _chip('Yolda',   yolda,  const Color(0xFF0891B2), const Color(0xFFE0F7FA), Icons.directions_bike_rounded),
          _chip('Meşgul',  mesgul, const Color(0xFF5964FF), const Color(0xFFEEEFFF), Icons.delivery_dining_rounded),
          _chip('Molada',  molada, const Color(0xFFF59E0B), const Color(0xFFFEF3C7), Icons.pause_circle_rounded),
          if (kaza > 0)
            _chip('Kaza', kaza, const Color(0xFFEF4444), const Color(0xFFFEE2E2), Icons.warning_rounded),
          _chip('Offline', offline, const Color(0xFF9CA3AF), const Color(0xFFF3F4F6), Icons.power_off_rounded),
        ].expand((w) => [w, const SizedBox(width: 7)]).toList()),
      ),
    );
  }

  Widget _chip(String label, int n, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(width: 5),
        Text('$n', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arama + Filtre
// ─────────────────────────────────────────────────────────────────────────────

class _SearchAndFilter extends StatelessWidget {
  final String search;
  final TextEditingController controller;
  final int? filterStat;
  final void Function(String) onSearch;
  final void Function(int?) onFilter;

  const _SearchAndFilter({
    required this.search,     required this.controller,
    required this.filterStat, required this.onSearch,
    required this.onFilter,
  });

  static const _filters = [
    (label: 'Tümü',   stat: null,  color: AppColors.primary),
    (label: 'Aktif',  stat: -1,    color: Color(0xFF10B981)),
    (label: 'Offline',stat: 0,     color: Color(0xFF9CA3AF)),
    (label: 'Müsait', stat: 1,     color: Color(0xFF10B981)),
    (label: 'Molada', stat: 3,     color: Color(0xFFF59E0B)),
    (label: 'Kaza',   stat: 4,     color: Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(children: [
        // Arama
        TextField(
          controller: controller,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'Kurye ara (isim, telefon)…',
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textHint, size: 20),
            suffixIcon: search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () { controller.clear(); onSearch(''); },
                  )
                : null,
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Filtre chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSelected = filterStat == f.stat;
              return GestureDetector(
                onTap: () => onFilter(f.stat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? f.color : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? f.color : AppColors.border,
                    ),
                  ),
                  child: Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kurye Kartı
// ─────────────────────────────────────────────────────────────────────────────

class _CourierCard extends StatelessWidget {
  final CourierModel courier;
  final _SD          statDef;
  final int          orderCount;
  final VoidCallback onStatusTap;
  final VoidCallback onEditTap;

  const _CourierCard({
    super.key,
    required this.courier,
    required this.statDef,
    required this.orderCount,
    required this.onStatusTap,
    required this.onEditTap,
  });

  String get _initials {
    final parts = courier.fullName.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Stack(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statDef.bg,
                border: Border.all(color: statDef.color, width: 2.5),
              ),
              child: Center(
                child: Text(_initials,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: statDef.color)),
              ),
            ),
            // Nokta göstergesi
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statDef.color,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 12),

          // ── Bilgiler ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İsim + sipariş rozeti
                Row(children: [
                  Expanded(
                    child: Text(
                      courier.fullName.isEmpty
                          ? 'İsimsiz Kurye'
                          : courier.fullName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (orderCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_rounded,
                            size: 11, color: Color(0xFFEF4444)),
                        const SizedBox(width: 3),
                        Text('$orderCount',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 5),

                // Durum chip (tıklanabilir)
                GestureDetector(
                  onTap: onStatusTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statDef.bg,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: statDef.color.withAlpha(80)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statDef.icon, size: 12, color: statDef.color),
                      const SizedBox(width: 5),
                      Text(statDef.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: statDef.color,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded,
                          size: 9,
                          color: statDef.color.withAlpha(160)),
                    ]),
                  ),
                ),

                // Telefon
                if (courier.sInfo.ssPhone?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.phone_rounded,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(courier.sInfo.ssPhone!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ]),
                ],
              ],
            ),
          ),

          // ── Düzenle ──────────────────────────────────────────────────────
          IconButton(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: AppColors.textHint,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Durum Değiştirme Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  final CourierModel courier;
  final void Function(int) onSelect;

  const _StatusSheet({required this.courier, required this.onSelect});

  // Yalnızca elle atanabilir statüler (Meşgul/Yolda siparişlerden hesaplanır)
  static const _settable = [
    _SD(code: 1, label: 'Müsait',  color: Color(0xFF10B981), bg: Color(0xFFD1FAE5), icon: Icons.check_circle_rounded),
    _SD(code: 3, label: 'Molada',  color: Color(0xFFF59E0B), bg: Color(0xFFFEF3C7), icon: Icons.pause_circle_rounded),
    _SD(code: 4, label: 'Kaza',    color: Color(0xFFEF4444), bg: Color(0xFFFEE2E2), icon: Icons.warning_rounded),
    _SD(code: 0, label: 'Offline', color: Color(0xFF9CA3AF), bg: Color(0xFFF3F4F6), icon: Icons.power_off_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),

        // Başlık
        Row(children: [
          const Icon(Icons.swap_vert_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${courier.fullName} — Durum Değiştir',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Meşgul ve Yolda durumları sipariş sayısından otomatik hesaplanır.',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
        const SizedBox(height: 14),

        ..._settable.map((s) {
          final isCurrent = courier.sStat == s.code;
          return GestureDetector(
            onTap: isCurrent ? null : () => onSelect(s.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isCurrent ? s.bg : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? s.color : AppColors.border,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: s.bg, shape: BoxShape.circle),
                  child: Icon(s.icon, size: 20, color: s.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isCurrent
                                  ? s.color
                                  : AppColors.textPrimary)),
                      Text(
                        _desc(s.code),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check_circle_rounded,
                      color: s.color, size: 22),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  String _desc(int code) {
    switch (code) {
      case 1: return 'Yeni sipariş alabilir';
      case 3: return 'Geçici olarak çalışmıyor';
      case 4: return 'Acil — kaza durumu';
      case 0: return 'Çevrimdışı, atama yapılamaz';
      default: return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kurye Formu (Ekle / Düzenle)
// ─────────────────────────────────────────────────────────────────────────────

class _CourierForm extends StatefulWidget {
  final int             bayId;
  final CourierModel?   editing;
  final OperationService service;

  const _CourierForm({
    required this.bayId,
    required this.service,
    this.editing,
  });

  @override
  State<_CourierForm> createState() => _CourierFormState();
}

class _CourierFormState extends State<_CourierForm> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _surnCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passCtrl;

  bool _saving   = false;
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final e  = widget.editing;
    _nameCtrl  = TextEditingController(text: e?.sInfo.ssName     ?? '');
    _surnCtrl  = TextEditingController(text: e?.sInfo.ssSurname  ?? '');
    _phoneCtrl = TextEditingController(text: e?.sInfo.ssPhone    ?? '');
    _passCtrl  = TextEditingController(text: e?.sInfo.ssPassword ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final bool ok;
    if (widget.editing == null) {
      ok = await widget.service.addCourier(
        bayId:    widget.bayId,
        name:     _nameCtrl.text,
        surname:  _surnCtrl.text,
        phone:    _phoneCtrl.text,
        password: _passCtrl.text,
      );
    } else {
      ok = await widget.service.updateCourier(
        docId:    widget.editing!.docId,
        name:     _nameCtrl.text,
        surname:  _surnCtrl.text,
        phone:    _phoneCtrl.text,
        password: _passCtrl.text,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (widget.editing == null ? 'Kurye başarıyla eklendi ✓' : 'Kurye güncellendi ✓')
            : 'İşlem başarısız, tekrar deneyin'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),

              // Başlık
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      isEdit
                          ? Icons.edit_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                      size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Kurye Düzenle' : 'Yeni Kurye Ekle',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ]),
              const SizedBox(height: 20),

              // Ad
              _buildField(_nameCtrl, 'Ad *', Icons.person_rounded,
                  required: true),
              const SizedBox(height: 12),

              // Soyad
              _buildField(_surnCtrl, 'Soyad *', Icons.person_outline_rounded,
                  required: true),
              const SizedBox(height: 12),

              // Telefon
              _buildField(_phoneCtrl, 'Telefon', Icons.phone_rounded,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),

              // Şifre
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'Şifre (değiştirmek için girin)'
                      : 'Şifre *',
                  prefixIcon: const Icon(Icons.lock_rounded,
                      size: 18, color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showPass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18),
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 12),
                ),
                validator: !isEdit
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Şifre zorunlu'
                        : null
                    : null,
              ),
              const SizedBox(height: 24),

              // Kaydet
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withAlpha(100),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEdit
                              ? 'Değişiklikleri Kaydet'
                              : 'Kurye Ekle',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? '${label.replaceAll(' *', '')} zorunlu'
              : null
          : null,
    );
  }
}
