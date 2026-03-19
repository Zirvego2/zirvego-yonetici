import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/bay_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GÜVENLİK SAYFASI
// ─────────────────────────────────────────────────────────────────────────────

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
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
    await _firestore
        .collection(AppConstants.tBayCollection)
        .doc(_user!.docId)
        .update({field: value});
  }

  // ── Şifre Değiştir Dialogu ─────────────────────────────────────────────────

  Future<void> _changePasswordDialog() async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool ob1 = true, ob2 = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Şifre Değiştir',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pwField(
                ctrl: newCtrl,
                label: 'Yeni Şifre',
                obscure: ob1,
                toggle: () => setS(() => ob1 = !ob1),
              ),
              const SizedBox(height: 12),
              _pwField(
                ctrl: confirmCtrl,
                label: 'Şifre Tekrar',
                obscure: ob2,
                toggle: () => setS(() => ob2 = !ob2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final pw = newCtrl.text.trim();
                if (pw.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Şifre en az 4 karakter olmalı')),
                  );
                  return;
                }
                if (pw != confirmCtrl.text.trim()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Şifreler eşleşmiyor')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _saving = true);
                try {
                  await _update('s_password', pw);
                  await _update('s_info.ss_password', pw);
                  await _update('s_password_updated', Timestamp.now());
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Şifre güncellendi'),
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
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField({
    required TextEditingController ctrl,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              size: 18),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5)),
      ),
    );
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
          'Güvenlik',
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
    final pwDate = u.sPasswordUpdated != null
        ? DateFormat('dd.MM.yyyy  HH:mm').format(u.sPasswordUpdated!)
        : 'Henüz değiştirilmedi';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Açıklama kartı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(10),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.error.withAlpha(35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded,
                        size: 18, color: AppColors.error),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hesap Güvenliği',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error)),
                        SizedBox(height: 3),
                        Text(
                          'Güçlü bir şifre kullanın. Şifrenizi kimseyle paylaşmayın.',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Şifre bilgileri kartı
            Container(
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
                children: [
                  // Son şifre değişimi
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded,
                          size: 18, color: AppColors.textHint),
                    ),
                    title: const Text('Son Şifre Değişimi',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textHint)),
                    subtitle: Text(pwDate,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                  ),

                  const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 62,
                      color: AppColors.divider),

                  // Şifre değiştir
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    title: const Text('Şifre Değiştir',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    subtitle: const Text('Giriş şifrenizi güncelleyin',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint)),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                    onTap: _changePasswordDialog,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Kullanıcı adı bilgisi
            Container(
              padding: const EdgeInsets.all(14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 15, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      const Text('Giriş Bilgileri',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Kullanıcı Adı', u.username),
                  const SizedBox(height: 6),
                  _infoRow('İşletme ID', '${u.sId}'),
                  const SizedBox(height: 6),
                  _infoRow('Admin Seviyesi',
                      u.sAdmin == 1 ? 'Yönetici' : 'Operatör'),
                ],
              ),
            ),
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

  Widget _infoRow(String label, String value) => Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textHint)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      );
}
