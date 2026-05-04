enum TipoNotificacion { convocatoria, test, sistema, info }

class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final TipoNotificacion tipo;
  final bool leida;
  final DateTime creadaEn;
  final int? referenciaId;

  const Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.leida,
    required this.creadaEn,
    this.referenciaId,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] ?? 0,
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      tipo: _parseTipo(json['tipo']),
      leida: json['leida'] ?? false,
      creadaEn: json['creadaEn'] != null
          ? DateTime.parse(json['creadaEn'] + 'Z').toLocal()
          : DateTime.now(),
      referenciaId: json['referenciaId'],
    );
  }

  static TipoNotificacion _parseTipo(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'convocatoria': return TipoNotificacion.convocatoria;
      case 'test':         return TipoNotificacion.test;
      case 'sistema':      return TipoNotificacion.sistema;
      default:             return TipoNotificacion.info;
    }
  }

  /// Copia con leida=true para actualizar la lista local sin hacer fetch
  Notificacion comoLeida() => Notificacion(
    id: id, titulo: titulo, mensaje: mensaje,
    tipo: tipo, leida: true, creadaEn: creadaEn,
    referenciaId: referenciaId,
  );
}
