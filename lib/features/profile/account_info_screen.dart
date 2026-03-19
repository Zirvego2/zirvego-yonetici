import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/bay_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HESAP BİLGİLERİ MODAL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

/// Profilden açılan hesap bilgileri modalı
class AccountInfoSheet extends StatefulWidget {
  const AccountInfoSheet({super.key});

  /// Modal'ı açmak için kullanılan yardımcı metot
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountInfoSheet(),
    );
  }

  @override
  State<AccountInfoSheet> createState() => _AccountInfoSheetState();
}

class _AccountInfoSheetState extends State<AccountInfoSheet> {
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
            content: Text('✅ Kaydedildi'),
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

  Future<void> _editDialog({
    required String title,
    required String currentValue,
    required String firestoreField,
    TextInputType? keyboard,
    int? maxLen,
    bool digits = false,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboard,
          inputFormatters:
              digits ? [FilteringTextInputFormatter.digitsOnly] : null,
          maxLength: maxLen,
          decoration: InputDecoration(
            labelText: title,
            filled: true,
            fillColor: AppColors.background,
            counterText: '',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result == null || result == currentValue) return;
    await _update(firestoreField, result);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      // Ekranın %92'sini kapla
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Tutma çubuğu ──────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Başlık barı ───────────────────────────────────
          _buildTitleBar(),

          // ── İçerik ───────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _user == null
                    ? _buildError()
                    : _buildBody(_user!),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Gradient ikon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF4299E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_center_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hesap Bilgileri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  'İşletme ve kişisel bilgilerinizi düzenleyin',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          // Kapat butonu
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.textHint.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Veriler yüklenemedi'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      );

  Widget _buildBody(BayModel u) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Bilgi banner ────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withAlpha(35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✏️ işaretli satırlara dokunarak düzenleyebilirsiniz.',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Alan kartı ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: Offset(0, 3))
                ],
              ),
              child: Column(
                children: [
                  _fieldTile(
                    icon: Icons.storefront_rounded,
                    label: 'İşletme Adı',
                    value: u.displayName,
                    editable: true,
                    onEdit: () => _editDialog(
                      title: 'İşletme Adı',
                      currentValue: u.sBayName,
                      firestoreField: 's_bay_name',
                    ),
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Kullanıcı Adı',
                    value: u.username,
                    editable: false,
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.badge_outlined,
                    label: 'Ad Soyad',
                    value: u.fullName.isNotEmpty ? u.fullName : '—',
                    editable: false,
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.phone_outlined,
                    label: 'Telefon',
                    value: u.sPhone.isNotEmpty ? u.sPhone : '—',
                    editable: true,
                    onEdit: () => _editDialog(
                      title: 'Telefon',
                      currentValue: u.sPhone,
                      firestoreField: 's_phone',
                      keyboard: TextInputType.phone,
                      maxLen: 15,
                    ),
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.location_city_rounded,
                    label: 'Şehir / İlçe',
                    value: '${u.district}, ${u.city}',
                    editable: false,
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.home_outlined,
                    label: 'Adres',
                    value: u.sAdres.isNotEmpty ? u.sAdres : '—',
                    editable: true,
                    onEdit: () => _editDialog(
                      title: 'Adres',
                      currentValue: u.sAdres,
                      firestoreField: 's_adres',
                    ),
                  ),
                  _div(),
                  _fieldTile(
                    icon: Icons.tag_rounded,
                    label: 'İşletme ID',
                    value: '${u.sId}',
                    editable: false,
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Kaydetme overlay ──────────────────────────────
        if (_saving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(30),
              child: const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  Widget _div() => const Divider(
      height: 1, thickness: 1, indent: 62, color: AppColors.divider);

  Widget _fieldTile({
    required IconData icon,
    required String label,
    required String value,
    required bool editable,
    VoidCallback? onEdit,
  }) {
    return InkWell(
      onTap: editable ? onEdit : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // İkon kutusu
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (editable ? AppColors.primary : AppColors.textHint)
                    .withAlpha(13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 18,
                  color:
                      editable ? AppColors.primary : AppColors.textHint),
            ),
            const SizedBox(width: 14),

            // Label + değer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),

            // Sağ göstergesi
            if (editable)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 11, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text('Düzenle',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.divider, width: 0.8),
                ),
                child: const Text('Sabit',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textHint)),
              ),
          ],
        ),
      ),
    );
  }
}
