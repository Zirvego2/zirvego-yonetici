import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/operation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/ai_settings_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OtoAtamaTab — Oto Atama Ayarları Sekmesi
// ─────────────────────────────────────────────────────────────────────────────

class OtoAtamaTab extends StatefulWidget {
  const OtoAtamaTab({super.key});

  @override
  State<OtoAtamaTab> createState() => _OtoAtamaTabState();
}

class _OtoAtamaTabState extends State<OtoAtamaTab> {
  final _service = OperationService.instance;
  int get _bayId => AuthService.instance.currentUser?.sId ?? 0;

  AiSettingsModel? _settings;
  bool _loading  = true;
  bool _saving   = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasChanges = false; });
    final s = await _service.fetchAiSettings(_bayId);
    if (mounted) setState(() { _settings = s; _loading = false; });
  }

  void _update(AiSettingsModel updated) {
    setState(() { _settings = updated; _hasChanges = true; });
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    final ok = await _service.saveAiSettings(_settings!);
    if (mounted) {
      setState(() { _saving = false; if (ok) _hasChanges = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Ayarlar kaydedildi ✓' : 'Kayıt başarısız, tekrar deneyin'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 14),
          Text('Ayarlar yükleniyor…', style: TextStyle(color: AppColors.textHint)),
        ]),
      );
    }

    final s = _settings!;

    return Stack(children: [
      // ── Scrollable içerik ──────────────────────────────────────────────
      ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 110),
        children: [
          // Başlık kartı
          _headerCard(),

          // 1 — AI Otomatik Atama
          _section(
            icon: Icons.auto_fix_high_rounded,
            color: const Color(0xFF6366F1),
            title: 'AI Otomatik Atama',
            subtitle: 'Siparişlerin yapay zeka tarafından otomatik atanması',
            children: [
              _toggle(
                label: 'AI Ataması Aktif',
                description: 'Yeni siparişleri AI otomatik olarak kuryeye atar',
                value: s.aiEnabled,
                onChanged: (v) => _update(s.copyWith(aiEnabled: v)),
                activeColor: const Color(0xFF6366F1),
              ),
              _divider(),
              _stepper(
                label: 'Maks. Paket Sayısı',
                description: 'Bir kuryeye atanabilecek maksimum paket adedi',
                unit: 'paket',
                value: s.aiMaxPackages,
                min: 1, max: 20, step: 1,
                enabled: s.aiEnabled,
                onChanged: (v) => _update(s.copyWith(aiMaxPackages: v)),
              ),
              _divider(),
              _stepper(
                label: 'Bekleme Süresi',
                description: 'Atama kararı vermeden önce beklenen süre',
                unit: 'dakika',
                value: s.aiWaitTime,
                min: 0, max: 30, step: 1,
                enabled: s.aiEnabled,
                onChanged: (v) => _update(s.copyWith(aiWaitTime: v)),
              ),
            ],
          ),

          // 2 — Kurye Onayı
          _section(
            icon: Icons.verified_rounded,
            color: const Color(0xFF0891B2),
            title: 'Kurye Onayı',
            subtitle: 'Atama sonrası kurye onay gerekliliği',
            children: [
              _toggle(
                label: 'Kurye Onayı Zorunlu',
                description: 'Kurye, atanan siparişi onaylamak zorunda olsun',
                value: s.courierApprovalEnabled,
                onChanged: (v) => _update(s.copyWith(courierApprovalEnabled: v)),
                activeColor: const Color(0xFF0891B2),
              ),
              _divider(),
              _stepper(
                label: 'Onay Zaman Aşımı',
                description: 'Bu süre geçince sipariş otomatik iptale alınır',
                unit: 'saniye',
                value: s.approvalTimeout,
                min: 10, max: 600, step: 10,
                enabled: s.courierApprovalEnabled,
                onChanged: (v) => _update(s.copyWith(approvalTimeout: v)),
              ),
            ],
          ),

          // 3 — Otomatik Hazır
          _section(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            title: 'Otomatik Hazır Durumu',
            subtitle: 'Teslimat sonrası kurye durumu',
            children: [
              _toggle(
                label: 'Otomatik Hazır',
                description:
                    'Kurye teslimattan sonra otomatik olarak Müsait durumuna geçsin',
                value: s.autoReadyEnabled,
                onChanged: (v) => _update(s.copyWith(autoReadyEnabled: v)),
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),

          // 4 — Grup Atama
          _section(
            icon: Icons.groups_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Grup Atama',
            subtitle: 'Aynı yöndeki siparişleri grupla',
            children: [
              _toggle(
                label: 'Grup Atama Aktif',
                description: 'Benzer güzergâhtaki siparişler aynı kuryeye atansın',
                value: s.groupAssignmentEnabled,
                onChanged: (v) => _update(s.copyWith(groupAssignmentEnabled: v)),
                activeColor: const Color(0xFFF59E0B),
              ),
              _divider(),
              _stepper(
                label: 'Yön Eşiği',
                description: 'Siparişlerin "aynı yön" sayılması için max sapma açısı',
                unit: 'derece',
                value: s.groupDirectionThreshold,
                min: 5, max: 180, step: 5,
                enabled: s.groupAssignmentEnabled,
                onChanged: (v) => _update(s.copyWith(groupDirectionThreshold: v)),
              ),
            ],
          ),

          // 5 — Sipariş Önceliği
          _section(
            icon: Icons.priority_high_rounded,
            color: const Color(0xFFEF4444),
            title: 'Sipariş Önceliği',
            subtitle: 'Yeni gelen siparişlere öncelik tanıma',
            children: [
              _stepper(
                label: 'Yeni Sipariş Öncelik Süresi',
                description:
                    'Son X dakika içinde gelen siparişler önce atansın',
                unit: 'dakika',
                value: s.latestOrderPriorityMinutes,
                min: 1, max: 60, step: 1,
                onChanged: (v) =>
                    _update(s.copyWith(latestOrderPriorityMinutes: v)),
              ),
            ],
          ),

          // 6 — Mesafe Ayarları
          _section(
            icon: Icons.social_distance_rounded,
            color: const Color(0xFF9333EA),
            title: 'Mesafe Ayarları',
            subtitle: 'İşletme ve paket konum eşikleri',
            children: [
              _numberInput(
                label: 'İşletme–Paket Mesafesi',
                description:
                    'Kuryenin işletmeye bu mesafe içinde olması gerekir (metre)',
                unit: 'm',
                value: s.businessToPackageDistance,
                min: 100, max: 20000, step: 100,
                onChanged: (v) =>
                    _update(s.copyWith(businessToPackageDistance: v)),
              ),
            ],
          ),
        ],
      ),

      // ── Kaydet butonu (sabit alt) ───────────────────────────────────────
      Positioned(
        left: 0, right: 0, bottom: 0,
        child: _buildSaveBar(),
      ),
    ]);
  }

  // ── Başlık kartı ──────────────────────────────────────────────────────────

  Widget _headerCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x336366F1), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_fix_high_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Oto Atama Ayarları',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Bay ID: $_bayId',
                style: TextStyle(
                    color: Colors.white.withAlpha(180), fontSize: 12)),
          ]),
        ),
        // Yenile
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Yenile',
        ),
      ]),
    );
  }

  // ── Kaydet bar ────────────────────────────────────────────────────────────

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            key: ValueKey(_hasChanges),
            onPressed: (_hasChanges && !_saving) ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _hasChanges ? AppColors.primary : AppColors.border,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textHint,
              elevation: _hasChanges ? 4 : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _hasChanges
                        ? Icons.save_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 20),
            label: Text(
              _saving
                  ? 'Kaydediliyor…'
                  : (_hasChanges ? 'Değişiklikleri Kaydet' : 'Kaydedildi'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bileşen oluşturucular
  // ─────────────────────────────────────────────────────────────────────────

  /// Bölüm kartı
  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Bölüm başlığı
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ]),
            ),
          ]),
        ),
        Container(height: 1, color: AppColors.divider),

        // Ayarlar
        ...children,
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _divider() =>
      Container(height: 1, color: AppColors.divider,
          margin: const EdgeInsets.symmetric(horizontal: 16));

  /// Toggle (switch) satırı
  Widget _toggle({
    required String label,
    required String description,
    required bool value,
    required void Function(bool) onChanged,
    Color activeColor = AppColors.primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint)),
          ]),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  /// +/− stepper satırı
  Widget _stepper({
    required String label,
    required String description,
    required String unit,
    required int value,
    required int min,
    required int max,
    required int step,
    required void Function(int) onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(description,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            ]),
          ),
          const SizedBox(width: 10),
          _StepperWidget(
            value: value,
            min: min,
            max: max,
            step: step,
            unit: unit,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }

  /// Büyük sayı için metin girişli satır (tap to edit dialog)
  Widget _numberInput({
    required String label,
    required String description,
    required String unit,
    required int value,
    required int min,
    required int max,
    required int step,
    required void Function(int) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint)),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showNumberDialog(
            label: label,
            unit: unit,
            current: value,
            min: min,
            max: max,
            step: step,
            onSave: onChanged,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                value.toString(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded,
                  size: 13, color: AppColors.textHint),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _showNumberDialog({
    required String label,
    required String unit,
    required int current,
    required int min,
    required int max,
    required int step,
    required void Function(int) onSave,
  }) async {
    final ctrl = TextEditingController(text: current.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Geçerli aralık: $min – $max $unit',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              suffixText: unit,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 14),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ]),
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
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? current;
              onSave(v.clamp(min, max));
              Navigator.pop(ctx);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// +/− Stepper Widget
// ─────────────────────────────────────────────────────────────────────────────

class _StepperWidget extends StatelessWidget {
  final int      value;
  final int      min;
  final int      max;
  final int      step;
  final String   unit;
  final bool     enabled;
  final void Function(int) onChanged;

  const _StepperWidget({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDec = enabled && value > min;
    final canInc = enabled && value < max;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // − butonu
      _btn(
        icon: Icons.remove_rounded,
        enabled: canDec,
        onTap: () => onChanged((value - step).clamp(min, max)),
      ),

      // Değer kutusu
      Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textHint,
            ),
          ),
          Text(
            unit,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textHint),
          ),
        ]),
      ),

      // + butonu
      _btn(
        icon: Icons.add_rounded,
        enabled: canInc,
        onTap: () => onChanged((value + step).clamp(min, max)),
      ),
    ]);
  }

  Widget _btn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withAlpha(18)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppColors.primary.withAlpha(80) : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}
