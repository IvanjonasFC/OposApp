import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ── Tipos de error de dominio ─────────────────────────────────────────────
enum AppErrorType { network, auth, server, timeout, notFound, unknown }

/// Excepción tipada que lanza ApiService.
/// Permite a los repositorios y pantallas distinguir
/// errores de red, autenticación, servidor, etc.
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final AppErrorType type;

  const AppException(
    this.message, {
    this.statusCode,
    this.type = AppErrorType.unknown,
  });

  @override
  String toString() => message;
}

// ── Widget de error reutilizable ──────────────────────────────────────────
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15, color: Colors.black54, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.naranja,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
