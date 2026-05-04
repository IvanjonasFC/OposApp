enum EstadoSolicitud { pendiente, procesando, completado, error }

class SolicitudGeneracion {
  final int id;
  final String tema;
  final String oposicion;
  final String dificultad;
  final int numPreguntas;
  final EstadoSolicitud estadoEnum;
  final String? fechaSolicitud;
  final String? fechaCompletado;
  final int? testId;

  /// Veces que el usuario ha completado este test (viene del backend)
  final int vecesRealizado;

  /// Porcentaje de aciertos del último intento (0–100, null si nunca realizado)
  final double? ultimaNota;

  SolicitudGeneracion({
    required this.id,
    required this.tema,
    required this.oposicion,
    required this.dificultad,
    required this.numPreguntas,
    required this.estadoEnum,
    this.fechaSolicitud,
    this.fechaCompletado,
    this.testId,
    this.vecesRealizado = 0,
    this.ultimaNota,
  });

  /// Acceso como string para comparaciones en la UI
  String get estado => estadoEnum.name;

  factory SolicitudGeneracion.fromJson(Map<String, dynamic> json) {
    return SolicitudGeneracion(
      id: json['id'] ?? json['solicitudId'] ?? 0,
      tema: json['tema'] ?? '',
      oposicion: json['oposicion'] ?? '',
      dificultad: json['dificultad'] ?? 'Media',
      numPreguntas: json['numPreguntas'] ?? 10,
      estadoEnum: _parseEstado(json['estado']),
      fechaSolicitud: json['fechaSolicitud']?.toString(),
      fechaCompletado: json['fechaCompletado']?.toString(),
      testId: json['testId'],
      vecesRealizado: json['vecesRealizado'] ?? 0,
      ultimaNota: json['ultimaNota'] != null
          ? (json['ultimaNota'] as num).toDouble()
          : null,
    );
  }

  static EstadoSolicitud _parseEstado(dynamic estadoRaw) {
    final s = (estadoRaw ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'procesando': return EstadoSolicitud.procesando;
      case 'completado': return EstadoSolicitud.completado;
      case 'error':      return EstadoSolicitud.error;
      default:           return EstadoSolicitud.pendiente;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'tema': tema, 'oposicion': oposicion,
    'dificultad': dificultad, 'numPreguntas': numPreguntas,
    'estado': estado, 'fechaSolicitud': fechaSolicitud,
    'fechaCompletado': fechaCompletado, 'testId': testId,
    'vecesRealizado': vecesRealizado, 'ultimaNota': ultimaNota,
  };

  /// Para actualizar estado por polling — conserva vecesRealizado y ultimaNota locales
  SolicitudGeneracion copyWithEstado(SolicitudGeneracion estadoActualizado) {
    return SolicitudGeneracion(
      id: id,
      tema: tema,
      oposicion: oposicion,
      dificultad: dificultad,
      numPreguntas: numPreguntas,
      estadoEnum: estadoActualizado.estadoEnum,
      fechaSolicitud: fechaSolicitud,
      fechaCompletado: estadoActualizado.fechaCompletado ?? fechaCompletado,
      testId: estadoActualizado.testId ?? testId,
      vecesRealizado: vecesRealizado,
      ultimaNota: ultimaNota,
    );
  }
}
