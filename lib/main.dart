import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/order_color_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Sistem UI Ayarları ────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Yalnızca dikey yön ───────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Google Fonts önbelleğe yükle ─────────────────────────
  // ignore: deprecated_member_use
  GoogleFonts.config.allowRuntimeFetching = true;

  // ── Firebase Başlat ───────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics: yakalanmayan hataları kaydet ─────────────
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // ── Tarih yerelleştirme verilerini yükle (tr_TR, intl) ───
  await initializeDateFormatting('tr_TR');

  // ── Önceki Oturumu Yükle ──────────────────────────────────
  await AuthService.instance.init();

  // ── Sipariş renk eşiklerini yükle ────────────────────────────────────────
  await OrderColorService.instance.load();

  runApp(const ZirveGoApp());
}

class ZirveGoApp extends StatelessWidget {
  const ZirveGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZirveGo Yönetici',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme, // Koyu tema ileride eklenecek
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      // localizationsDelegates ve supportedLocales ileride eklenecek
    );
  }
}
