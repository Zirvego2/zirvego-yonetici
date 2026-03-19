import 'package:cloud_firestore/cloud_firestore.dart';

/// t_orders koleksiyonundaki sipariş modeli
class OrderModel {
  final String docId;
  final int sId;
  final int sStat;
  final int sCourier;
  final int sBay;
  final DateTime? sCdate;
  final DateTime? sAssignedTime;
  final DateTime? sOnRoadTime;
  final OrderCustomer sCustomer;
  final OrderPayment sPay;
  final int sOrderscr;
  final int sWork;
  final int? sReadyMinutes;
  final Timestamp? sReadyTime;
  final String? sReadyTimeText;

  /// Randevulu/ileri tarihli sipariş mi? (s_is_scheduled == true)
  final bool sIsScheduled;

  const OrderModel({
    required this.docId,
    required this.sId,
    required this.sStat,
    required this.sCourier,
    required this.sBay,
    this.sCdate,
    this.sAssignedTime,
    this.sOnRoadTime,
    required this.sCustomer,
    required this.sPay,
    required this.sOrderscr,
    required this.sWork,
    this.sReadyMinutes,
    this.sReadyTime,
    this.sReadyTimeText,
    this.sIsScheduled = false,
  });

  // ── Kısayollar ──────────────────────────────────────────
  bool get isAssigned => sCourier > 0;

  String get statusText {
    switch (sStat) {
      case 0:
        return 'Hazır';
      case 1:
        return 'Yolda';
      case 2:
        return 'Teslim Edildi';
      case 3:
        return 'İptal Edildi';
      case 4:
        return 'İşletmede';
      case 5:
        return 'İade Edildi';
      default:
        return 'Bilinmeyen';
    }
  }

  String get orderSourceName {
    switch (sOrderscr) {
      case 0:
        return 'Manuel';
      case 1:
        return 'Getir';
      case 2:
        return 'Yemek Sepeti';
      case 3:
        return 'Trendyol';
      case 4:
        return 'Migros';
      default:
        return 'Diğer';
    }
  }

  /// Oluşturulma zamanından itibaren geçen süre (dakika)
  int get elapsedMinutes {
    if (sCdate == null) return 0;
    return DateTime.now().difference(sCdate!).inMinutes;
  }

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel.fromMap(data, doc.id);
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return OrderModel(
      docId: docId,
      sId: (map['s_id'] as num?)?.toInt() ?? 0,
      sStat: (map['s_stat'] as num?)?.toInt() ?? 0,
      sCourier: (map['s_courier'] as num?)?.toInt() ?? 0,
      sBay: (map['s_bay'] as num?)?.toInt() ?? 0,
      sCdate: map['s_cdate'] is Timestamp
          ? (map['s_cdate'] as Timestamp).toDate()
          : null,
      sAssignedTime: map['s_assigned_time'] is Timestamp
          ? (map['s_assigned_time'] as Timestamp).toDate()
          : null,
      sOnRoadTime: map['s_on_road_time'] is Timestamp
          ? (map['s_on_road_time'] as Timestamp).toDate()
          : null,
      sCustomer: OrderCustomer.fromMap(
          map['s_customer'] as Map<String, dynamic>? ?? {}),
      sPay: OrderPayment.fromMap(map['s_pay'] as Map<String, dynamic>? ?? {}),
      sOrderscr: (map['s_orderscr'] as num?)?.toInt() ?? 0,
      sWork: (map['s_work'] as num?)?.toInt() ?? 0,
      sReadyMinutes: (map['s_ready_minutes'] as num?)?.toInt(),
      sReadyTime: map['s_ready_time'] is Timestamp
          ? map['s_ready_time'] as Timestamp
          : null,
      sReadyTimeText: map['s_ready_timeText'] as String?,
      sIsScheduled: map['s_is_scheduled'] as bool? ?? false,
    );
  }
}

/// Müşteri bilgileri
class OrderCustomer {
  final String ssFullname;
  final String ssPhone;
  final String ssAdres;

  /// Müşteri teslimat konumu (harita marker'ı için)
  final GeoPoint? ssLoc;

  const OrderCustomer({
    required this.ssFullname,
    required this.ssPhone,
    required this.ssAdres,
    this.ssLoc,
  });

  factory OrderCustomer.fromMap(Map<String, dynamic> map) {
    return OrderCustomer(
      ssFullname: map['ss_fullname'] as String? ?? '',
      ssPhone: map['ss_phone'] as String? ?? '',
      ssAdres: map['ss_adres'] as String? ?? '',
      ssLoc: map['ss_loc'] is GeoPoint ? map['ss_loc'] as GeoPoint : null,
    );
  }
}

/// Ödeme bilgileri
class OrderPayment {
  final int ssPaytype; // 0=Nakit, 1=Kredi Kartı, diğer=Online
  final dynamic ssPaycount;

  const OrderPayment({
    required this.ssPaytype,
    this.ssPaycount,
  });

  String get payTypeName {
    switch (ssPaytype) {
      case 0:
        return 'Nakit';
      case 1:
        return 'Kredi Kartı';
      default:
        return 'Online';
    }
  }

  factory OrderPayment.fromMap(Map<String, dynamic> map) {
    return OrderPayment(
      ssPaytype: (map['ss_paytype'] as num?)?.toInt() ?? 0,
      ssPaycount: map['ss_paycount'],
    );
  }
}
