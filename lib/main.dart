import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/local_db/database_service.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'services/database_seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forcer le mode portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialiser Firebase (Phone OTP + Google Sign-In)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialiser SQLite et peupler les données initiales
  final db = DatabaseService();
  try {
    await DatabaseSeedService(db).seedIfEmpty();
  } catch (e) {
    // Ne pas bloquer le démarrage si le seed échoue
    debugPrint('DB seed skipped: $e');
  }

  runApp(
    const ProviderScope(
      child: TemoignagesApp(),
    ),
  );
}

class TemoignagesApp extends ConsumerWidget {
  const TemoignagesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Témoignages',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B21A8),
        primary: const Color(0xFF6B21A8),
        secondary: const Color(0xFFF59E0B),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      dividerColor: const Color(0xFFE2E8F0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        indicatorColor: const Color(0xFF6B21A8).withAlpha(30),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B21A8),
            );
          }
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF6B21A8));
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
      ),
    );
  }
}
