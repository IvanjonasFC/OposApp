import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/dashboard_stats.dart';
import '../models/audit_log.dart';
import '../models/pregunta.dart';

class AdminException implements Exception {
  final String message;
  final int? statusCode;

  AdminException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class AdminService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  static void enableLogging() {
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
  }

  static bool useMock = false;

  static Future<DashboardStats> getStats(String token) async {
    if (useMock) {
      await Future.delayed(Duration(seconds: 1));
      return DashboardStats(
        totalUsuarios: 1542,
        preguntasGeneradasHoy: 320,
        solicitudesPendientes: 12,
      );
    }
    try {
      final response = await _dio.get(
        '/admin/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return DashboardStats.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<List<AuditLog>> getAuditLogs(String token) async {
    if (useMock) {
      await Future.delayed(Duration(seconds: 1));
      return [
        AuditLog(id: 1, tabla: 'usuarios', operacion: 'UPDATE', timestamp: DateTime.now().subtract(Duration(minutes: 5)), ipAddress: '192.168.1.5'),
        AuditLog(id: 2, tabla: 'preguntas', operacion: 'INSERT', timestamp: DateTime.now().subtract(Duration(hours: 1))),
      ];
    }
    try {
      final response = await _dio.get(
        '/admin/audit',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as List).map((json) => AuditLog.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> getSystemHealth(String token) async {
    try {
      final response = await _dio.get(
        '/admin/system-health',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<bool> getOllamaStatus(String token) async {
    try {
      final response = await _dio.get(
        '/admin/ollama/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['online'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getUsuarios(String token) async {
    try {
      final response = await _dio.get(
        '/admin/usuarios',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<void> cambiarRol(String token, dynamic id, String nuevoRol) async {
    try {
      await _dio.put(
        '/admin/usuarios/$id/rol',
        data: {'rol': nuevoRol},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<void> cambiarEstado(String token, dynamic id, bool activo) async {
    try {
      await _dio.put(
        '/admin/usuarios/$id/estado',
        data: {'activo': activo},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<void> cambiarPassword(String token, dynamic id, String nuevaPassword) async {
    try {
      await _dio.put(
        '/admin/usuarios/$id/password',
        data: {'password': nuevaPassword},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<List<Pregunta>> getPreguntas(String token) async {
    if (useMock) {
      await Future.delayed(Duration(seconds: 1));
      return []; // Return empty for mock or some dummy
    }
    try {
      // The backend returns a Page<Pregunta>, so let's extract 'content' array.
      final response = await _dio.get(
        '/admin/preguntas',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final data = response.data;
      if (data is Map && data.containsKey('content')) {
        return (data['content'] as List).map((json) => Pregunta.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Exception _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      String message = 'Error en el servidor: $statusCode';

      if (statusCode == 403) {
        if (data is Map && data.containsKey('error')) {
          message = data['error'];
        } else if (data is String && data.isNotEmpty) {
           message = data; // A veces el backend puede devolver el JSON como string.
        } else {
          message = 'Acceso Denegado: Conexión segura (Home LAN/VPN) requerida para administración';
        }
        return AdminException(message, statusCode);
      } else if (statusCode == 401) {
        message = 'Sesión expirada o no autorizada.';
      } else if (data is Map && data.containsKey('mensaje')) {
        message = data['mensaje'];
      }
      return Exception(message);
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return Exception('Tiempo de conexión agotado. Verifica tu red.');
    } else {
      return Exception('Error de red al intentar conectar al panel administrativo.');
    }
  }
}
