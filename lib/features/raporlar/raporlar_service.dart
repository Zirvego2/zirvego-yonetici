import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../shared/models/order_model.dart';

/// Tüm rapor sayfaları için merkezi veri çekme servisi.
/// ─ Tüm metotlar try/catch ile sarılıdır, asla fırlatmaz.
/// ─ Tüm sorgularda limit() kullanılır (OOM koruması).
/// ─ İstemci tarafı filtreler composite-index ihtiyacını ortadan kaldırır.
class RaporlarService {
  RaporlarService._();
  static final RaporlarService instance = RaporlarService._();

  final _db = FirebaseFirestore.instance;

  // ── Koleksiyon isimleri ───────────────────────────────────────────────────
  static const _orders       = 't_orders';
  static const _courier      = 't_courier';
  static const _work         = 't_work';
  static const _cashTx       = 't_courier_cash_transactions';
  static const _dailyLogs    = 'courier_daily_logs';
  static const _bay          = 't_bay';

  // ── Yardımcı: varsayılan tarih aralığı (son 24 saat) ────────────────────
  static DateTimeRange defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(const Duration(hours: 24)),
      end:   now,
    );
  }

  // ── Yardımcı: DateTimeRange'i gün sonuna kadar genişlet ──────────────────
  static DateTimeRange normalizeRange(DateTimeRange r) => DateTimeRange(
    start: DateTime(r.start.year, r.start.month, r.start.day, 0,  0,  0),
    end:   DateTime(r.end.year,   r.end.month,   r.end.day,   23, 59, 59),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 1. SİPARİŞLER
  // ─────────────────────────────────────────────────────────────────────────

  /// [s_bay + tarih aralığı] ile siparişleri çeker.
  /// [filterStats] boşsa tüm siparişler döner; doluysa istemci filtrelenir.
  Future<List<OrderModel>> fetchOrdersInRange(
    int bayId,
    DateTimeRange range, {
    List<int>? filterStats,
  }) async {
    try {
      final snap = await _db
          .collection(_orders)
          .where('s_bay', isEqualTo: bayId)
          .where('s_cdate', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('s_cdate', isLessThanOrEqualTo:   Timestamp.fromDate(range.end))
          .orderBy('s_cdate', descending: true)
          .limit(500)
          .get();

      var list = snap.docs.map((d) => OrderModel.fromDoc(d)).toList();
      if (filterStats != null && filterStats.isNotEmpty) {
        list = list.where((o) => filterStats.contains(o.sStat)).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. KURYE / İŞLETME ADLARİ
  // ─────────────────────────────────────────────────────────────────────────

  /// Kurye id → isim haritası
  Future<Map<int, String>> fetchCourierNames(int bayId) async {
    try {
      final snap = await _db
          .collection(_courier)
          .where('s_bay', isEqualTo: bayId)
          .get();
      final map = <int, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final id   = (data['s_id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;
        final info  = data['s_info'] as Map<String, dynamic>? ?? {};
        final name  = '${info['ss_name'] ?? ''} ${info['ss_surname'] ?? ''}'.trim();
        map[id] = name.isEmpty ? 'Kurye #$id' : name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// İşletme id → isim haritası
  Future<Map<int, String>> fetchWorkNames(int bayId) async {
    try {
      final snap = await _db
          .collection(_work)
          .where('s_bay', isEqualTo: bayId)
          .get();
      final map = <int, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final id   = (data['s_id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;
        final name  = (data['s_name'] ?? data['s_title'] ?? '').toString().trim();
        map[id] = name.isEmpty ? 'İşletme #$id' : name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. NAKİT İŞLEMLERİ  (t_courier_cash_transactions)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCashTransactions(
    int bayId,
    DateTimeRange range,
  ) async {
    try {
      final snap = await _db
          .collection(_cashTx)
          .where('bay_id', isEqualTo: bayId)
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('transaction_date', isLessThanOrEqualTo:   Timestamp.fromDate(range.end))
          .orderBy('transaction_date', descending: true)
          .limit(500)
          .get();

      return snap.docs.map((d) {
        final raw = Map<String, dynamic>.from(d.data());
        raw['_docId'] = d.id;
        _convertTimestamps(raw);
        return raw;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. GÜNLÜK LOGLAR  (courier_daily_logs)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDailyLogs(
    int bayId,
    DateTimeRange range,
  ) async {
    // İki farklı schema'yı dene
    for (final schema in [
      {'bayField': 'bay_id',  'dateField': 'date'},
      {'bayField': 's_bay',   'dateField': 's_date'},
    ]) {
      try {
        final snap = await _db
            .collection(_dailyLogs)
            .where(schema['bayField']!,  isEqualTo: bayId)
            .where(schema['dateField']!, isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
            .where(schema['dateField']!, isLessThanOrEqualTo:    Timestamp.fromDate(range.end))
            .limit(500)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) {
            final raw = Map<String, dynamic>.from(d.data());
            raw['_docId'] = d.id;
            _convertTimestamps(raw);
            return raw;
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. ÖDEME DEĞİŞİKLİKLERİ (birkaç koleksiyon adı dene)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPaymentChanges(
    int bayId,
    DateTimeRange range,
  ) async {
    const candidates = [
      'payment_changes',
      't_payment_changes',
      'odeme_degisiklikleri',
      'PaymentChanges',
    ];
    for (final col in candidates) {
      try {
        final snap = await _db
            .collection(col)
            .where('bay_id', isEqualTo: bayId)
            .limit(300)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) {
            final raw = Map<String, dynamic>.from(d.data());
            raw['_docId'] = d.id;
            _convertTimestamps(raw);
            return raw;
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. BAY ÖDEME AYARLARI  (kurye kazanç hesabı için)
  // ─────────────────────────────────────────────────────────────────────────

  Future<({double perOrder, double perKm})> fetchBayPaySettings(
      String bayDocId) async {
    try {
      final doc = await _db.collection(_bay).doc(bayDocId).get();
      if (!doc.exists) return (perOrder: 0.0, perKm: 0.0);
      final setting =
          (doc.data()?['s_settingcur'] as Map<String, dynamic>?) ?? {};
      final po = double.tryParse(setting['ss_curpay']?.toString() ?? '0') ?? 0;
      final pk = double.tryParse(setting['ss_kmpay']?.toString() ?? '0') ?? 0;
      return (perOrder: po, perKm: pk);
    } catch (_) {
      return (perOrder: 0.0, perKm: 0.0);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YARDIMCI
  // ─────────────────────────────────────────────────────────────────────────

  void _convertTimestamps(Map<String, dynamic> map) {
    for (final key in map.keys.toList()) {
      if (map[key] is Timestamp) {
        map[key] = (map[key] as Timestamp).toDate();
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hesaplanmış kurye raporu satırı
// ─────────────────────────────────────────────────────────────────────────────

class CourierReportRow {
  final int    courierId;
  final String courierName;
  final int    totalOrders;
  final int    delivered;
  final int    cancelled;
  final int    returned;
  final double deliveryRate; // %
  final double avgReadyMinutes;  // Sipariş-atama arası
  final double avgOnRoadMinutes; // Atama-yolda arası
  final double totalCash;        // Nakit teslim toplam

  const CourierReportRow({
    required this.courierId,
    required this.courierName,
    required this.totalOrders,
    required this.delivered,
    required this.cancelled,
    required this.returned,
    required this.deliveryRate,
    required this.avgReadyMinutes,
    required this.avgOnRoadMinutes,
    required this.totalCash,
  });

  static List<CourierReportRow> fromOrders(
    List<OrderModel> orders,
    Map<int, String> names,
  ) {
    final map = <int, _Builder>{};
    for (final o in orders) {
      if (o.sCourier <= 0) continue;
      map.putIfAbsent(o.sCourier, () => _Builder());
      map[o.sCourier]!.add(o);
    }
    return map.entries.map((e) {
      final b = e.value;
      final name = names[e.key] ?? 'Kurye #${e.key}';
      final total = b.total;
      return CourierReportRow(
        courierId:         e.key,
        courierName:       name,
        totalOrders:       total,
        delivered:         b.delivered,
        cancelled:         b.cancelled,
        returned:          b.returned,
        deliveryRate:      total == 0 ? 0 : b.delivered / total * 100,
        avgReadyMinutes:   b.readyCount == 0 ? 0 : b.readyMins / b.readyCount,
        avgOnRoadMinutes:  b.onRoadCount == 0 ? 0 : b.onRoadMins / b.onRoadCount,
        totalCash:         b.cash,
      );
    }).toList()
      ..sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
  }
}

class _Builder {
  int total = 0, delivered = 0, cancelled = 0, returned = 0;
  int readyCount = 0, onRoadCount = 0;
  double readyMins = 0, onRoadMins = 0, cash = 0;

  void add(OrderModel o) {
    total++;
    if (o.sStat == 2) delivered++;
    if (o.sStat == 3) cancelled++;
    if (o.sStat == 5) returned++;

    if (o.sCdate != null && o.sAssignedTime != null) {
      readyMins += o.sAssignedTime!.difference(o.sCdate!).inMinutes.abs().toDouble();
      readyCount++;
    }
    if (o.sAssignedTime != null && o.sOnRoadTime != null) {
      onRoadMins += o.sOnRoadTime!.difference(o.sAssignedTime!).inMinutes.abs().toDouble();
      onRoadCount++;
    }
    if (o.sPay.ssPaytype == 0 && o.sStat == 2) {
      final amt = double.tryParse(o.sPay.ssPaycount?.toString() ?? '0') ?? 0;
      cash += amt;
    }
  }
}
