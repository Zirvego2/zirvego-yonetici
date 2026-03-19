import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/bay_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UYGULAMA AYARLARI SAYFASI
// ─────────────────────────────────────────────────────────────────────────────

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  BayModel? _user;
  bool _loading = true;
  bool _saving = false;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  Future<void> _update(String field, dynamic value) async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      await _firestore
          .collection(AppConstants.tBayCollection)
          .doc(_user!.docId)
          .update({field: value});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ayar kaydedildi'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Uygulama Ayarları',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Poppins'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      const Text('Veriler yüklenemedi'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _buildBody(_user!),
    );
  }

  Widget _buildBody(BayModel u) {
    final s = u.sSettings;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Açıklama kartı ──────────────────────────────
            _infoCard(),
            const SizedBox(height: 16),

            // ── Kurye Ayarları ──────────────────────────────
            _sectionLabel('Kurye Ayarları', Icons.delivery_dining_rounded,
                const Color(0xFF6366F1)),
            const SizedBox(height: 8),
            _card([
              _toggleTile(
                icon: Icons.block_rounded,
                iconColor: AppColors.error,
                label: 'Kurye Sipariş Reddi',
                sub: 'Kuryeler atanan siparişi reddedebilir',
                value: s.courierOrderRejectEnabled,
                onChanged: (v) async {
                  await _update('s_settings.courierOrderRejectEnabled', v);
                  await _update('s_settings.updatedAt', Timestamp.now());
                },
              ),
            ]),
            const SizedBox(height: 20),

            // ── Sipariş Ayarları ────────────────────────────
            _sectionLabel('Sipariş Ayarları', Icons.receipt_long_rounded,
                AppColors.primary),
            const SizedBox(height: 8),
            _card([
              _toggleTile(
                icon: Icons.visibility_rounded,
                iconColor: AppColors.info,
                label: 'Sipariş Sonrası Adres',
                sub: 'Müşteri adresi teslimat sonrasında görünür olur',
                value: s.orderAddressVisibleAfterOrder,
                onChanged: (v) async {
                  await _update(
                      's_settings.orderAddressVisibleAfterOrder', v);
                  await _update('s_settings.updatedAt', Timestamp.now());
                },
              ),
            ]),
            const SizedBox(height: 20),

            // ── İşletme Ayarları ────────────────────────────
            _sectionLabel(
                'İşletme Ayarları', Icons.store_rounded, AppColors.warning),
            const SizedBox(height: 8),
            _card([
              _toggleTile(
                icon: Icons.restaurant_rounded,
                iconColor: AppColors.warning,
                label: 'Restoran Fiyatlandırması',
                sub: 'Restorana özel teslimat fiyatlandırması aktif olur',
                value: s.restaurantPricingEnabled,
                onChanged: (v) async {
                  await _update('s_settings.restaurantPricingEnabled', v);
                  await _update('s_settings.updatedAt', Timestamp.now());
                },
              ),
            ]),
          ],
        ),
        if (_saving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(30),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withAlpha(35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uygulama Davranışı',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  SizedBox(height: 3),
                  Text(
                    'Değişiklikler anında kaydedilir ve tüm kuryelerinize yansır.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String title, IconData icon, Color color) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins')),
        ],
      );

  Widget _card(List<Widget> children) => Container(
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
        child: Column(children: children),
      );

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (value ? iconColor : AppColors.textHint).withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: value ? iconColor : AppColors.textHint),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      subtitle: Text(sub,
          style:
              const TextStyle(fontSize: 11, color: AppColors.textHint)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: iconColor,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
