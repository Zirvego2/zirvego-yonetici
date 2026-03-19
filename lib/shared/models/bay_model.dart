import 'package:cloud_firestore/cloud_firestore.dart';

/// t_bay koleksiyonundaki yönetici/bayi kullanıcı modeli
class BayModel {
  final String docId;
  final int sId;
  final String sPhone;
  final String sPassword;
  final String sKey;
  final String sBayName;
  final String sAdres;
  final String sUsername;
  final int sAdmin;
  final int sBlock;
  final int payment;
  final bool paymentactive;
  final bool sTrackingEnabled;
  final String sSmsTemplate;
  final BayInfo sInfo;
  final BayLocation sLoc;
  final BaySettings sSettingcur;
  final BayAppSettings sSettings;
  final DateTime? sCreate;
  final DateTime? sPasswordUpdated;

  const BayModel({
    required this.docId,
    required this.sId,
    required this.sPhone,
    required this.sPassword,
    required this.sKey,
    required this.sBayName,
    required this.sAdres,
    required this.sUsername,
    required this.sAdmin,
    required this.sBlock,
    required this.payment,
    required this.paymentactive,
    required this.sTrackingEnabled,
    required this.sSmsTemplate,
    required this.sInfo,
    required this.sLoc,
    required this.sSettingcur,
    required this.sSettings,
    this.sCreate,
    this.sPasswordUpdated,
  });

  // ── Kısayollar ──────────────────────────────────────────
  String get username => sInfo.ssUsername;
  String get name => sInfo.ssName;
  String get surname => sInfo.ssSurname;
  String get fullName => '${sInfo.ssName} ${sInfo.ssSurname}'.trim();
  String get city => sLoc.ssCity;
  String get district => sLoc.ssDistrict;
  String get displayName => sBayName.isNotEmpty ? sBayName : fullName;

  factory BayModel.fromMap(Map<String, dynamic> map, String docId) {
    return BayModel(
      docId: docId,
      sId: (map['s_id'] as num?)?.toInt() ?? 0,
      sPhone: map['s_phone'] as String? ?? '',
      sPassword: map['s_password'] as String? ?? '',
      sKey: map['s_key'] as String? ?? '',
      sBayName: map['s_bay_name'] as String? ?? '',
      sAdres: map['s_adres'] as String? ?? '',
      sUsername: map['s_username'] as String? ?? '',
      sAdmin: (map['s_admin'] as num?)?.toInt() ?? 0,
      sBlock: (map['s_block'] as num?)?.toInt() ?? 0,
      payment: (map['Payment'] as num?)?.toInt() ?? 0,
      paymentactive: map['paymentactive'] as bool? ?? false,
      sTrackingEnabled: map['s_tracking_enabled'] as bool? ?? false,
      sSmsTemplate: map['s_sms_template'] as String? ?? '',
      sInfo: BayInfo.fromMap(map['s_info'] as Map<String, dynamic>? ?? {}),
      sLoc: BayLocation.fromMap(map['s_loc'] as Map<String, dynamic>? ?? {}),
      sSettingcur: BaySettings.fromMap(
          map['s_settingcur'] as Map<String, dynamic>? ?? {}),
      sSettings: BayAppSettings.fromMap(
          map['s_settings'] as Map<String, dynamic>? ?? {}),
      sCreate: map['s_create'] is Timestamp
          ? (map['s_create'] as Timestamp).toDate()
          : null,
      sPasswordUpdated: map['s_password_updated'] is Timestamp
          ? (map['s_password_updated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      's_id': sId,
      's_phone': sPhone,
      's_password': sPassword,
      's_key': sKey,
      's_bay_name': sBayName,
      's_adres': sAdres,
      's_username': sUsername,
      's_admin': sAdmin,
      's_block': sBlock,
      'Payment': payment,
      'paymentactive': paymentactive,
      's_tracking_enabled': sTrackingEnabled,
      's_sms_template': sSmsTemplate,
      's_info': sInfo.toMap(),
      's_loc': sLoc.toMap(),
      's_settingcur': sSettingcur.toMap(),
      's_settings': sSettings.toMap(),
      if (sCreate != null) 's_create': Timestamp.fromDate(sCreate!),
      if (sPasswordUpdated != null)
        's_password_updated': Timestamp.fromDate(sPasswordUpdated!),
    };
  }

  @override
  String toString() =>
      'BayModel(docId: $docId, username: $username, name: $fullName)';
}

/// s_info alt nesnesi
class BayInfo {
  final String ssName;
  final String ssSurname;
  final String ssUsername;
  final String ssPassword;

  const BayInfo({
    required this.ssName,
    required this.ssSurname,
    required this.ssUsername,
    required this.ssPassword,
  });

  factory BayInfo.fromMap(Map<String, dynamic> map) {
    return BayInfo(
      ssName: map['ss_name'] as String? ?? '',
      ssSurname: map['ss_surname'] as String? ?? '',
      ssUsername: map['ss_username'] as String? ?? '',
      ssPassword: map['ss_password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'ss_name': ssName,
        'ss_surname': ssSurname,
        'ss_username': ssUsername,
        'ss_password': ssPassword,
      };
}

/// s_loc alt nesnesi
class BayLocation {
  final String ssCity;
  final String ssDistrict;
  final GeoPoint? ssLocationGeoPoint;

  const BayLocation({
    required this.ssCity,
    required this.ssDistrict,
    this.ssLocationGeoPoint,
  });

  /// Koordinatları "enlem, boylam" formatında döndürür
  String get ssLocation {
    if (ssLocationGeoPoint == null) return '';
    return '${ssLocationGeoPoint!.latitude}, ${ssLocationGeoPoint!.longitude}';
  }

  factory BayLocation.fromMap(Map<String, dynamic> map) {
    GeoPoint? geoPoint;
    final raw = map['ss_location'];
    if (raw is GeoPoint) {
      geoPoint = raw;
    }
    return BayLocation(
      ssCity: map['ss_city'] as String? ?? '',
      ssDistrict: map['ss_district'] as String? ?? '',
      ssLocationGeoPoint: geoPoint,
    );
  }

  Map<String, dynamic> toMap() => {
        'ss_city': ssCity,
        'ss_district': ssDistrict,
        if (ssLocationGeoPoint != null) 'ss_location': ssLocationGeoPoint,
      };
}

/// s_settingcur alt nesnesi — kurye ücret ayarları
class BaySettings {
  final int ssCurpay;    // Kurye başlangıç ücreti
  final int ssKmpay;     // Km başı ücret
  final int ssMaxkm;     // Maksimum km
  final int ssPackageFee; // Paket ücreti

  const BaySettings({
    required this.ssCurpay,
    required this.ssKmpay,
    required this.ssMaxkm,
    required this.ssPackageFee,
  });

  factory BaySettings.fromMap(Map<String, dynamic> map) {
    return BaySettings(
      ssCurpay: (map['ss_curpay'] as num?)?.toInt() ?? 0,
      ssKmpay: (map['ss_kmpay'] as num?)?.toInt() ?? 0,
      ssMaxkm: (map['ss_maxkm'] as num?)?.toInt() ?? 0,
      ssPackageFee: (map['ss_package_fee'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'ss_curpay': ssCurpay,
        'ss_kmpay': ssKmpay,
        'ss_maxkm': ssMaxkm,
        'ss_package_fee': ssPackageFee,
      };
}

/// s_settings alt nesnesi — uygulama ayarları
class BayAppSettings {
  final bool courierOrderRejectEnabled;
  final bool orderAddressVisibleAfterOrder;
  final bool restaurantPricingEnabled;

  const BayAppSettings({
    required this.courierOrderRejectEnabled,
    required this.orderAddressVisibleAfterOrder,
    required this.restaurantPricingEnabled,
  });

  factory BayAppSettings.fromMap(Map<String, dynamic> map) {
    return BayAppSettings(
      courierOrderRejectEnabled:
          map['courierOrderRejectEnabled'] as bool? ?? false,
      orderAddressVisibleAfterOrder:
          map['orderAddressVisibleAfterOrder'] as bool? ?? false,
      restaurantPricingEnabled:
          map['restaurantPricingEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'courierOrderRejectEnabled': courierOrderRejectEnabled,
        'orderAddressVisibleAfterOrder': orderAddressVisibleAfterOrder,
        'restaurantPricingEnabled': restaurantPricingEnabled,
      };
}
