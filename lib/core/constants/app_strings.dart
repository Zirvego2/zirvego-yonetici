/// Uygulama metin sabitleri
abstract class AppStrings {
  // ── Genel ─────────────────────────────────────────────────
  static const String appName = 'ZirveGo Yönetici';
  static const String ok = 'Tamam';
  static const String cancel = 'İptal';
  static const String save = 'Kaydet';
  static const String delete = 'Sil';
  static const String edit = 'Düzenle';
  static const String close = 'Kapat';
  static const String confirm = 'Onayla';
  static const String retry = 'Tekrar Dene';
  static const String loading = 'Yükleniyor...';
  static const String search = 'Ara...';
  static const String noData = 'Veri bulunamadı';
  static const String noInternet = 'İnternet bağlantısı yok';
  static const String error = 'Bir hata oluştu';
  static const String success = 'İşlem başarılı';

  // ── Auth ──────────────────────────────────────────────────
  static const String login = 'Giriş Yap';
  static const String logout = 'Çıkış Yap';
  static const String register = 'Kayıt Ol';
  static const String forgotPassword = 'Şifremi Unuttum';
  static const String resetPassword = 'Şifreyi Sıfırla';
  static const String email = 'E-posta';
  static const String password = 'Şifre';
  static const String confirmPassword = 'Şifre Tekrarı';
  static const String fullName = 'Ad Soyad';
  static const String phone = 'Telefon';
  static const String welcomeBack = 'Tekrar Hoşgeldiniz';
  static const String loginSubtitle = 'Yönetici panelinize giriş yapın';
  static const String emailHint = 'ornek@zirvego.com';
  static const String passwordHint = 'En az 8 karakter';
  static const String loginButton = 'Giriş Yap';
  static const String noAccount = 'Hesabınız yok mu? ';
  static const String haveAccount = 'Zaten hesabınız var mı? ';
  static const String signUp = 'Kayıt Olun';
  static const String signIn = 'Giriş Yapın';

  // ── Doğrulama Mesajları ────────────────────────────────────
  static const String requiredField = 'Bu alan zorunludur';
  static const String invalidEmail = 'Geçerli bir e-posta adresi girin';
  static const String passwordTooShort = 'Şifre en az 8 karakter olmalıdır';
  static const String passwordsNotMatch = 'Şifreler eşleşmiyor';
  static const String invalidPhone = 'Geçerli bir telefon numarası girin';

  // ── Dashboard ─────────────────────────────────────────────
  static const String dashboard = 'Ana Panel';
  static const String overview = 'Genel Bakış';
  static const String totalUsers = 'Toplam Kullanıcı';
  static const String activeUsers = 'Aktif Kullanıcı';
  static const String totalRevenue = 'Toplam Gelir';
  static const String monthlyGrowth = 'Aylık Büyüme';
  static const String recentActivity = 'Son Aktiviteler';
  static const String quickActions = 'Hızlı İşlemler';

  // ── Profil ────────────────────────────────────────────────
  static const String profile = 'Profil';
  static const String settings = 'Ayarlar';
  static const String notifications = 'Bildirimler';
  static const String security = 'Güvenlik';
  static const String helpSupport = 'Yardım & Destek';
  static const String about = 'Hakkında';
  static const String version = 'Versiyon';
  static const String logoutConfirm = 'Çıkış yapmak istediğinizden emin misiniz?';

  // ── Hata Mesajları ────────────────────────────────────────
  static const String authError = 'Kimlik doğrulama hatası';
  static const String networkError = 'Ağ bağlantısı hatası';
  static const String serverError = 'Sunucu hatası';
  static const String unknownError = 'Bilinmeyen bir hata oluştu';
  static const String sessionExpired = 'Oturumunuzun süresi doldu, lütfen tekrar giriş yapın';
  static const String permissionDenied = 'Bu işlem için yetkiniz bulunmuyor';
}
