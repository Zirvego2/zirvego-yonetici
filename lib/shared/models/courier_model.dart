import 'package:cloud_firestore/cloud_firestore.dart';

/// t_courier koleksiyonundaki kurye modeli
///
/// Kurye statü değerleri (web kaynaklı):
///   0 = Offline/Pasif  (filtrelenir, gösterilmez)
///   1 = Müsait         (yeşil)
///   2 = Meşgul         (mavi)
///   3 = Molada         (sarı)
///   4 = Kaza           (kırmızı)
class CourierModel {
  final String docId;
  final int sId;
  final int sStat;
  final int sBay;
  final CourierInfo sInfo;

  /// Ham konum string'i: "[40.3400703° N, 27.95097° E km : 0.07]"
  final String? sLoc;

  /// Push bildirim token'ları (kurye mobil uygulamasından yazılır)
  final String? fcmToken;
  final String? expoPushToken;

  const CourierModel({
    required this.docId,
    required this.sId,
    required this.sStat,
    required this.sBay,
    required this.sInfo,
    this.sLoc,
    this.fcmToken,
    this.expoPushToken,
  });

  // ── Kısayollar ──────────────────────────────────────────
  String get fullName => '${sInfo.ssName} ${sInfo.ssSurname}'.trim();

  /// Aktif push token: fcmToken varsa onu kullan, yoksa expoPushToken
  String? get pushToken {
    if (fcmToken != null && fcmToken!.isNotEmpty) return fcmToken;
    if (expoPushToken != null && expoPushToken!.isNotEmpty) return expoPushToken;
    return null;
  }

  String get statusText {
    switch (sStat) {
      case 1:
        return 'Müsait';
      case 2:
        return 'Meşgul';
      case 3:
        return 'Molada';
      case 4:
        return 'Kaza';
      default:
        return 'Offline';
    }
  }

  /// Müsait mi? (1 = Müsait — yalnızca bu statüdekiler boşta kabul edilir)
  bool get isAvailable => sStat == 1;

  /// Aktif mi? (0 = offline değil demek)
  bool get isActive => sStat != 0;

  // ── Sipariş bazlı etkin durum ────────────────────────────────────────────
  //
  // Kural:
  //   s_stat == 3 → Molada  (sipariş durumundan bağımsız)
  //   s_stat == 4 → Kaza    (sipariş durumundan bağımsız)
  //   Herhangi bir sipariş Yolda (s_stat==1) → 5 (Yolda)
  //   Siparişi var ama hiç Yolda yok       → 2 (Meşgul)
  //   Sipariş yok                          → 1 (Müsait)
  //
  // Dönen kodlar: 1=Müsait 2=Meşgul 3=Molada 4=Kaza 5=Yolda

  int effectiveStatCode({int orderCount = 0, bool hasOnRoadOrder = false}) {
    if (sStat == 3) return 3;
    if (sStat == 4) return 4;
    if (hasOnRoadOrder) return 5;
    if (orderCount > 0) return 2;
    return 1;
  }

  String effectiveStatusText({int orderCount = 0, bool hasOnRoadOrder = false}) {
    switch (effectiveStatCode(
        orderCount: orderCount, hasOnRoadOrder: hasOnRoadOrder)) {
      case 1: return 'Müsait';
      case 2: return 'Meşgul';
      case 3: return 'Molada';
      case 4: return 'Kaza';
      case 5: return 'Yolda';
      default: return 'Offline';
    }
  }

  /// Kurye konumunu ayrıştır
  /// Format: "[40.3400703° N, 27.95097° E km : 0.07]"
  CourierLocation? get parsedLocation {
    if (sLoc == null || sLoc!.isEmpty) return null;
    final match = RegExp(
      r'\[([\d.]+)°\s*N,\s*([\d.]+)°\s*E\s*km\s*:\s*([\d.]+)\]',
    ).firstMatch(sLoc!);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1) ?? '');
    final lng = double.tryParse(match.group(2) ?? '');
    final speed = double.tryParse(match.group(3) ?? '');
    if (lat == null || lng == null) return null;
    return CourierLocation(lat: lat, lng: lng, speed: speed ?? 0.0);
  }

  factory CourierModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourierModel.fromMap(data, doc.id);
  }

  factory CourierModel.fromMap(Map<String, dynamic> map, String docId) {
    return CourierModel(
      docId: docId,
      sId: (map['s_id'] as num?)?.toInt() ?? 0,
      sStat: (map['s_stat'] as num?)?.toInt() ?? 0,
      sBay: (map['s_bay'] as num?)?.toInt() ?? 0,
      sInfo: CourierInfo.fromMap(
          map['s_info'] as Map<String, dynamic>? ?? {}),
      sLoc: _parseLocField(map['s_loc']),
      fcmToken: map['fcmToken'] as String?,
      expoPushToken: map['expoPushToken'] as String?,
    );
  }

  /// s_loc alanı Firestore'da hem String hem GeoPoint olarak gelebilir.
  /// String ise: "[40.34° N, 27.95° E km : 0.07]"
  /// GeoPoint ise: aynı formata çevirilir.
  static String? _parseLocField(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is GeoPoint) {
      return '[${raw.latitude}° N, ${raw.longitude}° E km : 0.0]';
    }
    // Map formatı: {latitude: x, longitude: y}
    if (raw is Map) {
      final lat = raw['latitude'] ?? raw['lat'];
      final lng = raw['longitude'] ?? raw['lng'];
      if (lat != null && lng != null) {
        return '[$lat° N, $lng° E km : 0.0]';
      }
    }
    return null;
  }
}

/// Kurye kişisel bilgileri
class CourierInfo {
  final String ssName;
  final String ssSurname;
  final String? ssPhone;
  final String? ssPassword; // kurye uygulaması girişi için

  const CourierInfo({
    required this.ssName,
    required this.ssSurname,
    this.ssPhone,
    this.ssPassword,
  });

  factory CourierInfo.fromMap(Map<String, dynamic> map) {
    return CourierInfo(
      ssName:     map['ss_name']     as String? ?? '',
      ssSurname:  map['ss_surname']  as String? ?? '',
      ssPhone:    map['ss_phone']    as String?,
      ssPassword: map['ss_password'] as String?,
    );
  }
}

/// Ayrıştırılmış kurye konumu
class CourierLocation {
  final double lat;
  final double lng;
  final double speed; // km/h

  const CourierLocation({
    required this.lat,
    required this.lng,
    required this.speed,
  });
}
