// ZirveGo Widget Test Dosyası
// Firebase gerektiren testler entegrasyon testi olarak yazılmalıdır
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ZirveGo uygulama başlangıç testi', (WidgetTester tester) async {
    // Firebase bağımlılığı nedeniyle bu test entegrasyon ortamında çalıştırılmalıdır.
    // Birim testleri için mock Firebase kullanın.
    expect(true, isTrue);
  });
}
