/// Uygulama geneli sabitler
abstract class AppConstants {
  // ── Uygulama Bilgileri ───────────────────────────────────
  static const String appName = 'ZirveGo Yönetici';
  static const String appVersion = '1.0.0';
  static const String companyName = 'ZirveGo';

  // ── Google Maps ──────────────────────────────────────────
  static const String googleMapsApiKey =
      'AIzaSyBpgppKBVULdvG8yHq8F57TljP9PpXTvCM';

  // ── Firebase Koleksiyonları ───────────────────────────────
  static const String tBayCollection = 't_bay';
  static const String tOrdersCollection = 't_orders';
  static const String tCourierCollection = 't_courier';
  static const String tWorkCollection = 't_work';
  static const String usersCollection = 'users';
  static const String settingsCollection = 'settings';
  static const String logsCollection = 'logs';
  static const String notificationsCollection = 'notifications';

  // ── Storage ───────────────────────────────────────────────
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyAuthToken = 'auth_token';

  // ── Boyutlar ──────────────────────────────────────────────
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  static const double radiusSM = 6.0;
  static const double radiusMD = 10.0;
  static const double radiusLG = 14.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 30.0;

  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;

  // ── Animasyon Süreleri ────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animVerySlow = Duration(milliseconds: 800);

  // ── Pagination ────────────────────────────────────────────
  static const int pageSize = 20;
  static const int maxRetryCount = 3;

  // ── Validation ────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxDescLength = 500;
  static const int otpLength = 6;

  // ── Tarih Formatları ──────────────────────────────────────
  static const String dateFormatDisplay = 'dd MMM yyyy';
  static const String dateFormatShort = 'dd.MM.yyyy';
  static const String dateTimeFormat = 'dd.MM.yyyy HH:mm';
  static const String timeFormat = 'HH:mm';

  // ── Kullanıcı Rolleri ─────────────────────────────────────
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleUser = 'user';
}
