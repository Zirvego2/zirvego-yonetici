import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/update_check_service.dart';
import '../../core/theme/app_colors.dart';

/// Güncelleme dialogunu gösterir.
///
/// [result.isForced] → true ise kapatılamaz, sadece "Güncelle" butonu görünür.
/// [result.isOptional] → "Sonra Hatırlat" butonu da görünür.
class UpdateDialog extends StatefulWidget {
  final UpdateResult result;

  const UpdateDialog({super.key, required this.result});

  /// Dialog'u göster. Zorunlu güncellemede WillPopScope ile kapatma engellenir.
  static Future<void> show(BuildContext context, UpdateResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !result.isForced,
      builder: (_) => UpdateDialog(result: result),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress  = 0;
  String? _errorMsg;

  UpdateResult get _result => widget.result;

  // ─────────────────────────────────────────────────────────────────────────
  // Güncelleme Aksiyonu
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onUpdate() async {
    if (Platform.isIOS) {
      // iOS → TestFlight / App Store linkini aç
      final url = _result.iosUrl;
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return;
    }

    // Android → APK indir & kur
    final apkUrl = _result.apkUrl;
    if (apkUrl.isEmpty) {
      setState(() => _errorMsg = 'İndirme linki bulunamadı.');
      return;
    }

    setState(() {
      _downloading = true;
      _progress    = 0;
      _errorMsg    = null;
    });

    try {
      final dir      = await getTemporaryDirectory();
      final savePath = '${dir.path}/zirvego_update.apk';

      await Dio().download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (!mounted) return;
      await OpenFile.open(savePath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _errorMsg    = 'İndirme başarısız. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Zorunlu güncellemede geri tuşunu engelle
      canPop: !_result.isForced,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── İkon ────────────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              // ── Başlık ──────────────────────────────────────────
              Text(
                _result.isForced
                    ? 'Zorunlu Güncelleme'
                    : 'Yeni Sürüm Mevcut',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),

              // ── Versiyon ─────────────────────────────────────────
              Text(
                'Sürüm ${_result.latestVersion}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
              ),

              // ── Açıklama ─────────────────────────────────────────
              if (_result.isForced) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.error),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bu sürüm artık desteklenmiyor. Devam edebilmek için güncelleme yapmanız gerekmektedir.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Sürüm Notları ─────────────────────────────────────
              if (_result.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _result.releaseNotes,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── İndirme Progress ──────────────────────────────────
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İndiriliyor... %${(_progress * 100).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Hata Mesajı ───────────────────────────────────────
              if (_errorMsg != null) ...[
                Text(
                  _errorMsg!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // ── Butonlar ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloading ? null : _onUpdate,
                  icon: _downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_downloading ? 'İndiriliyor...' : 'Güncelle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

              // "Sonra Hatırlat" — sadece isteğe bağlı güncellemede
              if (_result.isOptional && !_downloading) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Sonra Hatırlat',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
