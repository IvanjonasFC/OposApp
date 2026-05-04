
import 'dart:io';

/// Constantes de conexión al backend Spring Boot.
/// Fuente de verdad: si cambias la URL, solo toca este fichero.
///
/// CONFIGURACIÓN PARA DESARROLLO:
///   Edita [baseUrlLan] con la IP de tu NAS y el puerto del backend.
///   Compilar APK producción:
///     flutter build apk --dart-define=PRODUCCION=true --release
class ApiConstants {
  ApiConstants._();

  // ── URLs ──────────────────────────────────────────────────────────────────

  /// HTTPS producción — dominio público con certificado Let's Encrypt.
  /// Sustituir por el dominio real antes de compilar la APK de producción.
  static const String baseUrlProduccion = 'https://api.tu-dominio.ejemplo.com/api';

  /// LAN local / VPN — acceso directo al NAS por IP.
  /// Sustituir <IP_NAS> y <PUERTO> por los valores de tu entorno.
  static const String _nasIp   = '<IP_NAS>';
  static const int    _nasPort = 8083;
  static const String baseUrlLan = 'http://$_nasIp:$_nasPort/api';

  /// Emulador Android — 10.0.2.2 apunta al localhost del PC host.
  static const String baseUrlAndroid = 'http://10.0.2.2:$_nasPort/api';

  /// Flutter Web en el mismo PC que el backend.
  static const String baseUrlLocal = 'http://localhost:$_nasPort/api';

  // ── Selector automático de URL ────────────────────────────────────────────
  //
  //  Compilar APK de producción:
  //    flutter build apk --dart-define=PRODUCCION=true --release
  //
  //  Desarrollo LAN (defecto en dispositivo físico Android):
  //    flutter run
  //
  static const bool _esProduccion =
      bool.fromEnvironment('PRODUCCION', defaultValue: false);

  static String get baseUrl {
    if (_esProduccion) return baseUrlProduccion;
    try {
      if (Platform.isAndroid) return baseUrlLan;
      return baseUrlLocal;
    } catch (_) {
      return baseUrlLocal;
    }
  }

  // ── Timeouts (ms) ─────────────────────────────────────────────────────────
  static const int connectTimeout = 8000;
  static const int receiveTimeout = 20000;
  static const int scrapTimeout   = 30000;
  /// Ollama puede tardar hasta 2 min generando preguntas
  static const int ollamaTimeout  = 120000;

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static const String login           = '/auth/login';
  static const String registro        = '/auth/registro';
  static const String refresh         = '/auth/refresh';
  static const String verificarEmail  = '/auth/verificar-email';
  static const String convocatorias   = '/convocatorias';
  static const String buscarBopa      = '/convocatorias/buscar';
  static const String favoritos       = '/convocatorias/guardadas';
  static const String notificaciones  = '/notificaciones';
  static const String tests           = '/tests';
  static const String misSolicitudes  = '/tests/mis-solicitudes';
  static const String estadisticas    = '/estadisticas/usuario';
  static const String userMe          = '/user/me';
  static const String userPerfil      = '/user/perfil';
  static const String userExport      = '/user/export';
  static const String userDelete      = '/user/delete';
  static const String adminStats      = '/admin/stats';
  static const String adminUsuarios   = '/admin/usuarios';
  static const String adminAudit      = '/admin/audit';
  static const String adminOllama     = '/admin/ollama/status';
  static const String ads             = '/ads/activo';
}
