import 'package:flutter/material.dart';

/// ZirveGo Kurumsal Renk Paleti
/// Derin Lacivert + Kırık Beyaz + Altın Vurgu
abstract class AppColors {
  // ── Marka Renkleri ──────────────────────────────────────
  static const Color primary = Color(0xFF1E3A5F);       // Derin Lacivert
  static const Color primaryLight = Color(0xFF2C5282);  // Orta Lacivert
  static const Color primaryDark = Color(0xFF0F1F35);   // Koyu Lacivert

  static const Color secondary = Color(0xFF2B6CB0);     // Kurumsal Mavi
  static const Color secondaryLight = Color(0xFF4299E1); // Açık Mavi
  static const Color secondaryDark = Color(0xFF1A4A80);  // Koyu Mavi

  static const Color accent = Color(0xFFB7860B);        // Altın Vurgu
  static const Color accentLight = Color(0xFFD4A017);   // Açık Altın

  // ── Arkaplan ─────────────────────────────────────────────
  static const Color background = Color(0xFFF7F8FC);    // Açık Gri-Mavi
  static const Color backgroundDark = Color(0xFF121B2E); // Koyu Arkaplan
  static const Color surface = Color(0xFFFFFFFF);       // Yüzey (Kart)
  static const Color surfaceDark = Color(0xFF1E2A3D);   // Koyu Yüzey

  // ── Metin ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A202C);   // Ana Metin
  static const Color textSecondary = Color(0xFF4A5568); // İkincil Metin
  static const Color textHint = Color(0xFF718096);      // İpucu Metni
  static const Color textDisabled = Color(0xFFA0AEC0);  // Devre Dışı
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Koyu üzeri Metin
  static const Color textOnDark = Color(0xFFE2E8F0);    // Açık Metin (Koyu BG)

  // ── Durum Renkleri ───────────────────────────────────────
  static const Color success = Color(0xFF276749);       // Koyu Yeşil
  static const Color successLight = Color(0xFFEBF8F0);  // Açık Yeşil BG
  static const Color warning = Color(0xFFB7600B);       // Turuncu
  static const Color warningLight = Color(0xFFFFF3E0);  // Açık Turuncu BG
  static const Color error = Color(0xFFC53030);         // Kırmızı
  static const Color errorLight = Color(0xFFFFF5F5);    // Açık Kırmızı BG
  static const Color info = Color(0xFF2B6CB0);          // Bilgi Mavisi
  static const Color infoLight = Color(0xFFEBF8FF);     // Açık Mavi BG

  // ── Kenarlık & Ayraç ─────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);        // Kenarlık
  static const Color borderFocus = Color(0xFF2B6CB0);   // Odaklanma Kenarlığı
  static const Color divider = Color(0xFFEDF2F7);       // Ayraç

  // ── Gölge ────────────────────────────────────────────────
  static const Color shadow = Color(0x1A1E3A5F);        // Hafif Lacivert Gölge
  static const Color shadowMedium = Color(0x331E3A5F);  // Orta Gölge

  // ── Gradient ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB7860B), Color(0xFFD4A017)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A5F), Color(0xFF1A4A80)],
  );

  // ── Kart Arka Planları ───────────────────────────────────
  static const Color cardBlue = Color(0xFFEBF8FF);
  static const Color cardGreen = Color(0xFFEBF8F0);
  static const Color cardOrange = Color(0xFFFFF3E0);
  static const Color cardRed = Color(0xFFFFF5F5);
  static const Color cardPurple = Color(0xFFF8F0FF);
}
