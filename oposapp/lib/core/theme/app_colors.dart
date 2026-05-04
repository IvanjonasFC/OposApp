import 'package:flutter/material.dart';

// ── Paleta OposApp ────────────────────────────────────────────────────────
// Todas las pantallas importan AppColors en lugar de hardcodear 0xFFFF6B00.
// Si mañana cambia la marca, cambias aquí y se propaga a toda la app.
abstract final class AppColors {
  static const naranja     = Color(0xFFFF6B00);
  static const naranjaOsc  = Color(0xFFE55A00);
  static const fondo       = Color(0xFFF5F5F5);
  static const superficieCrema = Color(0xFFFFF3E0);
  static const bordeNaranja    = Color(0xFFFFCC80);
  static const error       = Color(0xFFB00020);
  static const exito       = Color(0xFF2E7D32);
  static const advertencia = Color(0xFFE65100);
}
