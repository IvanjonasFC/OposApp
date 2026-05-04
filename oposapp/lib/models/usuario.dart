class Usuario {
  final int id;
  final String email;
  final String nombre;
  final String? apellidos;
  final DateTime fechaRegistro;
  final bool rgpdAceptado;
  final DateTime? rgpdFechaAceptacion;
  final bool emailVerificado;
  final String rol;

  Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    this.apellidos,
    required this.fechaRegistro,
    this.rgpdAceptado = false,
    this.rgpdFechaAceptacion,
    this.emailVerificado = false,
    this.rol = 'USER',
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? json['usuarioId'] ?? 0,
      email: json['email'] ?? '',
      nombre: json['nombre'] ?? json['username'] ?? 'Usuario',
      apellidos: json['apellidos'],
      fechaRegistro: json['fechaRegistro'] != null
          ? DateTime.parse(json['fechaRegistro'] + 'Z').toLocal()
          : DateTime.now(),
      rgpdAceptado: json['rgpdAceptado'] ?? false,
      rgpdFechaAceptacion: json['rgpdFechaAceptacion'] != null
          ? DateTime.parse(json['rgpdFechaAceptacion'] + 'Z').toLocal()
          : null,
      emailVerificado: json['emailVerificado'] ?? false,
      rol: (json['rol'] ?? 'USER').toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'apellidos': apellidos,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'rgpdAceptado': rgpdAceptado,
      'rgpdFechaAceptacion': rgpdFechaAceptacion?.toIso8601String(),
      'emailVerificado': emailVerificado,
      'rol': rol,
    };
  }

  bool get isAdmin   => rol == 'ADMIN';
  bool get isPremium => rol == 'PREMIUM' || rol == 'ADMIN';
  bool get isFree    => rol == 'USER';
}
