import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../cache/hive_cache.dart';
import '../models/pregunta.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import 'resultado_test_screen.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

class TestScreen extends StatefulWidget {
  final String testId;
  const TestScreen({super.key, required this.testId});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  List<Pregunta> _preguntas = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentIndex = 0;

  // preguntaId → letra seleccionada ('A','B','C','D')
  final Map<int, String> _respuestas = {};

  // Tiempo de respuesta por pregunta (ms)
  final Map<int, int> _tiempos = {};
  DateTime _tiempoInicioPage = DateTime.now();

  late final AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadTest();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressAnim.dispose();
    super.dispose();
  }

  Future<void> _loadTest() async {
    // 1. Intentar caché Hive primero (offline-first)
    final local = await HiveCache.getTest(widget.testId);
    if (local != null && local.isNotEmpty) {
      if (!mounted) return;
      setState(() { _preguntas = local; _isLoading = false; });
      return;
    }
    // 2. API
    try {
      final tests = await ApiService.getPreguntasSolicitud(int.parse(widget.testId));
      await HiveCache.saveTest(widget.testId, tests);
      if (!mounted) return;
      setState(() { _preguntas = tests; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Error al cargar test: $e', type: ToastType.error);
      context.pop();
    }
  }


  void _seleccionarRespuesta(String letra) {
    HapticFeedback.selectionClick();
    final pregId = _preguntas[_currentIndex].id;
    final elapsed = DateTime.now().difference(_tiempoInicioPage).inMilliseconds;
    setState(() {
      _respuestas[pregId] = letra;
      _tiempos[pregId] = elapsed;
    });
  }

  void _nextPage() {
    if (_currentIndex < _preguntas.length - 1) {
      _tiempoInicioPage = DateTime.now();
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _tiempoInicioPage = DateTime.now();
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _respuestaActualSeleccionada =>
      _respuestas.containsKey(_preguntas[_currentIndex].id);

  Future<void> _finalizarTest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    // Calcular resultado local
    int aciertos = 0;
    for (final p in _preguntas) {
      if (_respuestas[p.id] == p.respuestaCorrecta) aciertos++;
    }
    final fallos = _preguntas.length - aciertos;
    final nota = _preguntas.isEmpty ? 0.0 : (aciertos / _preguntas.length) * 10.0;

    // Enviar al backend — formato correcto para RespuestaEnvioDto
    final conectado = !(await Connectivity().checkConnectivity())
        .contains(ConnectivityResult.none);
    bool guardadoEnBD = false;
    if (conectado) {
      try {
        final lista = _preguntas.map((p) => {
          'preguntaId': p.id,
          'respuestaDada': _respuestas[p.id] ?? 'A',
          'tiempoRespuesta': _tiempos[p.id] ?? 5000,
        }).toList();
        await ApiService.guardarResultado(
          testId: int.parse(widget.testId),
          respuestas: lista,
        );
        guardadoEnBD = true;
      } catch (e) {
        if (mounted) {
          AppToast.show(context,
            'Aviso: resultado no guardado en servidor',
            type: ToastType.warning,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Navegar a pantalla de resultados
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultadoTestScreen(
        preguntas: _preguntas,
        respuestas: _respuestas,
        aciertos: aciertos,
        fallos: fallos,
        nota: nota,
        testId: widget.testId,
        guardadoEnBD: guardadoEnBD,
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _fondo,
        body: Center(child: CircularProgressIndicator(color: _naranja)),
      );
    }
    if (_preguntas.isEmpty) {
      return Scaffold(
        backgroundColor: _fondo,
        appBar: AppBar(backgroundColor: _naranja, foregroundColor: Colors.white,
            title: const Text('Test'), elevation: 0),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.quiz_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No hay preguntas', style: TextStyle(color: Colors.grey.shade500)),
        ])),
      );
    }

    final total = _preguntas.length;
    final progreso = (_currentIndex + 1) / total;
    final respondidas = _respuestas.length;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _naranja,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Pregunta ${_currentIndex + 1} de $total',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$respondidas/$total',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de progreso premium
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            child: LinearProgressIndicator(
              value: progreso,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(_naranja),
              minHeight: 4,
            ),
          ),

          // Indicadores de preguntas respondidas
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(total, (i) {
                final pregId = _preguntas[i].id;
                final respondida = _respuestas.containsKey(pregId);
                final esCurrent = i == _currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _tiempoInicioPage = DateTime.now();
                      _pageController.animateToPage(i,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut);
                    },
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: esCurrent ? _naranja : respondida
                            ? _naranja.withOpacity(0.4) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Preguntas
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemCount: total,
              itemBuilder: (_, i) => _PreguntaPage(
                pregunta: _preguntas[i],
                respuestaSeleccionada: _respuestas[_preguntas[i].id],
                onSeleccionar: _seleccionarRespuesta,
                numero: i + 1,
                total: total,
              ),
            ),
          ),

          // Navegación inferior
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(children: [
                // Anterior
                if (_currentIndex > 0)
                  OutlinedButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _naranja,
                      side: const BorderSide(color: _naranja),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  )
                else
                  const Spacer(),

                const SizedBox(width: 12),

                // Siguiente / Finalizar
                Expanded(
                  child: _currentIndex < total - 1
                      ? ElevatedButton.icon(
                          onPressed: _respuestaActualSeleccionada ? _nextPage : null,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('Siguiente',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _naranja,
                            disabledBackgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 3,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: (_respuestaActualSeleccionada && !_isSubmitting)
                              ? _finalizarTest : null,
                          icon: _isSubmitting
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(_isSubmitting ? 'Guardando...' : 'FINALIZAR',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            disabledBackgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 4,
                          ),
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Página de pregunta ─────────────────────────────────────────────────────
class _PreguntaPage extends StatelessWidget {
  final Pregunta pregunta;
  final String? respuestaSeleccionada;
  final ValueChanged<String> onSeleccionar;
  final int numero;
  final int total;

  const _PreguntaPage({
    required this.pregunta,
    required this.respuestaSeleccionada,
    required this.onSeleccionar,
    required this.numero,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final letras = ['A', 'B', 'C', 'D'];
    final textos = [
      pregunta.opcionA,
      pregunta.opcionB,
      pregunta.opcionC,
      pregunta.opcionD,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Enunciado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06), blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _naranja.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$numero / $total',
                  style: const TextStyle(
                      fontSize: 12, color: _naranja, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            Text(
              pregunta.textoPregunta,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  height: 1.5, color: Colors.black87),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Opciones
        for (int i = 0; i < letras.length; i++)
          _OpcionBtn(
            letra: letras[i],
            texto: textos[i],
            seleccionada: respuestaSeleccionada == letras[i],
            onTap: () => onSeleccionar(letras[i]),
          ),
      ]),
    );
  }
}

// ── Botón de opción ────────────────────────────────────────────────────────
class _OpcionBtn extends StatelessWidget {
  final String letra;
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionBtn({
    required this.letra,
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionada ? const Color(0xFFFFF3E0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? _naranja : Colors.grey.shade200,
            width: seleccionada ? 2 : 1,
          ),
          boxShadow: seleccionada
              ? [BoxShadow(color: _naranja.withOpacity(0.15),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 4)],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: seleccionada ? _naranja : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(letra,
                  style: TextStyle(
                    color: seleccionada ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                  color: seleccionada ? _naranjaOsc : Colors.black87,
                  fontWeight: seleccionada ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15, height: 1.4,
                )),
          ),
          if (seleccionada)
            const Icon(Icons.check_circle_rounded, color: _naranja, size: 20),
        ]),
      ),
    );
  }
}
