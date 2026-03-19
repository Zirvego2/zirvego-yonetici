import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/courier_model.dart';
import '../../shared/models/ai_settings_model.dart';
import '../constants/app_constants.dart';

/// Operasyon sayfası için anlık sipariş ve kurye yönetim servisi
class OperationService {
  OperationService._();
  static final OperationService instance = OperationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Logger _log = Logger();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  // ── Koleksiyon isimleri ───────────────────────────────
  static const String _ordersCol      = 't_orders';
  static const String _courierCol     = 't_courier';
  static const String _workCol        = 't_work';
  static const String _aiSettingsCol  = 'ai_settings';

  // ── Aktif sipariş durum kodları ──────────────────────
  // 0=Hazır, 1=Yolda, 4=İşletmede
  static const List<int> _activeStats = [0, 1, 4];

  // ── Push bildirim API URL'i ───────────────────────────
  static const String _pushNotifUrl =
      'https://zirvego.app/api/sendPushNotification';

  // ─────────────────────────────────────────────────────────────────────
  // SİPARİŞ STREAMLERİ
  // ─────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────
  // GÜNLÜK SIRA NUMARASI
  // ─────────────────────────────────────────────────────────────────────

  /// Bugün saat 05:00'den itibaren (veya dün 05:00 eğer henüz o saati
  /// geçmediyse) gelen SİPARİŞLERE oluşturulma sırasına göre numara atar.
  /// Dönen Map: { docId → sıraNo (1'den başlar) }
  Stream<Map<String, int>> watchDailySequences(int bayId) {
    final startTs = Timestamp.fromMillisecondsSinceEpoch(
      _dayStart().millisecondsSinceEpoch,
    );

    // limit(500): günlük sıra numarası için tüm döküman içeriği gerekmez,
    // ancak Flutter Firestore SDK field projection desteklemez → limit ile
    // codec payload'ını sınırla (OOM önlemi).
    return _db
        .collection(_ordersCol)
        .where('s_bay', isEqualTo: bayId)
        .where('s_cdate', isGreaterThanOrEqualTo: startTs)
        .orderBy('s_cdate')
        .limit(500)
        .snapshots()
        .map((snap) {
      final map = <String, int>{};
      for (int i = 0; i < snap.docs.length; i++) {
        map[snap.docs[i].id] = i + 1;
      }
      return map;
    });
  }

  /// Günlük periyodun başlangıcı: bugün saat 05:00.
  /// Eğer şu an 05:00'den önceyse dünün 05:00'i kullanılır.
  DateTime _dayStart() {
    final now = DateTime.now();
    final today5am = DateTime(now.year, now.month, now.day, 5, 0, 0);
    return now.isBefore(today5am)
        ? today5am.subtract(const Duration(days: 1))
        : today5am;
  }

  /// TÜM aktif siparişleri anlık dinler (harita + operasyon için).
  ///
  /// Kullanılan composite index (zaten mevcut):
  ///   t_orders → s_bay (ASC) + s_stat (ASC)
  ///
  /// Avantajları:
  ///  • Firestore sadece aktif siparişleri gönderir
  ///  • s_stat 2'ye (teslim) döndüğünde Firestore "removed" event atar
  ///    → sipariş anlık listeden düşer, client-side filter gerekmez
  ///  • limit(150) → Firestore→Flutter codec'in büyük payload OOM'unu önler
  Stream<List<OrderModel>> watchAllActiveOrders(int bayId) {
    return _db
        .collection(_ordersCol)
        .where('s_bay', isEqualTo: bayId)
        .where('s_stat', whereIn: _activeStats)
        .limit(150)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrderModel.fromDoc(d))
            .toList());
  }

  // ─────────────────────────────────────────────────────────────────────
  // KURYE YÖNETİMİ (KuryelerTab için)
  // ─────────────────────────────────────────────────────────────────────

  /// Bayiye ait TÜM kuryeleri anlık dinler (offline dahil — KuryelerTab)
  Stream<List<CourierModel>> watchAllCouriers(int bayId) {
    return _db
        .collection(_courierCol)
        .where('s_bay', isEqualTo: bayId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CourierModel.fromDoc(d)).toList());
  }

  /// Kurye statüsünü güncelle (0=Offline 1=Müsait 3=Molada 4=Kaza)
  Future<bool> updateCourierStatus({
    required String docId,
    required int newStat,
  }) async {
    try {
      await _db.collection(_courierCol).doc(docId).update({'s_stat': newStat});
      _log.i('Kurye statüsü güncellendi: $docId → $newStat');
      return true;
    } catch (e) {
      _log.e('Kurye statüsü güncellenemedi', error: e);
      return false;
    }
  }

  /// Yeni kurye ekle — s_id otomatik: bayideki max(s_id)+1
  Future<bool> addCourier({
    required int bayId,
    required String name,
    required String surname,
    String? phone,
    String? password,
  }) async {
    try {
      // Mevcut en büyük s_id'yi bul
      final snap = await _db
          .collection(_courierCol)
          .where('s_bay', isEqualTo: bayId)
          .orderBy('s_id', descending: true)
          .limit(1)
          .get();
      int nextId = 1001;
      if (snap.docs.isNotEmpty) {
        final maxId = (snap.docs.first.data()['s_id'] as num?)?.toInt() ?? 1000;
        nextId = maxId + 1;
      }

      await _db.collection(_courierCol).add({
        's_id':   nextId,
        's_stat': 0, // Offline — ilk oluşturmada çevrimdışı
        's_bay':  bayId,
        's_info': {
          'ss_name':     name.trim(),
          'ss_surname':  surname.trim(),
          'ss_phone':    phone?.trim() ?? '',
          'ss_password': password?.trim() ?? '',
        },
        's_loc':   null,
        's_cdate': FieldValue.serverTimestamp(),
      });
      _log.i('Yeni kurye eklendi: $name $surname (bayId: $bayId)');
      return true;
    } catch (e) {
      _log.e('Kurye eklenemedi', error: e);
      return false;
    }
  }

  /// Kurye bilgilerini güncelle (şifre boşsa değiştirme)
  Future<bool> updateCourier({
    required String docId,
    required String name,
    required String surname,
    String? phone,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{
        's_info.ss_name':    name.trim(),
        's_info.ss_surname': surname.trim(),
        's_info.ss_phone':   phone?.trim() ?? '',
      };
      if (password != null && password.trim().isNotEmpty) {
        data['s_info.ss_password'] = password.trim();
      }
      await _db.collection(_courierCol).doc(docId).update(data);
      _log.i('Kurye güncellendi: $docId');
      return true;
    } catch (e) {
      _log.e('Kurye güncellenemedi', error: e);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // AI ATAMA AYARLARI
  // ─────────────────────────────────────────────────────────────────────

  /// Bayiye ait AI atama ayarlarını çeker.
  /// Belge yoksa varsayılan değerlerle döner.
  Future<AiSettingsModel> fetchAiSettings(int bayId) async {
    try {
      final doc = await _db
          .collection(_aiSettingsCol)
          .doc(bayId.toString())
          .get();
      if (doc.exists && doc.data() != null) {
        return AiSettingsModel.fromMap(doc.data()!);
      }
      return AiSettingsModel.defaults(bayId);
    } catch (e) {
      _log.e('AI ayarları alınamadı', error: e);
      return AiSettingsModel.defaults(bayId);
    }
  }

  /// Ayarları Firestore'a kaydeder (merge: true — eksik alan silinmez).
  Future<bool> saveAiSettings(AiSettingsModel settings) async {
    try {
      await _db
          .collection(_aiSettingsCol)
          .doc(settings.bayId.toString())
          .set(
            {
              ...settings.toMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
      _log.i('AI ayarları kaydedildi (bayId: ${settings.bayId})');
      return true;
    } catch (e) {
      _log.e('AI ayarları kaydedilemedi', error: e);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────

  /// Tüm aktif kuryeleri anlık dinler (harita için)
  Stream<List<CourierModel>> watchActiveCouriersStream(int bayId) {
    return _db
        .collection(_courierCol)
        .where('s_bay', isEqualTo: bayId)
        .where('s_stat', isNotEqualTo: 0)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CourierModel.fromDoc(d)).toList());
  }

  /// Anlık atanmayan siparişleri dinler (s_courier == 0)
  Stream<List<OrderModel>> watchUnassignedOrders(int bayId) {
    return _db
        .collection(_ordersCol)
        .where('s_courier', isEqualTo: 0)
        .where('s_stat', whereIn: _activeStats)
        .where('s_bay', isEqualTo: bayId)
        .orderBy('s_cdate', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
  }

  /// Anlık atanmış siparişleri dinler (s_courier > 0)
  /// Composite index gerektiren filtreler client-side'a taşındı.
  Stream<List<OrderModel>> watchAssignedOrders(int bayId) {
    return _db
        .collection(_ordersCol)
        .where('s_bay', isEqualTo: bayId)
        .where('s_courier', isGreaterThan: 0)
        // NOT: .orderBy('s_courier') zorunlu (isGreaterThan için),
        // ek orderBy composite index gerektirir → client-side sort kullanılır
        .orderBy('s_courier')
        .limit(100)
        .snapshots()
        .map((snap) {
          final orders = snap.docs
              .map((d) => OrderModel.fromDoc(d))
              // Aktif durum filtresi — client-side (composite index yok)
              .where((o) => _activeStats.contains(o.sStat))
              .toList()
            // En yeni sipariş üstte
            ..sort((a, b) {
              if (a.sCdate == null) return 1;
              if (b.sCdate == null) return -1;
              return b.sCdate!.compareTo(a.sCdate!);
            });
          return orders;
        });
  }

  // ─────────────────────────────────────────────────────────────────────
  // KURYE İŞLEMLERİ
  // ─────────────────────────────────────────────────────────────────────

  /// Bayiye ait TÜM aktif kuryeleri getirir (s_stat != 0 yani online olanlar).
  /// Statü sırası: 1=Müsait, 2=Meşgul, 3=Molada, 4=Kaza
  Future<List<CourierModel>> fetchActiveCouriers(int bayId) async {
    try {
      final snap = await _db
          .collection(_courierCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', isNotEqualTo: 0) // offline olanları dışla
          .get();

      final couriers = snap.docs
          .map((d) => CourierModel.fromDoc(d))
          .where((c) => c.sStat != 0)
          .toList();

      // Sıralama: Müsait → Meşgul → Molada → Kaza
      couriers.sort((a, b) => a.sStat.compareTo(b.sStat));
      return couriers;
    } catch (e) {
      _log.e('Aktif kuryeler alınamadı', error: e);
      return [];
    }
  }

  /// Bayiye ait kurye istatistiklerini getirir.
  /// "Yolda" sayısı effectiveStatCode ile hesaplanır:
  ///   kurye s_stat == 3 → Molada  (sipariş durumuna bakılmaz)
  ///   kurye s_stat == 4 → Kaza    (sipariş durumuna bakılmaz)
  ///   kurye herhangi siparişi Yolda (s_stat==1) → Yolda
  ///   kurye siparişi var ama Yolda yok          → Meşgul
  ///   kurye siparişi yok                        → Müsait
  Future<CourierStats> fetchCourierStats(int bayId) async {
    try {
      // 1) Aktif kuryeler
      final courierSnap = await _db
          .collection(_courierCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', isNotEqualTo: 0)
          .get();

      if (courierSnap.docs.isEmpty) {
        return const CourierStats(available: 0, busy: 0, onBreak: 0);
      }

      final couriers = courierSnap.docs
          .map((d) => CourierModel.fromDoc(d))
          .toList();

      // 2) Bu bayin SADECE aktif siparişlerini çek (s_bay + s_stat index kullanır).
      // Önceki sorgu s_courier > 0 + no s_stat filter kullanıyordu → tüm tarihi
      // siparişler (teslim edilmiş dahil binlerce döküman) çekiliyordu → OOM.
      // Şimdi s_stat whereIn [0,1,4] ile yalnızca aktif dökümanlar gelir,
      // s_courier > 0 filtresi client-side uygulanır.
      final orderSnap = await _db
          .collection(_ordersCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', whereIn: _activeStats)
          .get();

      // courierId → {count, hasOnRoad}
      final Map<int, int>  orderCount  = {};
      final Map<int, bool> hasOnRoad   = {};

      for (final doc in orderSnap.docs) {
        final o = OrderModel.fromDoc(doc);
        if (o.sCourier <= 0) continue; // atanmamış siparişleri atla
        orderCount[o.sCourier]  = (orderCount[o.sCourier]  ?? 0) + 1;
        if (o.sStat == 1) hasOnRoad[o.sCourier] = true;
      }

      // 3) effectiveStatCode ile say
      int available = 0, busy = 0, onBreak = 0, onRoad = 0, accident = 0;
      for (final courier in couriers) {
        final code = courier.effectiveStatCode(
          orderCount:     orderCount[courier.sId]  ?? 0,
          hasOnRoadOrder: hasOnRoad[courier.sId]   ?? false,
        );
        switch (code) {
          case 1: available++; break;
          case 2: busy++;      break;
          case 3: onBreak++;   break;
          case 4: accident++;  break;
          case 5: onRoad++;    break;
        }
      }

      return CourierStats(
          available: available,
          busy: busy,
          onBreak: onBreak,
          onRoad: onRoad,
          accident: accident);
    } catch (e) {
      _log.e('Kurye istatistikleri alınamadı', error: e);
      return const CourierStats(available: 0, busy: 0, onBreak: 0);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // KURYE PAKET SAYISI
  // ─────────────────────────────────────────────────────────────────────

  /// Kurye üzerindeki aktif paket sayısını döndürür.
  /// Web ile aynı: s_stat in [0, 1] (Hazır ve Yolda)
  Future<int> fetchCourierOrderCount(int courierId) async {
    try {
      final snap = await _db
          .collection(_ordersCol)
          .where('s_courier', isEqualTo: courierId)
          .where('s_stat', whereIn: [0, 1])
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      _log.w('Kurye paket sayısı alınamadı (ID: $courierId)', error: e);
      return 0;
    }
  }

  /// Tüm kuryeler için paket sayılarını toplu getirir
  Future<Map<int, int>> fetchAllCourierOrderCounts(
      List<int> courierIds) async {
    if (courierIds.isEmpty) return {};
    final results = await Future.wait(
      courierIds.map((id) async => MapEntry(id, await fetchCourierOrderCount(id))),
    );
    return Map.fromEntries(results);
  }

  /// Kurye başına: aktif sipariş sayısı + yolda (s_stat==1) sipariş var mı?
  /// assign_courier_sheet ve harita için etkin durum hesabında kullanılır.
  Future<Map<int, ({int count, bool hasOnRoad})>> fetchAllCourierOrderDetails(
      List<int> courierIds) async {
    if (courierIds.isEmpty) return {};
    final results = await Future.wait(
      courierIds.map((id) async {
        try {
          final snap = await _db
              .collection(_ordersCol)
              .where('s_courier', isEqualTo: id)
              .where('s_stat', whereIn: [0, 1]) // Hazır ve Yolda
              .get();
          final count = snap.docs.length;
          final hasOnRoad = snap.docs.any(
            (d) => (d.data()['s_stat'] as num?)?.toInt() == 1,
          );
          return MapEntry(id, (count: count, hasOnRoad: hasOnRoad));
        } catch (_) {
          return MapEntry(id, (count: 0, hasOnRoad: false));
        }
      }),
    );
    return Map.fromEntries(results);
  }

  /// N ayrı sorgu yerine tek Firestore sorgusuyla tüm kuryenin sipariş
  /// detaylarını (sayı + yolda mı?) döner.
  /// `fetchAllCourierOrderDetails`'in bay bazlı, daha hızlı alternatifi.
  Future<Map<int, ({int count, bool hasOnRoad})>>
      fetchCourierOrderDetailsBatch(int bayId) async {
    try {
      final snap = await _db
          .collection(_ordersCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', whereIn: [0, 1]) // Hazır + Yolda
          .get();

      final Map<int, int>  countMap   = {};
      final Map<int, bool> onRoadMap  = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final courierId = (data['s_courier'] as num?)?.toInt() ?? 0;
        if (courierId <= 0) continue;
        countMap[courierId]  = (countMap[courierId]  ?? 0) + 1;
        if ((data['s_stat'] as num?)?.toInt() == 1) {
          onRoadMap[courierId] = true;
        }
      }

      // Tüm kuryeler için sonuç döndür (sipariş olmayan → count:0)
      final allIds = {...countMap.keys, ...onRoadMap.keys};
      return {
        for (final id in allIds)
          id: (count: countMap[id] ?? 0, hasOnRoad: onRoadMap[id] ?? false),
      };
    } catch (e) {
      _log.e('Toplu kurye sipariş detayları alınamadı', error: e);
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // SİPARİŞ ATAMA
  // ─────────────────────────────────────────────────────────────────────

  /// Siparişe kurye ata
  ///
  /// [courierToken] : Kurye FCM / Expo push token'ı (opsiyonel).
  /// [orderName]    : Bildirim metninde kullanılacak sipariş adı/ID.
  Future<bool> assignCourier({
    required String orderDocId,
    required int courierId,
    String? courierToken,
    String orderName = '',
    int previousCourierId = 0, // Yeniden atama durumunda eski kurye ID'si
  }) async {
    try {
      await _db.collection(_ordersCol).doc(orderDocId).update({
        's_courier': courierId,
        's_assigned_time': FieldValue.serverTimestamp(),
        's_adate': FieldValue.serverTimestamp(),
        's_courier_accepted': null,
        's_courier_response_time': null,
      });
      _log.i('Sipariş atandı: $orderDocId → Kurye: $courierId');

      // ── Eski kuryeye iptal bildirimi (yeniden atama) ──────────────────
      if (previousCourierId > 0 && previousCourierId != courierId) {
        _fetchCourierToken(previousCourierId).then((token) {
          if (token != null) _sendCancellationNotification(token);
        });
      }

      // ── Yeni kuryeye atama bildirimi ──────────────────────────────────
      if (courierToken != null && courierToken.isNotEmpty) {
        _sendAssignmentNotification(token: courierToken);
      }

      return true;
    } catch (e) {
      _log.e('Sipariş atanamadı', error: e);
      return false;
    }
  }

  /// Sipariş atamasını kaldır — eski kuryeye iptal bildirimi gönderir.
  Future<bool> unassignCourier({required String orderDocId}) async {
    try {
      // Mevcut kurye ID'sini oku (bildirim için)
      int prevCourierId = 0;
      try {
        final doc = await _db.collection(_ordersCol).doc(orderDocId).get();
        prevCourierId =
            (doc.data()?['s_courier'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      await _db.collection(_ordersCol).doc(orderDocId).update({
        's_courier': 0,
        's_stat': 0, // Hazır durumuna getir (web ile aynı)
      });
      _log.i('Sipariş ataması kaldırıldı: $orderDocId');

      // ── Eski kuryeye iptal bildirimi ──────────────────────────────────
      if (prevCourierId > 0) {
        _fetchCourierToken(prevCourierId).then((token) {
          if (token != null) _sendCancellationNotification(token);
        });
      }

      return true;
    } catch (e) {
      _log.e('Sipariş ataması kaldırılamadı', error: e);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // BİLDİRİM YARDIMCILARI
  // ─────────────────────────────────────────────────────────────────────

  /// `s_id` üzerinden kurye push token'ını getirir (fcmToken → expoPushToken).
  Future<String?> _fetchCourierToken(int courierId) async {
    if (courierId <= 0) return null;
    try {
      final snap = await _db
          .collection(_courierCol)
          .where('s_id', isEqualTo: courierId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final fcm  = data['fcmToken']      as String?;
      final expo = data['expoPushToken'] as String?;
      if (fcm  != null && fcm.isNotEmpty)  return fcm;
      if (expo != null && expo.isNotEmpty) return expo;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// "Yeni Sipariş Ataması!" bildirimi gönderir.
  Future<void> _sendAssignmentNotification({required String token}) async {
    await _postNotification(
      token: token,
      title: 'Yeni Sipariş Ataması!',
      body: 'Size yeni bir sipariş atandı, detaylar için kontrol ediniz.',
    );
  }

  /// "Sipariş Değişikliği" (iptal) bildirimi gönderir.
  Future<void> _sendCancellationNotification(String token) async {
    await _postNotification(
      token: token,
      title: 'Sipariş Değişikliği',
      body: 'Bir sipariş üzerinizden alındı.',
    );
  }

  /// Ortak push bildirim gönderim metodu.
  /// Hata durumunda log yazar, exception fırlatmaz.
  Future<void> _postNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final resp = await _dio.post<dynamic>(
        _pushNotifUrl,
        data: {
          'expoPushToken': token,
          'title': title,
          'body': body,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      _log.i('Push bildirim gönderildi [$title] (${resp.statusCode})');
    } catch (e) {
      _log.w('Push bildirim gönderilemedi [$title]: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // İŞLETME (t_work) BİLGİSİ
  // ─────────────────────────────────────────────────────────────────────

  /// Bayiye ait tüm işletmeleri getirir (harita marker'ları için)
  Future<List<WorkInfo>> fetchWorkInfos(int bayId) async {
    try {
      final snap = await _db
          .collection(_workCol)
          .where('s_bay', isEqualTo: bayId)
          .get();

      final result = <WorkInfo>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['s_id'] as num?)?.toInt() ?? 0;
        final name = (data['s_info'] as Map<String, dynamic>?)?['ss_name']
                as String? ??
            '';
        final locData = data['s_loc'];
        GeoPoint? geoPoint;
        if (locData is Map) {
          final loc = locData['ss_location'];
          if (loc is GeoPoint) geoPoint = loc;
        } else if (locData is GeoPoint) {
          geoPoint = locData;
        }
        if (geoPoint != null && name.isNotEmpty) {
          result.add(WorkInfo(id: id, name: name, location: geoPoint));
        }
      }
      return result;
    } catch (e) {
      _log.e('İşletme bilgileri alınamadı', error: e);
      return [];
    }
  }

  /// Kurye rotasını Google Directions API ile hesaplar.
  /// Hata durumunda kurye → sipariş noktaları arası düz çizgi döner.
  Future<List<_LatLngPoint>> fetchCourierRoute({
    required double courierLat,
    required double courierLng,
    required List<OrderModel> orders,
  }) async {
    final orderPoints = orders
        .where((o) => o.sCustomer.ssLoc != null)
        .map((o) => _LatLngPoint(
              o.sCustomer.ssLoc!.latitude,
              o.sCustomer.ssLoc!.longitude,
            ))
        .toList();

    if (orderPoints.isEmpty) {
      return [_LatLngPoint(courierLat, courierLng)];
    }

    // Nearest-neighbor sıralaması
    final sorted = _nearestNeighbor(
      startLat: courierLat,
      startLng: courierLng,
      points: orderPoints,
    );

    try {
      final origin = '$courierLat,$courierLng';
      final destination = '${sorted.last.lat},${sorted.last.lng}';

      final queryParams = <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'mode': 'driving',
        'language': 'tr',
        'key': AppConstants.googleMapsApiKey,
      };

      if (sorted.length > 1) {
        queryParams['waypoints'] = sorted
            .sublist(0, sorted.length - 1)
            .map((p) => '${p.lat},${p.lng}')
            .join('|');
      }

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final polylineStr =
                routes[0]['overview_polyline']['points'] as String;
            return _decodePolyline(polylineStr);
          }
        }
      }
    } catch (e) {
      _log.w('Directions API hatası, düz çizgi kullanılıyor', error: e);
    }

    // Fallback: düz çizgi
    final fallback = <_LatLngPoint>[_LatLngPoint(courierLat, courierLng)];
    for (final p in sorted) {
      fallback.add(p);
    }
    return fallback;
  }

  /// Google Encoded Polyline decoder
  List<_LatLngPoint> _decodePolyline(String encoded) {
    final points = <_LatLngPoint>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(_LatLngPoint(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Nearest-neighbor algoritması ile sipariş noktalarını sıralar
  List<_LatLngPoint> _nearestNeighbor({
    required double startLat,
    required double startLng,
    required List<_LatLngPoint> points,
  }) {
    if (points.isEmpty) return [];
    final sorted = <_LatLngPoint>[];
    var remaining = List<_LatLngPoint>.from(points);
    var curLat = startLat, curLng = startLng;
    while (remaining.isNotEmpty) {
      final nearest = remaining.reduce((a, b) {
        final da = _sqDist(curLat, curLng, a.lat, a.lng);
        final db = _sqDist(curLat, curLng, b.lat, b.lng);
        return da < db ? a : b;
      });
      sorted.add(nearest);
      remaining.remove(nearest);
      curLat = nearest.lat;
      curLng = nearest.lng;
    }
    return sorted;
  }

  double _sqDist(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return dLat * dLat + dLng * dLng;
  }

  /// İşletme konumunu (GeoPoint) getirir — mesafe hesabı için kullanılır
  Future<GeoPoint?> fetchWorkLocation(int workId) async {
    try {
      final snap = await _db
          .collection(_workCol)
          .where('s_id', isEqualTo: workId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final loc = data['s_loc'];
      if (loc is Map) {
        final gp = loc['ss_location'];
        if (gp is GeoPoint) return gp;
      }
      return null;
    } catch (e) {
      _log.e('İşletme konumu alınamadı', error: e);
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // MESAFE HESABI
  // ─────────────────────────────────────────────────────────────────────

  /// Google Maps Distance Matrix API ile GERÇEK YOL mesafesi hesaplar.
  /// Hata durumunda Haversine (kuş uçuşu) fallback devreye girer.
  Future<RouteDistance> calculateRouteDistance({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    // ── Google Maps Distance Matrix API ──────────────────
    try {
      const baseUrl =
          'https://maps.googleapis.com/maps/api/distancematrix/json';

      final response = await _dio.get(
        baseUrl,
        queryParameters: {
          'origins': '$fromLat,$fromLng',
          'destinations': '$toLat,$toLng',
          'mode': 'driving',
          'language': 'tr',
          'key': AppConstants.googleMapsApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rows = data['rows'] as List?;
        if (rows != null && rows.isNotEmpty) {
          final elements = (rows[0] as Map)['elements'] as List?;
          if (elements != null && elements.isNotEmpty) {
            final element = elements[0] as Map<String, dynamic>;
            final status = element['status'] as String?;

            if (status == 'OK') {
              final distMeters =
                  (element['distance']['value'] as num).toDouble();
              final durSecs =
                  (element['duration']['value'] as num).toDouble();

              return RouteDistance(
                km: distMeters / 1000,
                durationMinutes: durSecs / 60,
                isRouteBased: true,
              );
            }
          }
        }
      }
    } catch (e) {
      _log.w('Google Maps Distance Matrix hatası, kuş uçuşu kullanılıyor',
          error: e);
    }

    // ── Fallback: Haversine (kuş uçuşu) ──────────────────
    final straight = _haversine(fromLat, fromLng, toLat, toLng);
    return RouteDistance(
      km: straight,
      durationMinutes: null,
      isRouteBased: false,
    );
  }

  /// N kurye için tek bir Distance Matrix API çağrısıyla mesafe hesaplar.
  ///
  /// [origins]   : Her kurye için {lat, lng} listesi (index sırası korunur).
  /// [toLat/toLng]: Tek hedef nokta (işletme konumu).
  ///
  /// Dönen liste `origins` ile aynı index sırasına sahiptir.
  /// Herhangi bir kurye için konum yoksa index'e `null` döner.
  /// API hatası durumunda Haversine fallback kullanılır.
  Future<List<RouteDistance?>> calculateBatchDistances({
    required List<CourierLocation?> origins,
    required double toLat,
    required double toLng,
  }) async {
    // Konum olmayan kuryelere null placeholder ekle
    final validIdx  = <int>[];     // origins içindeki geçerli indeksler
    final origParts = <String>[];  // "lat,lng" parçaları

    for (int i = 0; i < origins.length; i++) {
      final loc = origins[i];
      if (loc != null) {
        validIdx.add(i);
        origParts.add('${loc.lat},${loc.lng}');
      }
    }

    // Sonuç listesini null ile başlat
    final results = List<RouteDistance?>.filled(origins.length, null);

    if (validIdx.isEmpty) return results;

    // ── Google Maps Distance Matrix (tüm kuryeler tek istekte) ────────────
    try {
      const baseUrl =
          'https://maps.googleapis.com/maps/api/distancematrix/json';

      final response = await _dio.get(
        baseUrl,
        queryParameters: {
          'origins'     : origParts.join('|'),
          'destinations': '$toLat,$toLng',
          'mode'        : 'driving',
          'language'    : 'tr',
          'key'         : AppConstants.googleMapsApiKey,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rows = data['rows'] as List?;

        if (rows != null) {
          for (int r = 0; r < rows.length && r < validIdx.length; r++) {
            final elements = (rows[r] as Map)['elements'] as List?;
            if (elements == null || elements.isEmpty) continue;
            final element = elements[0] as Map<String, dynamic>;
            if ((element['status'] as String?) == 'OK') {
              final distM = (element['distance']['value'] as num).toDouble();
              final durS  = (element['duration']['value']  as num).toDouble();
              results[validIdx[r]] = RouteDistance(
                km: distM / 1000,
                durationMinutes: durS / 60,
                isRouteBased: true,
              );
            }
          }
        }
      }
    } catch (e) {
      _log.w('Batch Distance Matrix hatası, Haversine devreye giriyor: $e');
    }

    // ── Fallback: API'den sonuç alamayan her kurye için Haversine ─────────
    for (int i = 0; i < origins.length; i++) {
      if (results[i] == null) {
        final loc = origins[i];
        if (loc != null) {
          final km = _haversine(loc.lat, loc.lng, toLat, toLng);
          results[i] = RouteDistance(km: km, durationMinutes: null, isRouteBased: false);
        }
      }
    }

    return results;
  }

  /// Haversine formülü ile kuş uçuşu mesafe (km)
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Dünya yarıçapı km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  // ─────────────────────────────────────────────────────────────────────
  // GÜNLÜK İSTATİSTİK
  // ─────────────────────────────────────────────────────────────────────

  /// Bugün teslim edilen ve iade edilen sipariş sayılarını getirir
  Future<DailyDeliveryStats> fetchDailyStats(int bayId) async {
    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = startOfDay + 24 * 60 * 60 * 1000;

      final startTs = Timestamp.fromMillisecondsSinceEpoch(startOfDay);
      final endTs = Timestamp.fromMillisecondsSinceEpoch(endOfDay);

      final deliveredSnap = await _db
          .collection(_ordersCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', isEqualTo: 2) // Teslim edildi
          .where('s_cdate', isGreaterThanOrEqualTo: startTs)
          .where('s_cdate', isLessThan: endTs)
          .count()
          .get();

      final returnedSnap = await _db
          .collection(_ordersCol)
          .where('s_bay', isEqualTo: bayId)
          .where('s_stat', isEqualTo: 5) // İade edildi
          .where('s_cdate', isGreaterThanOrEqualTo: startTs)
          .where('s_cdate', isLessThan: endTs)
          .count()
          .get();

      return DailyDeliveryStats(
        delivered: deliveredSnap.count ?? 0,
        returned: returnedSnap.count ?? 0,
      );
    } catch (e) {
      _log.e('Günlük istatistikler alınamadı', error: e);
      return const DailyDeliveryStats(delivered: 0, returned: 0);
    }
  }
}

// ── Yardımcı veri sınıfları ───────────────────────────────────────────────────

class CourierStats {
  final int available; // Müsait  (s_stat == 1)
  final int busy;      // Meşgul  (s_stat == 2)
  final int onBreak;   // Molada  (s_stat == 3)
  final int onRoad;    // Yolda   (effectiveStatCode == 5)
  final int accident;  // Kaza    (s_stat == 4)

  const CourierStats({
    required this.available,
    required this.busy,
    required this.onBreak,
    this.onRoad = 0,
    this.accident = 0,
  });

  int get total => available + busy + onBreak + onRoad + accident;
}

class DailyDeliveryStats {
  final int delivered;
  final int returned;

  const DailyDeliveryStats({
    required this.delivered,
    required this.returned,
  });
}

/// İşletme bilgisi (harita marker'ları için)
class WorkInfo {
  final int id;
  final String name;
  final GeoPoint location;

  const WorkInfo({
    required this.id,
    required this.name,
    required this.location,
  });
}

/// Dahili: lat/lng noktası (route hesabı için)
class _LatLngPoint {
  final double lat, lng;
  const _LatLngPoint(this.lat, this.lng);
}

class RouteDistance {
  final double km;
  final double? durationMinutes;
  final bool isRouteBased;

  const RouteDistance({
    required this.km,
    this.durationMinutes,
    required this.isRouteBased,
  });

  String get displayText {
    final kmStr = km.toStringAsFixed(1);
    final suffix = isRouteBased ? '' : '~';
    if (durationMinutes != null) {
      final min = durationMinutes!.round();
      return '$suffix${kmStr}km · ${min}dk';
    }
    return '$suffix${kmStr}km';
  }
}
