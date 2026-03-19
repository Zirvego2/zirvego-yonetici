import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Güncelleme kontrolünün sonucu
enum UpdateStatus {
  /// Uygulama güncel, güncelleme gerekmez
  upToDate,

  /// Yeni sürüm var, kullanıcı erteleyebilir
  optional,

  /// Yeni sürüm var ve güncelleme zorunludur (force_update: true)
  forced,
}

/// Firestore'dan güncelleme bilgisini okur ve mevcut versiyon ile karşılaştırır.
///
/// Koleksiyon : app_version
/// Doküman    : zirvego-yönetici
class UpdateCheckService {
  UpdateCheckService._();
  static final UpdateCheckService instance = UpdateCheckService._();

  final _db  = FirebaseFirestore.instance;
  final _log = Logger();

  static const _collection = 'app_version';
  static const _document   = 'zirvego-yönetici';

  // ─────────────────────────────────────────────────────────────────────────
  // Güncelleme Kontrolü
  // ─────────────────────────────────────────────────────────────────────────

  /// Güncelleme durumunu döndürür.
  /// Hata durumunda [UpdateStatus.upToDate] döner → uygulama normal açılır.
  Future<UpdateResult> checkForUpdate() async {
    try {
      final doc = await _db
          .collection(_collection)
          .doc(_document)
          .get();

      if (!doc.exists) return UpdateResult.upToDate();

      final data          = doc.data()!;
      final latestVersion = (data['latest_version'] as String? ?? '').trim();
      final forceUpdate   = data['force_update'] as bool? ?? false;
      final apkUrl        = data['apk_url']       as String? ?? '';
      final iosUrl        = data['ios_url']        as String? ?? '';
      final releaseNotes  = data['release_notes']  as String? ?? '';

      // Firestore'da versiyon boşsa güncelleme yok
      if (latestVersion.isEmpty) return UpdateResult.upToDate();

      final info           = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // ör: "2.1.2"

      final needsUpdate = _isNewer(latestVersion, currentVersion);

      if (!needsUpdate) return UpdateResult.upToDate();

      final status = forceUpdate ? UpdateStatus.forced : UpdateStatus.optional;

      return UpdateResult(
        status:       status,
        latestVersion: latestVersion,
        apkUrl:       apkUrl,
        iosUrl:       iosUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      _log.w('Güncelleme kontrolü başarısız (görmezden gelindi): $e');
      return UpdateResult.upToDate();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Versiyon Karşılaştırma
  // ─────────────────────────────────────────────────────────────────────────

  /// [candidate] sürümü [current]'tan yeni mi?
  /// "2.2.0" > "2.1.2" → true
  bool _isNewer(String candidate, String current) {
    final c = _parseVersion(candidate);
    final v = _parseVersion(current);
    for (int i = 0; i < 3; i++) {
      if (c[i] > v[i]) return true;
      if (c[i] < v[i]) return false;
    }
    return false; // eşit
  }

  List<int> _parseVersion(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sonuç Modeli
// ─────────────────────────────────────────────────────────────────────────────

class UpdateResult {
  final UpdateStatus status;
  final String latestVersion;
  final String apkUrl;
  final String iosUrl;
  final String releaseNotes;

  const UpdateResult({
    required this.status,
    this.latestVersion = '',
    this.apkUrl        = '',
    this.iosUrl        = '',
    this.releaseNotes  = '',
  });

  factory UpdateResult.upToDate() =>
      const UpdateResult(status: UpdateStatus.upToDate);

  bool get isForced   => status == UpdateStatus.forced;
  bool get isOptional => status == UpdateStatus.optional;
  bool get needsUpdate => status != UpdateStatus.upToDate;
}
