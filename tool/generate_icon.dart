// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// ZirveGo Yönetici — App Icon Generator
///
/// Tasarım:
///  • Koyu lacivert zemin  (#0A1628)
///  • Ortada beyaz "Z" harfi (kalın, cesur)
///  • "Z"nin üzerinde küçük altın/turuncu bir taç (3 diş)
///  • Zemin üzerinde hafif radyal aydınlatma efekti
///
/// Çalıştır:  dart run tool/generate_icon.dart
void main() {
  const int size = 1024;

  final image = img.Image(width: size, height: size);

  // ── 1. Zemin ────────────────────────────────────────────────
  img.fill(image, color: img.ColorRgb8(10, 22, 40)); // #0A1628

  // ── 2. Radyal aydınlatma efekti ─────────────────────────────
  _drawGlow(image, size);

  // ── 3. Taç (yönetim simgesi) ────────────────────────────────
  _drawCrown(image, size);

  // ── 4. "Z" harfi ────────────────────────────────────────────
  _drawZ(image, size);

  // ── 5. Alt çizgi / vurgu ────────────────────────────────────
  _drawBottomAccent(image, size);

  // ── Kaydet ──────────────────────────────────────────────────
  final outDir = Directory('assets/icons');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final outFile = File('assets/icons/app_icon.png');
  outFile.writeAsBytesSync(img.encodePng(image));
  print('✅  İcon oluşturuldu → assets/icons/app_icon.png  ($size×$size)');
}

// ── Radyal mavi parıltı ──────────────────────────────────────────────────────
void _drawGlow(img.Image image, int size) {
  final cx = size ~/ 2;
  final cy = size ~/ 2;
  for (int r = 440; r >= 180; r -= 4) {
    final t = (440 - r) / (440 - 180);
    final alpha = (t * t * 30).toInt().clamp(0, 30);
    _drawCircleAlpha(image, cx, cy, r, 30, 90, 200, alpha);
  }
}

// ── Taç (3 diş) ──────────────────────────────────────────────────────────────
void _drawCrown(img.Image image, int size) {
  final gold = img.ColorRgb8(255, 196, 57); // #FFC439

  // Taç gövdesi (yatay çubuk)
  const cx     = 512;
  const baseY  = 228;
  const barH   = 44;
  const barW   = 240;
  img.fillRect(
    image,
    x1: cx - barW ~/ 2, y1: baseY,
    x2: cx + barW ~/ 2, y2: baseY + barH,
    color: gold,
  );

  // Orta diş (en uzun)
  _drawTooth(image, cx, baseY, 82, 32, gold);
  // Sol diş
  _drawTooth(image, cx - 88, baseY, 60, 28, gold);
  // Sağ diş
  _drawTooth(image, cx + 88, baseY, 60, 28, gold);

  // Taç alt kısmı (hafif genişleme)
  img.fillRect(
    image,
    x1: cx - barW ~/ 2 - 10, y1: baseY + barH,
    x2: cx + barW ~/ 2 + 10, y2: baseY + barH + 18,
    color: gold,
  );
}

void _drawTooth(
  img.Image image, int cx, int baseY, int height, int halfW, img.Color color) {
  // Üçgen şekli — filled triangle
  for (int dy = 0; dy < height; dy++) {
    final progress = dy / height;
    final halfCur  = (halfW * (1.0 - progress)).round();
    img.drawLine(
      image,
      x1: cx - halfCur, y1: baseY - dy,
      x2: cx + halfCur, y2: baseY - dy,
      color: color,
    );
  }
}

// ── "Z" harfi ────────────────────────────────────────────────────────────────
void _drawZ(img.Image image, int size) {
  final white = img.ColorRgb8(255, 255, 255);

  const left   = 268;
  const right  = 756;
  const top    = 312;
  const bottom = 796;
  const barH   = 72; // yatay çubuk yüksekliği
  const diagW  = 68; // diyagonal çizgi kalınlığı

  // Üst yatay çubuk
  img.fillRect(image, x1: left, y1: top, x2: right, y2: top + barH, color: white);

  // Alt yatay çubuk
  img.fillRect(image, x1: left, y1: bottom - barH, x2: right, y2: bottom, color: white);

  // Diyagonal (sağ üstten sol alta)
  img.drawLine(
    image,
    x1: right - diagW ~/ 2, y1: top + barH,
    x2: left  + diagW ~/ 2, y2: bottom - barH,
    color: white,
    thickness: diagW,
    antialias: true,
  );
}

// ── Alt vurgu çizgisi ─────────────────────────────────────────────────────────
void _drawBottomAccent(img.Image image, int size) {
  final gold = img.ColorRgb8(255, 196, 57);
  const cx   = 512;
  const y    = 840;
  const w    = 160;
  const h    = 8;
  img.fillRect(
    image,
    x1: cx - w ~/ 2, y1: y,
    x2: cx + w ~/ 2, y2: y + h,
    color: gold,
  );
}

// ── Yardımcı: alfa kanallı çember çiz ─────────────────────────────────────────
void _drawCircleAlpha(
    img.Image image, int cx, int cy, int radius, int r, int g, int b, int a) {
  if (a <= 0) return;
  final color = img.ColorRgba8(r, g, b, a);

  final x0 = (cx - radius).clamp(0, image.width - 1);
  final x1 = (cx + radius).clamp(0, image.width - 1);
  final y0 = (cy - radius).clamp(0, image.height - 1);
  final y1 = (cy + radius).clamp(0, image.height - 1);

  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= radius && dist >= radius - 4) {
        _blendPixel(image, x, y, color);
      }
    }
  }
}

// Alfa harmanlama
void _blendPixel(img.Image image, int x, int y, img.ColorRgba8 src) {
  final dst = image.getPixel(x, y);
  final srcA = src.a / 255.0;
  final dstA = 1.0 - srcA;
  final nr = (src.r * srcA + dst.r * dstA).round();
  final ng = (src.g * srcA + dst.g * dstA).round();
  final nb = (src.b * srcA + dst.b * dstA).round();
  image.setPixelRgb(x, y, nr, ng, nb);
}
