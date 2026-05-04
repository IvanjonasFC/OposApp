
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../constants/api_constants.dart';

class NetworkService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Comprueba si el dispositivo puede alcanzar el backend del NAS.
  /// Útil para decidir si usar baseUrlLan o baseUrlLocal como fallback.
  static Future<bool> isSameNetwork() async {
    // Extraer host del baseUrlLan definido en ApiConstants (sin hardcodear IPs)
    final uri = Uri.tryParse(ApiConstants.baseUrlLan);
    final host = uri?.host ?? '<IP_NAS>';
    final port = uri?.port ?? 8083;

    // Opción 1: Intentar conectar directamente al backend
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {}

    // Opción 2: Comprobar prefijo de IP WiFi como fallback
    try {
      final String? wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.startsWith('192.168.')) {
        return true;
      }
    } catch (_) {}

    return false;
  }
}
