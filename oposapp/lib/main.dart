import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'cache/hive_cache.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barra de estado transparente sobre el hero naranja del splash
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Solo activar logs de Dio en debug nativo (no en Web)
  if (kDebugMode && !kIsWeb) ApiService.enableLogging();

  await Hive.initFlutter();
  await HiveCache.init();
  runApp(const OposApp());
}

class OposApp extends StatelessWidget {
  const OposApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OposApp',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,     // ← core/routing/app_router.dart
      themeMode: ThemeMode.light,
      theme: AppTheme.light,       // ← core/theme/app_theme.dart
    );
  }
}
