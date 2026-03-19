import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../../shared/models/bay_model.dart';

/// Firestore t_bay koleksiyonu üzerinden kimlik doğrulama servisi
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _log = Logger();

  // ── Oturum Durumu ─────────────────────────────────────────
  BayModel? _currentUser;
  BayModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Router'ın dinleyeceği auth durum bildirimi
  final ValueNotifier<bool> authStateNotifier = ValueNotifier(false);

  // ── Başlangıç Yüklemesi ───────────────────────────────────
  /// Uygulama açılışında secure storage'dan oturumu yükler
  Future<void> init() async {
    try {
      final isLoggedIn =
          await _secureStorage.read(key: AppConstants.keyIsLoggedIn);
      final docId = await _secureStorage.read(key: AppConstants.keyUserId);

      if (isLoggedIn == 'true' && docId != null && docId.isNotEmpty) {
        final doc = await _firestore
            .collection(AppConstants.tBayCollection)
            .doc(docId)
            .get();

        if (doc.exists && doc.data() != null) {
          _currentUser = BayModel.fromMap(doc.data()!, doc.id);
          authStateNotifier.value = true;
          _log.i('Oturum yüklendi: ${_currentUser!.username}');
        } else {
          await _clearSession();
        }
      }
    } catch (e) {
      _log.e('Oturum yükleme hatası', error: e);
      await _clearSession();
    }
  }

  // ── Kullanıcı Adı ile Giriş ───────────────────────────────
  /// t_bay koleksiyonunda s_username ve s_password eşleşmesini kontrol eder
  Future<AuthResult> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final query = await _firestore
          .collection(AppConstants.tBayCollection)
          .where('s_username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return AuthResult.failure(message: 'Kullanıcı adı veya şifre hatalı');
      }

      final doc = query.docs.first;
      final data = doc.data();
      final storedPassword = data['s_password'] as String? ?? '';

      if (storedPassword != password.trim()) {
        return AuthResult.failure(message: 'Kullanıcı adı veya şifre hatalı');
      }

      _currentUser = BayModel.fromMap(data, doc.id);

      // Oturumu güvenli depoya kaydet
      await _secureStorage.write(
          key: AppConstants.keyIsLoggedIn, value: 'true');
      await _secureStorage.write(
          key: AppConstants.keyUserId, value: doc.id);

      authStateNotifier.value = true;
      _log.i('Giriş başarılı: ${_currentUser!.username}');
      return AuthResult.success(user: _currentUser);
    } on FirebaseException catch (e) {
      _log.e('Firestore giriş hatası', error: e);
      return AuthResult.failure(
          message: 'Bağlantı hatası: ${e.message ?? e.code}');
    } catch (e) {
      _log.e('Giriş hatası', error: e);
      return AuthResult.failure(message: 'Beklenmeyen bir hata oluştu');
    }
  }

  // ── Çıkış ─────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _clearSession();
      _log.i('Kullanıcı çıkış yaptı');
    } catch (e) {
      _log.e('Çıkış hatası', error: e);
    }
  }

  // ── Yardımcı ──────────────────────────────────────────────
  Future<void> _clearSession() async {
    _currentUser = null;
    authStateNotifier.value = false;
    await _secureStorage.delete(key: AppConstants.keyIsLoggedIn);
    await _secureStorage.delete(key: AppConstants.keyUserId);
  }
}

/// Auth işlem sonucu
class AuthResult {
  final bool isSuccess;
  final String? message;
  final BayModel? user;

  const AuthResult._({
    required this.isSuccess,
    this.message,
    this.user,
  });

  factory AuthResult.success({BayModel? user, String? message}) {
    return AuthResult._(isSuccess: true, user: user, message: message);
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(isSuccess: false, message: message);
  }
}
