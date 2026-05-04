/// Cliente HTTP centralizado de OposApp.
///
/// Gestiona toda la comunicación con el backend Spring Boot mediante [Dio].
///
/// **Características principales:**
/// - Interceptor JWT automático: adjunta `Authorization: Bearer <token>` en cada petición.
/// - Renovación silenciosa del token cuando queda menos de 24 h de validez.
/// - Logout automático si el token ha expirado.
/// - Timeouts diferenciados: 8 s para operaciones normales, 120 s para llamadas a Ollama.
/// - Método `_handleError` que mapea códigos HTTP → [AppException] tipados.
///
/// Todos los métodos son estáticos para usarse sin instanciar la clase:
/// ```dart
/// final convocatorias = await ApiService.getConvocatorias(0, 20);
/// ```
import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/routing/app_router.dart';
import '../models/usuario.dart';
import '../models/convocatoria.dart';
import '../models/solicitud_generacion.dart';
import '../models/pregunta.dart';
import '../models/estadisticas.dart';
import '../models/notificacion.dart';
import '../services/auth_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) {
          // Token expirado → logout inmediato
          if (await AuthService.isTokenExpired()) {
            await AuthService.logout();
            appRouter.go('/login');
            return handler.reject(DioException(
              requestOptions: options,
              error: const AppException('La sesión ha expirado', type: AppErrorType.auth),
            ));
          }
          // Token próximo a expirar (< 24h) → refrescar silenciosamente
          if (await AuthService.tokenProximoAExpirar()) {
            try {
              final res = await Dio().post(
                '${ApiConstants.baseUrl}/auth/refresh',
                options: Options(headers: {'Authorization': 'Bearer $token'}),
              );
              final nuevoToken = res.data['token'] as String?;
              if (nuevoToken != null && nuevoToken.isNotEmpty) {
                await AuthService.actualizarToken(nuevoToken);
                options.headers['Authorization'] = 'Bearer $nuevoToken';
              } else {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (_) {
              // Si el refresh falla, continuamos con el token actual
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await AuthService.logout();
          appRouter.go('/login');
          return handler.next(error);
        } else if (error.response?.statusCode == 403) {
          appRouter.go('/home');
          return handler.resolve(Response(
            requestOptions: error.requestOptions,
            data: {},
            statusCode: 200,
          ));
        }
        handler.next(error);
      },
    ));

  static void enableLogging() {
    _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      return response.data;
    } on DioException catch (e) { throw _handleError(e); }
  }

  /// POST /api/auth/refresh — renueva el JWT sin contraseña.
  /// Llamado automáticamente por el interceptor cuando el token tiene < 24h.
  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final token = await AuthService.getToken();
      final response = await _dio.post('/auth/refresh',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data;
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<Map<String, dynamic>> registro({
    required String email, required String password,
    String? nombre, String? apellidos, required bool rgpdAceptado,
  }) async {
    try {
      final response = await _dio.post('/auth/registro', data: {
        'email': email, 'password': password,
        'nombre': nombre, 'apellidos': apellidos, 'rgpdAceptado': rgpdAceptado,
      });
      return response.data;
    } on DioException catch (e) { throw _handleError(e); }
  }

  // ─── CONVOCATORIAS ───────────────────────────────────────────────────────

  static Future<List<Convocatoria>> getConvocatorias(int page, int size) async {
    try {
      final response = await _dio.get('/convocatorias', queryParameters: {'page': page, 'size': size});
      if (response.data is Map && response.data['content'] != null) {
        return (response.data['content'] as List).map((j) => Convocatoria.fromJson(j)).toList();
      }
      return (response.data as List).map((j) => Convocatoria.fromJson(j)).toList();
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<List<Convocatoria>> buscarConvocatorias(String termino) async {
    try {
      final response = await _dio.get('/convocatorias/buscar', queryParameters: {'q': termino});
      if (response.data is Map && response.data['content'] != null) {
        return (response.data['content'] as List).map((j) => Convocatoria.fromJson(j)).toList();
      }
      return (response.data as List).map((j) => Convocatoria.fromJson(j)).toList();
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> guardarFavorito(int id) async {
    try { await _dio.post('/convocatorias/$id/guardar'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> eliminarFavorito(int id) async {
    try { await _dio.delete('/convocatorias/$id/guardar'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<List<Convocatoria>> getFavoritos() async {
    try {
      final response = await _dio.get('/convocatorias/guardadas');
      if (response.data is Map && response.data['content'] != null) {
        return (response.data['content'] as List).map((j) => Convocatoria.fromJson(j)).toList();
      }
      if (response.data is List) return (response.data as List).map((j) => Convocatoria.fromJson(j)).toList();
      return [];
    } on DioException catch (e) { throw _handleError(e); }
  }

  // ─── NOTIFICACIONES ──────────────────────────────────────────────────────

  static Future<int> getNotificacionesBadge() async {
    try {
      final response = await _dio.get('/notificaciones/no-leidas/count');
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return 0;
      throw _handleError(e);
    }
  }

  static Future<List<Notificacion>> getNotificaciones() async {
    try {
      final response = await _dio.get('/notificaciones');
      return (response.data as List).map((j) => Notificacion.fromJson(j)).toList();
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> marcarNotificacionLeida(int id) async {
    try { await _dio.patch('/notificaciones/$id/leer'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> marcarTodasLeidas() async {
    try { await _dio.patch('/notificaciones/leer-todas'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  // ─── TESTS / SOLICITUDES ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> ejecutarScraping() async {
    try { final r = await _dio.post('/admin/bopa/scrape'); return r.data; }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<SolicitudGeneracion> crearSolicitud({required SolicitudGeneracion solicitud}) async {
    try {
      final response = await _dio.post('/tests/generate', data: {
        'tema': solicitud.tema, 'numPreguntas': solicitud.numPreguntas,
        'dificultad': solicitud.dificultad, 'oposicion': solicitud.oposicion,
      }, options: Options(receiveTimeout: const Duration(milliseconds: ApiConstants.ollamaTimeout)));
      return SolicitudGeneracion.fromJson(response.data);
    } on DioException catch (e) { throw _handleError(e); }
  }

  /// Historial del usuario — GET /api/tests/mis-solicitudes (endpoint nuevo)
  static Future<List<SolicitudGeneracion>> getHistorialSolicitudes() async {
    try {
      final response = await _dio.get('/tests/mis-solicitudes');
      return (response.data as List).map((j) => SolicitudGeneracion.fromJson(j)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw _handleError(e);
    }
  }

  /// Polling — GET /api/tests/solicitud/{id}/estado
  static Future<SolicitudGeneracion> verificarSolicitud(int id) async {
    try {
      final response = await _dio.get('/tests/solicitud/$id/estado');
      return SolicitudGeneracion.fromJson(response.data);
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<List<Pregunta>> getPreguntasSolicitud(int solicitudId) async {
    try {
      final response = await _dio.get('/tests/$solicitudId');
      if (response.data is Map && response.data['preguntas'] != null) {
        return (response.data['preguntas'] as List).map((j) => Pregunta.fromJson(j)).toList();
      }
      return [];
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<Estadisticas> getEstadisticas(int usuarioId) async {
    try {
      // Usar el endpoint seguro /mias que usa el token JWT
      final response = await _dio.get('/estadisticas/mias');
      return Estadisticas.fromJson(response.data);
    } on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> guardarResultado({required int testId, required List<Map<String, dynamic>> respuestas}) async {
    try { await _dio.put('/tests/$testId/respuestas', data: respuestas); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> deleteSolicitud(int solicitudId) async {
    try { await _dio.delete('/tests/solicitud/$solicitudId'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> eliminarNotificacion(int id) async {
    try { await _dio.delete('/notificaciones/$id'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<void> eliminarTodasNotificaciones() async {
    try { await _dio.delete('/notificaciones/todas'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  // ─── ANUNCIOS ─────────────────────────────────────────────────────────────

  /// GET /api/ads/random — devuelve el anuncio o null si el servidor da 204 (PREMIUM/sin anuncios)
  static Future<Map<String, dynamic>?> getAnuncioAleatorio() async {
    try {
      final response = await _dio.get('/ads/random');
      if (response.statusCode == 204 || response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw _handleError(e);
    }
  }

  /// POST /api/ads/{id}/click — registra el clic y devuelve la URL destino
  static Future<String?> registrarClicAnuncio(int id) async {
    try {
      final response = await _dio.post('/ads/$id/click');
      return response.data['url'] as String?;
    } on DioException catch (e) { throw _handleError(e); }
  }

  // ─── RGPD ────────────────────────────────────────────────────────────────

  static Future<void> solicitarBaja() async {
    try { await _dio.post('/user/delete'); }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<Map<String, dynamic>> exportarDatos() async {
    try { final r = await _dio.get('/user/export'); return r.data as Map<String, dynamic>; }
    on DioException catch (e) { throw _handleError(e); }
  }

  static Future<Map<String, dynamic>> updatePerfil({
    required String nombre,
    required String apellidos,
    required String username,
  }) async {
    try {
      final r = await _dio.put('/user/perfil', data: {
        'nombre': nombre,
        'apellidos': apellidos,
        'username': username,
      });
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) { throw _handleError(e); }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────────────────────

  static AppException _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      dynamic data = e.response!.data;
      if (data is String) { try { data = json.decode(data); } catch (_) {} }
      String message = 'Error del servidor';
      AppErrorType type = AppErrorType.server;
      if (statusCode == 401 || statusCode == 403) {
        message = 'Credenciales incorrectas o sesión expirada'; type = AppErrorType.auth;
      } else if (statusCode == 404) {
        message = 'Recurso no encontrado'; type = AppErrorType.notFound;
      } else if (statusCode == 429) {
        message = 'Demasiadas peticiones. Intenta más tarde.';
      } else if (data is Map) {
        final raw = data['message'];
        if (raw is String && raw.isNotEmpty) message = raw;
        else if (raw is Map) message = raw.values.join(', ');
        else message = data['error']?.toString() ?? 'Error desconocido';
      }
      return AppException(message, statusCode: statusCode, type: type);
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
      return const AppException('Tiempo de conexión agotado.', type: AppErrorType.timeout);
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return const AppException('El servidor tardó demasiado.', type: AppErrorType.timeout);
    } else if (e.type == DioExceptionType.connectionError) {
      return const AppException('Sin conexión al servidor.', type: AppErrorType.network);
    }
    return AppException(e.message ?? 'Error inesperado', type: AppErrorType.unknown);
  }
}
