import 'package:flutter/material.dart';
import '../../core/services/order_color_service.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SİPARİŞ RENK EŞİKLERİ SAYFASI
// ─────────────────────────────────────────────────────────────────────────────

class OrderColorSettingsScreen extends StatefulWidget {
  const OrderColorSettingsScreen({super.key});

  @override
  State<OrderColorSettingsScreen> createState() =>
      _OrderColorSettingsScreenState();
}

class _OrderColorSettingsScreenState extends State<OrderColorSettingsScreen> {
  late List<ColorThreshold> _unassigned;
  late List<ColorThreshold> _assigned;
  late Color _onRoadColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromService();
  }

  void _loadFromService() {
    final svc = OrderColorService.instance;
    _unassigned = List.from(svc.unassigned);
    _assigned = List.from(svc.assigned);
    _onRoadColor = svc.onRoadColor;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await OrderColorService.instance.save(
      unassigned: _unassigned,
      assigned: _assigned,
      onRoadColor: _onRoadColor,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Renk eşikleri kaydedildi'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Varsayılana Sıfırla'),
        content: const Text(
            'Tüm renk eşikleri varsayılan değerlere döndürülecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await OrderColorService.instance.resetToDefaults();
    setState(_loadFromService);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Varsayılanlara döndürüldü'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editThreshold({
    required bool isUnassigned,
    required int index,
  }) async {
    final list = isUnassigned ? _unassigned : _assigned;
    final current = list[index];

    final result = await showModalBottomSheet<ColorThreshold>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThresholdEditSheet(threshold: current, index: index),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (isUnassigned) {
        _unassigned = List.from(_unassigned)..[index] = result;
      } else {
        _assigned = List.from(_assigned)..[index] = result;
      }
    });
  }

  Future<void> _pickOnRoadColor() async {
    final result = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OnRoadColorSheet(current: _onRoadColor),
    );
    if (result == null || !mounted) return;
    setState(() => _onRoadColor = result);
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  String _colorName(Color color) {
    for (final p in OrderColorService.palette) {
      if (p.color.value == color.value) return p.name;
    }
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String _nextMinutes(ColorThreshold t, List<ColorThreshold> list) {
    for (final th in list) {
      if (th.minutes > t.minutes) return '${th.minutes - 1}';
    }
    return '∞';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          'Sipariş Renk Eşikleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          // Sağ üst: kaydet butonu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.save_rounded,
                      size: 16, color: AppColors.primary),
              label: Text(
                _saving ? 'Kaydediliyor…' : 'Kaydet',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Açıklama Kartı ──────────────────────────────────────────────
          _buildInfoCard(),
          const SizedBox(height: 20),

          // ── Önizleme ────────────────────────────────────────────────────
          _buildPreview(),
          const SizedBox(height: 24),

          // ── Atanmayan ───────────────────────────────────────────────────
          _buildSectionHeader(
            title: 'Atanmayan Siparişler',
            subtitle: 'Kart arka planı ve kenarlık rengi',
            icon: Icons.hourglass_empty_rounded,
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 8),
          _buildThresholdsCard(
            thresholds: _unassigned,
            isUnassigned: true,
          ),
          const SizedBox(height: 20),

          // ── Atanan ──────────────────────────────────────────────────────
          _buildSectionHeader(
            title: 'Atanan Siparişler',
            subtitle: 'Sadece "Xdk" süre rozetinin rengi',
            icon: Icons.assignment_turned_in_rounded,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildThresholdsCard(
            thresholds: _assigned,
            isUnassigned: false,
            onRoadRow: true,
          ),
          const SizedBox(height: 28),

          // ── Varsayılana Dön ─────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: _saving ? null : _resetDefaults,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Tüm Ayarları Varsayılana Döndür'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Açıklama Kartı ─────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withAlpha(60),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Bu sayfa ne işe yarar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Madde 1
          _infoItem(
            icon: Icons.hourglass_empty_rounded,
            title: 'Atanmayan Siparişler',
            desc:
                'Kuryeye henüz atanmamış siparişlerin kart arka planı ve kenarlık rengi bekleme süresine göre değişir. 20 dk+ siparişler ayrıca yanıp söner.',
          ),
          const SizedBox(height: 10),

          // Madde 2
          _infoItem(
            icon: Icons.timer_outlined,
            title: 'Atanan Siparişler — "Xdk" Rozeti',
            desc:
                'Atanmış siparişlerde kart rengi değişmez; yalnızca üst bardaki geçen süre ("11dk", "22dk") rozetinin rengi eşiğe göre renklendirilir.',
          ),
          const SizedBox(height: 10),

          // Madde 3
          _infoItem(
            icon: Icons.delivery_dining_rounded,
            title: 'Yolda Siparişler',
            desc:
                '"Yolda" statüsüne geçen atanmış siparişlerin kart arka planı seçilen renkle hafifçe boyanır.',
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mini Önizleme ──────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Önizleme',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Row(
          children: [
            // Atanmayan
            Expanded(
              child: _previewCard(
                label: 'Atanmayan',
                topColors: _unassigned.map((t) => t.color).toList(),
                bgColor: _unassigned.first.color,
                showBg: true,
              ),
            ),
            const SizedBox(width: 10),
            // Atanan
            Expanded(
              child: _previewCard(
                label: 'Atanan',
                topColors: _assigned.map((t) => t.color).toList(),
                bgColor: _onRoadColor,
                showBg: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewCard({
    required String label,
    required List<Color> topColors,
    required Color bgColor,
    required bool showBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: showBg ? bgColor.withAlpha(18) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showBg ? bgColor.withAlpha(80) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 8),

          // Eşik renk çubukları
          Row(
            children: topColors.asMap().entries.map((e) {
              final isLast = e.key == topColors.length - 1;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: isLast ? 0 : 3),
                  decoration: BoxDecoration(
                    color: e.value,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // "Xdk" rozet örneği
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '13:45',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (showBg ? bgColor : topColors.last).withAlpha(22),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  showBg ? '8dk' : '22dk',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: showBg ? topColors.first : topColors.last,
                  ),
                ),
              ),
              if (!showBg) ...[
                const Spacer(),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded,
                      size: 9, color: Colors.white),
                ),
                const SizedBox(width: 3),
                Text('Yolda',
                    style: TextStyle(
                        fontSize: 9, color: bgColor, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Bölüm Başlığı ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.textHint),
            ),
          ],
        ),
      ],
    );
  }

  // ── Eşik Listesi Kartı ─────────────────────────────────────────────────────

  Widget _buildThresholdsCard({
    required List<ColorThreshold> thresholds,
    required bool isUnassigned,
    bool onRoadRow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          ...thresholds.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            final isLastItem = e.key == thresholds.length - 1;
            final t = e.value;
            final rangeLabel = isFirst
                ? '0 – ${_nextMinutes(t, thresholds)} dk arası'
                : '≥ ${t.minutes} dk';

            return Column(
              children: [
                _thresholdTile(
                  color: t.color,
                  label: rangeLabel,
                  colorName: _colorName(t.color),
                  onTap: () => _editThreshold(
                      isUnassigned: isUnassigned, index: e.key),
                ),
                if (!isLastItem || onRoadRow)
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.divider,
                      indent: 56),
              ],
            );
          }),

          // Yolda rengi satırı (sadece atanan kart için)
          if (onRoadRow) _onRoadTile(),
        ],
      ),
    );
  }

  Widget _thresholdTile({
    required Color color,
    required String label,
    required String colorName,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Renkli daire
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(90),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Açıklama
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    colorName,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Düzenle
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded,
                      size: 13, color: AppColors.textHint),
                  SizedBox(width: 3),
                  Text('Düzenle',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onRoadTile() {
    return InkWell(
      onTap: _pickOnRoadColor,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Renkli daire + ikon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _onRoadColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _onRoadColor.withAlpha(90),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.delivery_dining_rounded,
                  size: 15, color: Colors.white),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yolda siparişlerin kart rengi',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _colorName(_onRoadColor),
                    style: TextStyle(
                      fontSize: 11,
                      color: _onRoadColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded,
                      size: 13, color: AppColors.textHint),
                  SizedBox(width: 3),
                  Text('Düzenle',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YOLDA RENGİ SEÇME BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _OnRoadColorSheet extends StatefulWidget {
  final Color current;
  const _OnRoadColorSheet({required this.current});

  @override
  State<_OnRoadColorSheet> createState() => _OnRoadColorSheetState();
}

class _OnRoadColorSheetState extends State<_OnRoadColorSheet> {
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 10,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _selected,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _selected.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yolda Sipariş Rengi',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Atanan sekmesinde "Yolda" olan siparişler',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: OrderColorService.palette.map((p) {
              final isSel = p.color.value == _selected.value;
              return GestureDetector(
                onTap: () => setState(() => _selected = p.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withAlpha(isSel ? 130 : 55),
                        blurRadius: isSel ? 12 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            _paletteName(_selected),
            style: TextStyle(
                fontSize: 12,
                color: _selected,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paletteName(Color color) {
    for (final p in OrderColorService.palette) {
      if (p.color.value == color.value) return p.name;
    }
    return 'Özel Renk';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EŞİK DÜZENLEME BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ThresholdEditSheet extends StatefulWidget {
  final ColorThreshold threshold;
  final int index;

  const _ThresholdEditSheet({
    required this.threshold,
    required this.index,
  });

  @override
  State<_ThresholdEditSheet> createState() => _ThresholdEditSheetState();
}

class _ThresholdEditSheetState extends State<_ThresholdEditSheet> {
  late int _minutes;
  late Color _color;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _minutes = widget.threshold.minutes;
    _color = widget.threshold.color;
    _ctrl = TextEditingController(
        text: _minutes == 0 ? '' : _minutes.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.index == 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 10,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Başlık
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _color.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFirst ? 'İlk Eşik (0 dk)' : 'Eşik ${widget.index + 1}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      isFirst
                          ? 'Dakika değiştirilemez (her zaman 0)'
                          : 'Dakika ve renk seçin',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dakika girişi (ilk eşik için devre dışı)
          if (!isFirst) ...[
            const Text('Eşik Başlangıç Dakikası',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              onChanged: (v) => _minutes = int.tryParse(v) ?? _minutes,
              decoration: InputDecoration(
                hintText: 'ör: 10',
                suffixText: 'dk',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Renk seçimi
          const Text('Renk',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: OrderColorService.palette.map((p) {
              final isSel = p.color.value == _color.value;
              return GestureDetector(
                onTap: () => setState(() => _color = p.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withAlpha(isSel ? 130 : 40),
                        blurRadius: isSel ? 10 : 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final mins = isFirst ? 0 : (int.tryParse(_ctrl.text) ?? _minutes);
                    Navigator.pop(
                      context,
                      ColorThreshold(minutes: mins, color: _color),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
