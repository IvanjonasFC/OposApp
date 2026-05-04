class Estadisticas {
  final int testsCompletados;
  final int preguntasRespondidas;
  final int preguntasCorrectas;
  final double porcentajeAciertos;
  final int diasConsecutivos;
  final List<HistorialTest> historial;
  final List<TemaDebil> temasDebiles;
  final List<EvolucionDia> evolucion30d;

  Estadisticas({
    required this.testsCompletados,
    required this.preguntasRespondidas,
    required this.preguntasCorrectas,
    required this.porcentajeAciertos,
    required this.diasConsecutivos,
    required this.historial,
    this.temasDebiles = const [],
    this.evolucion30d = const [],
  });

  factory Estadisticas.fromJson(Map<String, dynamic> json) {
    return Estadisticas(
      testsCompletados:     json['testsCompletados'] ?? 0,
      preguntasRespondidas: json['preguntasRespondidas'] ?? 0,
      preguntasCorrectas:   json['preguntasCorrectas'] ?? 0,
      porcentajeAciertos:   (json['porcentajeAciertos'] ?? 0).toDouble(),
      diasConsecutivos:     json['diasConsecutivos'] ?? 0,
      historial: (json['historial'] as List<dynamic>?)
              ?.map((e) => HistorialTest.fromJson(e)).toList() ?? [],
      temasDebiles: (json['temasDebiles'] as List<dynamic>?)
              ?.map((e) => TemaDebil.fromJson(e)).toList() ?? [],
      evolucion30d: (json['evolucion30d'] as List<dynamic>?)
              ?.map((e) => EvolucionDia.fromJson(e)).toList() ?? [],
    );
  }
}

class HistorialTest {
  final int id;
  final String tema;
  final String oposicion;
  final double nota;
  final DateTime fecha;

  HistorialTest({required this.id, required this.tema, required this.oposicion, required this.nota, required this.fecha});

  factory HistorialTest.fromJson(Map<String, dynamic> json) {
    return HistorialTest(
      id:        json['id'],
      tema:      json['tema'] ?? 'Sin tema',
      oposicion: json['oposicion'] ?? '',
      nota:      (json['nota'] ?? 0).toDouble(),
      fecha:     DateTime.parse(json['fecha'] + 'Z').toLocal(),
    );
  }
}

class TemaDebil {
  final String tema;
  final String oposicion;
  final int preguntasIntentadas;
  final int aciertos;
  final double porcentajeAciertos;

  TemaDebil({
    required this.tema,
    required this.oposicion,
    required this.preguntasIntentadas,
    required this.aciertos,
    required this.porcentajeAciertos,
  });

  factory TemaDebil.fromJson(Map<String, dynamic> json) {
    return TemaDebil(
      tema:                 json['tema'] ?? '',
      oposicion:            json['oposicion'] ?? '',
      preguntasIntentadas:  (json['preguntasIntentadas'] as num?)?.toInt() ?? 0,
      aciertos:             (json['aciertos'] as num?)?.toInt() ?? 0,
      porcentajeAciertos:   (json['porcentajeAciertos'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EvolucionDia {
  final String fecha;      // "2026-03-18"
  final int testsRealizados;
  final double porcentajePromedio;

  EvolucionDia({
    required this.fecha,
    required this.testsRealizados,
    required this.porcentajePromedio,
  });

  factory EvolucionDia.fromJson(Map<String, dynamic> json) {
    return EvolucionDia(
      fecha:               json['fecha'] ?? '',
      testsRealizados:     (json['testsRealizados'] as num?)?.toInt() ?? 0,
      porcentajePromedio:  (json['porcentajePromedio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
