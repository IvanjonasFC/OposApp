class Convocatoria {
  final int id;
  final String titulo;
  final DateTime fechaPublicacion;
  final String organismo;
  final String urlBopa;      // campo real: url_bopa en BD
  final String? categoria;
  final String? bopaNumero;
  final String? textoCompleto;
  final int numPlazas;
  final DateTime? fechaScraping;
  final bool leida;
  final bool notificada;
  final bool guardada;

  Convocatoria({
    required this.id,
    required this.titulo,
    required this.fechaPublicacion,
    required this.organismo,
    required this.urlBopa,
    this.categoria,
    this.bopaNumero,
    this.textoCompleto,
    this.numPlazas = 0,
    this.fechaScraping,
    this.leida = false,
    this.notificada = false,
    this.guardada = false,
  });

  factory Convocatoria.fromJson(Map<String, dynamic> json) {
    return Convocatoria(
      id: json['id'],
      titulo: json['titulo'] ?? 'Sin título',
      // fechaPublicacion puede ser solo fecha "2024-10-07" o datetime "2024-10-07T00:00:00"
      // Si ya contiene 'T' es un datetime → añadir 'Z' para indicar UTC y convertir a local
      // Si es solo fecha → parsear directamente (no tiene componente hora que convertir)
      fechaPublicacion: _parseDate(json['fechaPublicacion']),
      organismo: json['organismo'] ?? 'No especificado',
      // El backend serializa urlBopa (camelCase de url_bopa)
      urlBopa: json['urlBopa'] ?? json['urlPdf'] ?? json['url_bopa'] ?? '',
      categoria: json['categoria'],
      bopaNumero: json['bopaNumero'] ?? json['bopa_numero'],
      textoCompleto: json['textoCompleto'] ?? json['texto_completo'],
      numPlazas: json['numPlazas'] ?? json['num_plazas'] ?? 0,
      fechaScraping: json['fechaScraping'] != null || json['fecha_scraping'] != null
          ? _parseDateTime(json['fechaScraping'] ?? json['fecha_scraping'])
          : null,
      leida: json['leida'] ?? false,
      notificada: json['notificada'] ?? false,
      guardada: json['guardada'] ?? false,
    );
  }

  Convocatoria copyWith({bool? leida, bool? notificada, bool? guardada}) {
    return Convocatoria(
      id: id,
      titulo: titulo,
      fechaPublicacion: fechaPublicacion,
      organismo: organismo,
      urlBopa: urlBopa,
      categoria: categoria,
      bopaNumero: bopaNumero,
      textoCompleto: textoCompleto,
      numPlazas: numPlazas,
      fechaScraping: fechaScraping,
      leida: leida ?? this.leida,
      notificada: notificada ?? this.notificada,
      guardada: guardada ?? this.guardada,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'fechaPublicacion': fechaPublicacion.toIso8601String(),
        'organismo': organismo,
        'urlBopa': urlBopa,
        'categoria': categoria,
        'bopaNumero': bopaNumero,
        'textoCompleto': textoCompleto,
        'numPlazas': numPlazas,
        'fechaScraping': fechaScraping?.toIso8601String(),
        'leida': leida,
        'notificada': notificada,
        'guardada': guardada,
      };
}

/// Parsea fechas del BOPA que pueden ser solo fecha ("2024-10-07")
/// o datetime completo ("2024-10-07T08:00:00") provenientes del servidor en UTC.
DateTime _parseDate(dynamic raw) {
  if (raw == null) return DateTime.now();
  final s = raw.toString();
  // Si tiene componente de hora → es un timestamp del servidor (UTC) → convertir a local
  if (s.contains('T')) return DateTime.parse(s + 'Z').toLocal();
  // Solo fecha → parsear sin conversión de zona (no hay hora que ajustar)
  return DateTime.parse(s);
}

DateTime _parseDateTime(dynamic raw) {
  final s = raw.toString();
  return DateTime.parse(s.contains('T') && !s.endsWith('Z') ? '${s}Z' : s).toLocal();
}
