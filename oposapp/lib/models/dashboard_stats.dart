class DashboardStats {
  final int totalUsuarios;
  final int preguntasGeneradasHoy;
  final int solicitudesPendientes;

  DashboardStats({
    required this.totalUsuarios,
    required this.preguntasGeneradasHoy,
    required this.solicitudesPendientes,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsuarios: json['totalUsuarios'] ?? 0,
      preguntasGeneradasHoy: json['preguntasGeneradasHoy'] ?? 0,
      solicitudesPendientes: json['solicitudesPendientes'] ?? 0,
    );
  }
}
