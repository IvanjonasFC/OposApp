class AuditLog {
  final int? id;
  final String tabla;
  final String operacion;
  final int? usuarioId;
  final String? datosAnteriores;
  final String? datosNuevos;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? timestamp;

  AuditLog({
    this.id,
    required this.tabla,
    required this.operacion,
    this.usuarioId,
    this.datosAnteriores,
    this.datosNuevos,
    this.ipAddress,
    this.userAgent,
    this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      tabla: json['tabla'] ?? '',
      operacion: json['operacion'] ?? '',
      usuarioId: json['usuarioId'],
      datosAnteriores: json['datosAnteriores'],
      datosNuevos: json['datosNuevos'],
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      // El backend serializa LocalDateTime sin zona → viene como "2026-03-26T10:40:12"
      // Lo tratamos como UTC (así lo guarda el servidor con hibernate.jdbc.time_zone=UTC)
      // y convertimos a hora local del dispositivo con toLocal()
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] + 'Z').toLocal()
          : null,
    );
  }
}
