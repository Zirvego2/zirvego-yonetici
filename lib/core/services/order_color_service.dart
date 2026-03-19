import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RENK EŞİĞİ MODELİ
// ─────────────────────────────────────────────────────────────────────────────

/// Tek bir renk eşiği: "X dakikadan itibaren bu renk kullanılır"
class ColorThreshold {
  final int minutes;
  final Color color;

  const ColorThreshold({required this.minutes, required this.color});

  ColorThreshold copyWith({int? minutes, Color? color}) => ColorThreshold(
        minutes: minutes ?? this.minutes,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() => {'m': minutes, 'c': color.value};

  factory ColorThreshold.fromJson(Map<String, dynamic> j) => ColorThreshold(
        minutes: (j['m'] as num).toInt(),
        color: Color((j['c'] as num).toInt()),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVİS
// ─────────────────────────────────────────────────────────────────────────────

class OrderColorService {
  OrderColorService._();
  static final instance = OrderColorService._();

  static const _key = 'order_color_thresholds_v1';
  static const _storage = FlutterSecureStorage();

  // ── Önayarlı renkler ────────────────────────────────────────────────────

  /// Kullanıcıya sunulan renk paleti
  static const List<({Color color, String name})> palette = [
    (color: Color(0xFF48BB78), name: 'Yeşil'),
    (color: Color(0xFF68D391), name: 'Açık Yeşil'),
    (color: Color(0xFFECC94B), name: 'Sarı'),
    (color: Color(0xFFF6AD55), name: 'Turuncu'),
    (color: Color(0xFFFC8181), name: 'Pembe'),
    (color: Color(0xFFC53030), name: 'Kırmızı'),
    (color: Color(0xFF4299E1), name: 'Mavi'),
    (color: Color(0xFF9F7AEA), name: 'Mor'),
  ];

  // ── Varsayılan eşikler ───────────────────────────────────────────────────

  static const List<ColorThreshold> _defaultUnassigned = [
    ColorThreshold(minutes: 0, color: Color(0xFF48BB78)),   // Yeşil
    ColorThreshold(minutes: 10, color: Color(0xFFECC94B)),  // Sarı
    ColorThreshold(minutes: 20, color: Color(0xFFC53030)),  // Kırmızı
  ];

  static const List<ColorThreshold> _defaultAssigned = [
    ColorThreshold(minutes: 0, color: Color(0xFF48BB78)),
    ColorThreshold(minutes: 10, color: Color(0xFFECC94B)),
    ColorThreshold(minutes: 20, color: Color(0xFFC53030)),
  ];

  /// Atanan sekmesinde "Yolda" (s_stat=1) siparişleri için varsayılan renk
  static const Color _defaultOnRoadColor = Color(0xFF4299E1); // Mavi

  // ── Çalışma zamanı değerleri ─────────────────────────────────────────────

  List<ColorThreshold> _unassigned = List.from(_defaultUnassigned);
  List<ColorThreshold> _assigned = List.from(_defaultAssigned);

  /// Atanan sekmesindeki "Yolda" siparişlere uygulanacak renk
  Color _onRoadColor = _defaultOnRoadColor;

  List<ColorThreshold> get unassigned => List.unmodifiable(_unassigned);
  List<ColorThreshold> get assigned => List.unmodifiable(_assigned);
  Color get onRoadColor => _onRoadColor;

  // ── Yükleme & Kaydetme ───────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final u = map['u'] as List?;
      final a = map['a'] as List?;

      if (u != null && u.isNotEmpty) {
        _unassigned = u
            .map((e) => ColorThreshold.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
      }
      if (a != null && a.isNotEmpty) {
        _assigned = a
            .map((e) => ColorThreshold.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
      }
      // Yolda rengi
      if (map['r'] != null) {
        _onRoadColor = Color((map['r'] as num).toInt());
      }
    } catch (_) {
      // Hata olursa varsayılanları kullan
    }
  }

  Future<void> save({
    required List<ColorThreshold> unassigned,
    required List<ColorThreshold> assigned,
    Color? onRoadColor,
  }) async {
    _unassigned = List.from(unassigned)
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    _assigned = List.from(assigned)
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    if (onRoadColor != null) _onRoadColor = onRoadColor;

    await _storage.write(
      key: _key,
      value: jsonEncode({
        'u': _unassigned.map((e) => e.toJson()).toList(),
        'a': _assigned.map((e) => e.toJson()).toList(),
        'r': _onRoadColor.value,
      }),
    );
  }

  Future<void> resetToDefaults() async {
    await save(
      unassigned: List.from(_defaultUnassigned),
      assigned: List.from(_defaultAssigned),
      onRoadColor: _defaultOnRoadColor,
    );
  }

  // ── Renk Hesaplama ───────────────────────────────────────────────────────

  /// `elapsed` dakikaya göre aktif rengi döndürür.
  Color colorFor({required int elapsed, required bool isAssigned}) {
    final list = isAssigned ? _assigned : _unassigned;
    if (list.isEmpty) return const Color(0xFF48BB78);
    var current = list.first;
    for (final t in list) {
      if (elapsed >= t.minutes) current = t;
    }
    return current.color;
  }

  /// Listenin son eşiğinde mi? (blink & maksimum uyarı için)
  bool isLastThreshold({required int elapsed, required bool isAssigned}) {
    final list = isAssigned ? _assigned : _unassigned;
    if (list.isEmpty) return false;
    return elapsed >= list.last.minutes;
  }
}
