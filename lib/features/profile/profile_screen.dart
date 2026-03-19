import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/order_color_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/bay_model.dart';
import 'account_info_screen.dart' show AccountInfoSheet;
import 'app_settings_screen.dart';
import 'order_color_settings_screen.dart';
import 'security_screen.dart';
// ── Rapor sayfaları ──────────────────────────────────────────────────────────
import '../raporlar/en_yogun_saatler_screen.dart';
import '../raporlar/siparisler_screen.dart';
import '../raporlar/kurye_raporu_screen.dart';
import '../raporlar/izin_plani_screen.dart';
import '../raporlar/vardiya_takip_screen.dart';
import '../raporlar/odeme_degisiklikleri_screen.dart';
import '../raporlar/kurye_performans_screen.dart';
import '../raporlar/kurye_nakitleri_screen.dart';
import '../raporlar/kurye_kazanc_screen.dart';
import '../raporlar/gunluk_siparis_raporu_screen.dart';
import '../raporlar/teslim_sure_raporu_screen.dart';
import '../raporlar/isletme_tahsilat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const ProfileTab(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANA PROFİL SEKMESİ
// ─────────────────────────────────────────────────────────────────────────────

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  BayModel? _user;
  bool _loading = true;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final auth = AuthService.instance.currentUser;
    if (auth == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await _firestore
          .collection(AppConstants.tBayCollection)
          .doc(auth.docId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _user = BayModel.fromMap(doc.data()!, doc.id);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('Çıkış Yap'),
        content: const Text(
            'Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  // ── Sayfa açıldığında verileri yenile ──────────────────────────────────────
  void _openPage(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page));
    // Geri döndükten sonra kullanıcı verisini yenile
    _loadUser();
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final user = _user;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded,
                size: 48, color: AppColors.textHint.withAlpha(120)),
            const SizedBox(height: 12),
            const Text('Kullanıcı verisi yüklenemedi'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadUser,
                child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header ─────────────────────────────────────────
        _buildHeader(user),
        const SizedBox(height: 24),

        // ── Menü Bölümleri ─────────────────────────────────
        _menuSection(
          context,
          title: 'Hesap',
          items: [
            _MenuItem(
              icon: Icons.business_center_rounded,
              iconColor: AppColors.primary,
              title: 'Hesap Bilgileri',
              subtitle: user.displayName,
              onTap: () async {
                await AccountInfoSheet.show(context);
                _loadUser(); // kapandıktan sonra yenile
              },
            ),
            _MenuItem(
              icon: Icons.security_rounded,
              iconColor: AppColors.error,
              title: 'Güvenlik',
              subtitle: 'Şifre ve giriş ayarları',
              onTap: () => _openPage(const SecurityScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _menuSection(
          context,
          title: 'Uygulama',
          items: [
            _MenuItem(
              icon: Icons.settings_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Uygulama Ayarları',
              subtitle: 'Kurye, sipariş ve işletme tercihleri',
              onTap: () => _openPage(const AppSettingsScreen()),
            ),
            _MenuItem(
              icon: Icons.palette_rounded,
              iconColor: const Color(0xFFEC4899),
              title: 'Sipariş Renk Eşikleri',
              subtitle: 'Bekleme süresine göre kart renkleri',
              onTap: () => _openPage(const OrderColorSettingsScreen()),
              trailing: _colorDots(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Sipariş Raporları ───────────────────────────────
        _menuSection(
          context,
          title: 'Sipariş Raporları',
          items: [
            _MenuItem(
              icon:      Icons.receipt_long_rounded,
              iconColor: AppColors.primary,
              title:     'Teslim & İptal Siparişler',
              subtitle:  'Tamamlanan, iptal ve iade siparişler',
              onTap:     () => _openPage(const SiparislerScreen()),
            ),
            _MenuItem(
              icon:      Icons.access_time_rounded,
              iconColor: const Color(0xFFF59E0B),
              title:     'En Yoğun Saatlerim',
              subtitle:  'Günlük sipariş yoğunluğuna göre saat analizi',
              onTap:     () => _openPage(const EnYogunSaatlerScreen()),
            ),
            _MenuItem(
              icon:      Icons.calendar_month_rounded,
              iconColor: const Color(0xFF6366F1),
              title:     'Günlük Sipariş Raporu',
              subtitle:  'Güne göre sipariş özeti ve istatistikler',
              onTap:     () => _openPage(const GunlukSiparisRaporuScreen()),
            ),
            _MenuItem(
              icon:      Icons.timer_rounded,
              iconColor: const Color(0xFFEC4899),
              title:     'Kurye Teslim Süre Raporu',
              subtitle:  'Ortalama hazırlık ve teslimat süreleri',
              onTap:     () => _openPage(const TeslimSureRaporuScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Kurye Yönetimi ──────────────────────────────────
        _menuSection(
          context,
          title: 'Kurye Raporları',
          items: [
            _MenuItem(
              icon:      Icons.bar_chart_rounded,
              iconColor: const Color(0xFF276749),
              title:     'Kurye Raporu',
              subtitle:  'Kurye bazlı sipariş, teslim ve iptal özeti',
              onTap:     () => _openPage(const KuryeRaporuScreen()),
            ),
            _MenuItem(
              icon:      Icons.leaderboard_rounded,
              iconColor: const Color(0xFF0891B2),
              title:     'Kurye Performans',
              subtitle:  'Teslimat oranı ve hız sıralaması',
              onTap:     () => _openPage(const KuryePerformansScreen()),
            ),
            _MenuItem(
              icon:      Icons.savings_rounded,
              iconColor: const Color(0xFF10B981),
              title:     'Kurye Kazanç',
              subtitle:  'Teslim başına ücret hesabı',
              onTap:     () => _openPage(const KuryeKazancScreen()),
            ),
            _MenuItem(
              icon:      Icons.event_available_rounded,
              iconColor: const Color(0xFFF59E0B),
              title:     'Kurye İzin Planı',
              subtitle:  'Haftalık izin ve tatil planları',
              onTap:     () => _openPage(const IzinPlaniScreen()),
            ),
            _MenuItem(
              icon:      Icons.schedule_rounded,
              iconColor: const Color(0xFF7C3AED),
              title:     'Kurye Vardiya Takip',
              subtitle:  'Vardiya başlangıç, bitiş ve molalar',
              onTap:     () => _openPage(const VardiyaTakipScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Finans ─────────────────────────────────────────
        _menuSection(
          context,
          title: 'Finans',
          items: [
            _MenuItem(
              icon:      Icons.payments_rounded,
              iconColor: const Color(0xFFEF4444),
              title:     'Kurye Üzerindeki Nakit',
              subtitle:  'Kuryedeki nakit işlem kayıtları',
              onTap:     () => _openPage(const KuryeNakitleriScreen()),
            ),
            _MenuItem(
              icon:      Icons.currency_exchange_rounded,
              iconColor: const Color(0xFFB7860B),
              title:     'Ödeme Değişiklikleri',
              subtitle:  'Ödeme düzeltmeleri ve düzensizlikler',
              onTap:     () => _openPage(const OdemeDegisiklikleriScreen()),
            ),
            _MenuItem(
              icon:      Icons.store_rounded,
              iconColor: const Color(0xFF9333EA),
              title:     'İşletme Tahsilat',
              subtitle:  'İşletme bazlı sipariş ve tahsilat özeti',
              onTap:     () => _openPage(const IsletmeTahsilatScreen()),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Çıkış ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.error, size: 18),
            label: const Text('Çıkış Yap',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'ID: ${user.sId}  •  ZirveGo Yönetici v1.0',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────

  Widget _buildHeader(BayModel u) {
    final initial =
        u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?';
    final created = u.sCreate != null
        ? 'Kayıt: ${DateFormat('dd.MM.yyyy').format(u.sCreate!)}'
        : '';

    return Container(
      width: double.infinity,
      decoration:
          const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withAlpha(90), width: 3),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(height: 14),

          Text(u.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 5),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('@${u.username}',
                style: TextStyle(
                    color: Colors.white.withAlpha(215),
                    fontSize: 13,
                    fontFamily: 'Poppins')),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (u.district.isNotEmpty || u.city.isNotEmpty)
                _hChip(Icons.location_on_outlined,
                    '${u.district}, ${u.city}'),
              if (u.sPhone.isNotEmpty)
                _hChip(Icons.phone_outlined, u.sPhone),
              if (created.isNotEmpty)
                _hChip(Icons.calendar_today_outlined, created),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hChip(IconData icon, String text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white.withAlpha(200)),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(210))),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────
  // MENÜ BÖLÜMÜ
  // ─────────────────────────────────────────────────────────

  Widget _menuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  _buildMenuTile(item),
                  if (!isLast)
                    const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 62,
                        color: AppColors.divider),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // İkon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconColor.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 20, color: item.iconColor),
            ),
            const SizedBox(width: 14),

            // Başlık + alt başlık
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Sağ: özel trailing veya ok
            if (item.trailing != null) ...[
              item.trailing!,
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  // Renk eşikleri önizleme noktalı widget
  Widget _colorDots() {
    final colors = [
      OrderColorService.instance.unassigned.first.color,
      OrderColorService.instance.unassigned.last.color,
      OrderColorService.instance.onRoadColor,
    ];
    return SizedBox(
      width: 50,
      height: 20,
      child: Stack(
        children: colors.asMap().entries.map((e) {
          return Positioned(
            left: e.key * 14.0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: e.value,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: e.value.withAlpha(60),
                      blurRadius: 3,
                      offset: const Offset(0, 1))
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Menü öğesi modeli
class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
}
