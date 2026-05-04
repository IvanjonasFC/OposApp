class Pregunta {
  final int id;
  final int testId;
  final String textoPregunta;
  final String opcionA;
  final String opcionB;
  final String opcionC;
  final String opcionD;
  final String respuestaCorrecta; // 'A', 'B', 'C', 'D'
  final String explicacion;
  final String tema;
  final String oposicion;
  final String dificultad;

  Pregunta({
    required this.id,
    required this.testId,
    required this.textoPregunta,
    required this.opcionA,
    required this.opcionB,
    required this.opcionC,
    required this.opcionD,
    required this.respuestaCorrecta,
    required this.explicacion,
    required this.tema,
    required this.oposicion,
    required this.dificultad,
  });

  factory Pregunta.fromJson(Map<String, dynamic> json) {
    return Pregunta(
      id: json['id'] ?? 0,
      testId: json['testId'] ?? 0,
      textoPregunta: json['textoPregunta'] ?? '',
      opcionA: json['opcionA'] ?? '',
      opcionB: json['opcionB'] ?? '',
      opcionC: json['opcionC'] ?? '',
      opcionD: json['opcionD'] ?? '',
      respuestaCorrecta: json['respuestaCorrecta'] ?? 'A',
      explicacion: json['explicacion'] ?? '',
      tema: json['tema'] ?? '',
      oposicion: json['oposicion'] ?? '',
      dificultad: json['dificultad'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testId': testId,
      'textoPregunta': textoPregunta,
      'opcionA': opcionA,
      'opcionB': opcionB,
      'opcionC': opcionC,
      'opcionD': opcionD,
      'respuestaCorrecta': respuestaCorrecta,
      'explicacion': explicacion,
      'tema': tema,
      'oposicion': oposicion,
      'dificultad': dificultad,
    };
  }
}
