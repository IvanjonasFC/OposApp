import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/splash_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/admin_dashboard_screen.dart';
import '../../screens/generate_screen.dart';
import '../../screens/test_screen.dart';
import '../../screens/bopa_screen.dart';
import '../../screens/progreso_screen.dart';
import '../../screens/perfil_screen.dart';
import '../../screens/resultado_test_screen.dart';

/// Router central de OposApp.
/// Fuente de verdad para todas las rutas de la app.
/// Referenciado desde main.dart: routerConfig: appRouter
final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  errorBuilder: (_, state) => HomeScreen(),

  routes: [
    // ── Autenticación ────────────────────────────────────────────────────
    GoRoute(path: '/splash',   builder: (_, __) => SplashScreen()),
    GoRoute(path: '/login',    builder: (_, __) => LoginScreen()),
    GoRoute(
      path: '/register',
      // Abre LoginScreen directamente en modo registro
      builder: (_, __) => LoginScreen(modoRegistroInicial: true),
    ),

    // ── Pantallas principales ─────────────────────────────────────────────
    GoRoute(path: '/home',     builder: (_, __) => HomeScreen()),
    GoRoute(path: '/bopa',     builder: (_, __) => BOPAScreen()),
    GoRoute(path: '/generate', builder: (_, __) => const GenerateScreen()),
    GoRoute(path: '/progreso', builder: (_, __) => ProgresoScreen()),
    GoRoute(path: '/perfil',   builder: (_, __) => PerfilScreen()),

    // ── Tests ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/test/:id',
      builder: (_, state) => TestScreen(testId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/resultado',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) return HomeScreen();
        return ResultadoTestScreen(
          preguntas:    extra['preguntas'],
          respuestas:   extra['respuestas'],
          aciertos:     extra['aciertos'],
          fallos:       extra['fallos'],
          nota:         extra['nota'],
          testId:       extra['testId'] ?? '0',
          guardadoEnBD: extra['guardadoEnBD'] ?? false,
        );
      },
    ),

    // ── Panel de administración (solo ROLE_ADMIN) ─────────────────────────
    GoRoute(path: '/admin', builder: (_, __) => AdminDashboardScreen()),
  ],
);
