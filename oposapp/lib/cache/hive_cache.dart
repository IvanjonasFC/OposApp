import 'package:hive_flutter/hive_flutter.dart';
import '../models/convocatoria.dart';
import '../models/pregunta.dart';

/// Caché local con Hive para funcionamiento offline.
/// Cubre RNF-10 (últimas 30 convocatorias en caché) y RNF-34 (tests guardados).
class HiveCache {
  static const String _TESTS_BOX          = 'tests_box';
  static const String _REPORTES_BOX       = 'reportes_box';
  static const String _CONVOCATORIAS_BOX  = 'convocatorias_box';
  static const String _CONVOCATORIAS_KEY  = 'ultima_lista';
  static const String _FAVORITOS_KEY      = 'favoritos_lista';
  static const int    _MAX_CONVOCATORIAS  = 30;

  // ─── Inicialización ──────────────────────────────────────────────────────
  static Future<void> init() async {
    await Hive.openBox(_TESTS_BOX);
    await Hive.openBox(_REPORTES_BOX);
    await Hive.openBox(_CONVOCATORIAS_BOX);
  }

  // ─── Convocatorias (offline RNF-10) ──────────────────────────────────────

  /// Guarda las últimas [_MAX_CONVOCATORIAS] convocatorias para modo offline.
  static Future<void> saveConvocatorias(List<Convocatoria> lista) async {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    final recorte = lista.take(_MAX_CONVOCATORIAS).toList();
    final jsonList = recorte.map((c) => c.toJson()).toList();
    await box.put(_CONVOCATORIAS_KEY, jsonList);
  }

  /// Devuelve las convocatorias en caché, o lista vacía si no hay nada.
  static List<Convocatoria> getCachedConvocatorias() {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    final raw = box.get(_CONVOCATORIAS_KEY);
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((e) => Convocatoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// True si hay convocatorias guardadas en caché.
  static bool hasConvocatorias() {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    return box.containsKey(_CONVOCATORIAS_KEY);
  }

  // ─── Favoritos (offline RF-08) ────────────────────────────────────────────

  /// Persiste la lista completa de favoritos del usuario.
  static Future<void> saveFavoritos(List<Convocatoria> lista) async {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    final jsonList = lista.map((c) => c.toJson()).toList();
    await box.put(_FAVORITOS_KEY, jsonList);
  }

  /// Devuelve los favoritos en caché, o lista vacía si no hay nada.
  static List<Convocatoria> getCachedFavoritos() {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    final raw = box.get(_FAVORITOS_KEY);
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((e) => Convocatoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// True si hay favoritos guardados en caché.
  static bool hasFavoritos() {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    return box.containsKey(_FAVORITOS_KEY);
  }

  /// Actualiza el estado `guardada` de una convocatoria en el caché de favoritos.
  /// Llamado tras toggle para mantener sincronía offline.
  static Future<void> actualizarFavorito(int convId, bool guardada) async {
    final box = Hive.box(_CONVOCATORIAS_BOX);
    final raw = box.get(_FAVORITOS_KEY);
    if (raw == null) return;
    final lista = (raw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (guardada) {
      // No hacer nada — la convocatoria ya debería estar o se refresca en next load
    } else {
      // Eliminar del caché de favoritos si se desfavoritea estando offline
      lista.removeWhere((e) => e['id'] == convId);
    }
    await box.put(_FAVORITOS_KEY, lista);
  }


  // ─── Tests guardados (RNF-34) ─────────────────────────────────────────────

  /// Guarda la lista de preguntas de un test para revisión offline.
  static Future<void> saveTest(String id, List<Pregunta> preguntas) async {
    final box = Hive.box(_TESTS_BOX);
    final listaJson = preguntas.map((p) => p.toJson()).toList();
    await box.put(id, listaJson);
  }

  /// Recupera un test guardado, o null si no existe.
  static Future<List<Pregunta>?> getTest(String id) async {
    final box = Hive.box(_TESTS_BOX);
    final raw = box.get(id);
    if (raw == null) return null;
    return (raw as List<dynamic>)
        .map((e) => Pregunta.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// IDs de todos los tests guardados localmente.
  static List<String> getTestIds() {
    final box = Hive.box(_TESTS_BOX);
    return box.keys.map((e) => e.toString()).toList();
  }

  // ─── Reportes ─────────────────────────────────────────────────────────────

  static Future<void> saveReporte(String testId, Map<String, dynamic> reporte) async {
    final box = Hive.box(_REPORTES_BOX);
    await box.put(testId, reporte);
  }

  static Map<String, dynamic>? getReporte(String testId) {
    final box = Hive.box(_REPORTES_BOX);
    final raw = box.get(testId);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }
}
