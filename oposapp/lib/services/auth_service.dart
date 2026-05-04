import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/usuario.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const String _TOKEN_KEY = 'auth_token';
  static const String _USER_ROLE_KEY = 'user_role';
  static const String _USER_ID_KEY = 'user_id';
  static const String _USER_NAME_KEY = 'user_name';
  static const String _USER_EMAIL_KEY = 'user_email';
  static const String _EMAIL_VERIFICADO_KEY = 'email_verificado';
  static const String _RGPD_ACEPTADO_KEY = 'rgpd_aceptado';

  static Future<void> saveSession({
    required String token,
    required Usuario usuario,
    required String rol,
  }) async {
    await _secureStorage.write(key: _TOKEN_KEY, value: token);
    await _secureStorage.write(key: _USER_ROLE_KEY, value: rol.toUpperCase());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_USER_ID_KEY, usuario.id);
    await prefs.setString(_USER_NAME_KEY, usuario.nombre);
    await prefs.setString(_USER_EMAIL_KEY, usuario.email);
    await prefs.setBool(_EMAIL_VERIFICADO_KEY, usuario.emailVerificado);
    await prefs.setBool(_RGPD_ACEPTADO_KEY, usuario.rgpdAceptado);
    // Persistir el rol también en prefs para que getCurrentUser() lo restaure
    await prefs.setString(_USER_ROLE_KEY, rol.toUpperCase());
  }

  static Future<String?> getToken() async {
    return _secureStorage.read(key: _TOKEN_KEY);
  }

  static Future<String> getRol() async {
    final rol = await _secureStorage.read(key: _USER_ROLE_KEY);
    return rol ?? 'USER';
  }

  static Future<bool> isAdmin() async {
    final rol = await getRol();
    return rol.toUpperCase() == 'ADMIN';
  }

  static Future<bool> isPremium() async {
    final rol = await getRol();
    return rol.toUpperCase() == 'PREMIUM' || rol.toUpperCase() == 'ADMIN';
  }

  static Future<bool> isTokenExpired() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return true;
      final parts = token.split('.');
      if (parts.length != 3) return true;
      String payload = parts[1];
      String normalized = base64Url.normalize(payload);
      String decoded = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(decoded);
      if (data.containsKey('exp')) {
        final exp = data['exp'] is int ? data['exp'] : int.tryParse(data['exp'].toString()) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        return now > exp;
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  /// True si el token expira en menos de [umbralHoras] horas.
  /// Usado por el interceptor para decidir si refrescar de forma proactiva.
  static Future<bool> tokenProximoAExpirar({int umbralHoras = 24}) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return false;
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = json.decode(decoded) as Map<String, dynamic>;
      if (!data.containsKey('exp')) return false;
      final exp = (data['exp'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final restante = exp - now;
      return restante > 0 && restante < umbralHoras * 3600;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza nombre y apellidos en SharedPreferences tras editar el perfil.
  /// Llamado por PerfilScreen después de que la API confirme el guardado.
  static Future<void> updateNombreLocal({
    required String nombre,
    String? apellidos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_USER_NAME_KEY, nombre);
    if (apellidos != null) {
      await prefs.setString('user_apellidos', apellidos);
    }
  }

  /// Lee los apellidos guardados localmente (complemento a getCurrentUser).
  static Future<String?> getApellidos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_apellidos');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final expired = await isTokenExpired();
    if (expired) {
      await logout();
      return false;
    }
    return true;
  }

  static Future<Usuario?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_USER_ID_KEY);
    final nombre = prefs.getString(_USER_NAME_KEY);
    final email = prefs.getString(_USER_EMAIL_KEY);
    final emailVerificado = prefs.getBool(_EMAIL_VERIFICADO_KEY) ?? false;
    final rgpdAceptado = prefs.getBool(_RGPD_ACEPTADO_KEY) ?? false;
    final rol = prefs.getString(_USER_ROLE_KEY) ?? 'USER';

    if (id == null || nombre == null || email == null) return null;

    return Usuario(
      id: id,
      nombre: nombre,
      email: email,
      fechaRegistro: DateTime.now(),
      emailVerificado: emailVerificado,
      rgpdAceptado: rgpdAceptado,
      rol: rol,
    );
  }

  static Future<void> logout() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Guarda el nuevo token tras un refresh exitoso (mantiene el resto de sesión).
  static Future<void> actualizarToken(String nuevoToken) async {
    await _secureStorage.write(key: _TOKEN_KEY, value: nuevoToken);
  }
}
