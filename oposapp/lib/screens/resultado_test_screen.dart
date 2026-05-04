import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/pregunta.dart';

const _naranja    = Color(0xFFFF6B00);
const _naranjaOsc = Color(0xFFE55A00);
const _fondo      = Color(0xFFF5F5F5);

class ResultadoTestScreen extends StatelessWidget {
  final List<Pregunta> preguntas;
  final Map<int, String> respuestas; // preguntaId → letra
  final int aciertos;
  final int fallos;
  final double nota;
  final String testId;
  final bool guardadoEnBD;

  const ResultadoTestScreen({
    super.key,
    required this.preguntas,
    required this.respuestas,
    required this.aciertos,
    required this.fallos,
    required this.nota,
    required this.testId,
    this.guardadoEnBD = false,
  });

  Color get _notaColor {
    if (nota >= 7) return const Color(0xFF2E7D32);
    if (nota >= 5) return const Color(0xFFE65100);
    return const Color(0xFFB00020);
  }

  IconData get _notaIcon {
    if (nota >= 7) return Icons.celebration_rounded;
    if (nota >= 5) return Icons.sentiment_neutral_rounded;
    return Icons.sentiment_dissatisfied_rounded;
  }

  String get _notaMensaje {
    if (nota >= 9) return '¡Excelente! Dominas el tema';
    if (nota >= 7) return '¡Muy bien! Sigue así';
    if (nota >= 5) return 'Aprobado. Puedes mejorar';
    return 'A repasar este tema';
  }


  @override
  Widget build(BuildContext context) {
    final porcentaje = preguntas.isEmpty ? 0.0 : aciertos / preguntas.length * 100;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _notaColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Resultado', style: TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () { HapticFeedback.lightImpact(); context.go('/home'); },
            child: const Text('Salir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Hero nota ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: BoxDecoration(
              color: _notaColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(children: [
              Icon(_notaIcon, size: 64, color: Colors.white),
              const SizedBox(height: 12),
              Text(_notaMensaje,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 16),
              Text(nota.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
              Text('sobre 10', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
            ]),
          ),

          // ── KPIs ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Row(children: [
              _KpiCard(icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32),
                  label: 'Aciertos', value: '$aciertos'),
              const SizedBox(width: 10),
              _KpiCard(icon: Icons.cancel_rounded, color: const Color(0xFFB00020),
                  label: 'Fallos', value: '$fallos'),
              const SizedBox(width: 10),
              _KpiCard(icon: Icons.percent_rounded, color: _naranja,
                  label: 'Acierto', value: '${porcentaje.toStringAsFixed(0)}%'),
            ]),
          ),

          // ── Indicador sincronización ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: guardadoEnBD
                    ? const Color(0xFFF1F8E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: guardadoEnBD
                      ? const Color(0xFF2E7D32) : Colors.orange.shade400,
                ),
              ),
              child: Row(children: [
                Icon(
                  guardadoEnBD ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  size: 18,
                  color: guardadoEnBD ? const Color(0xFF2E7D32) : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  guardadoEnBD
                      ? 'Resultado guardado · Progreso actualizado'
                      : 'Resultado calculado localmente (sin conexión)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: guardadoEnBD
                        ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _RespuestasSheet(
                      preguntas: preguntas, respuestas: respuestas),
                );
              },
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Ver respuestas detalladas',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _naranja,
                side: const BorderSide(color: _naranja, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Volver al inicio ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: ElevatedButton.icon(
              onPressed: () { HapticFeedback.heavyImpact(); context.go('/home'); },
              icon: const Icon(Icons.home_rounded),
              label: const Text('Volver al inicio',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _naranja,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size.fromHeight(54),
                elevation: 4,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}


// ── KPI Card ──────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String label; final String value;
  const _KpiCard({required this.icon, required this.color,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    ),
  );
}

// ── Sheet respuestas detalladas ───────────────────────────────────────────
class _RespuestasSheet extends StatelessWidget {
  final List<Pregunta> preguntas;
  final Map<int, String> respuestas;
  const _RespuestasSheet({required this.preguntas, required this.respuestas});

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.88,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Respuestas Detalladas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      const Divider(height: 24),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: preguntas.length,
          itemBuilder: (_, i) {
            final p = preguntas[i];
            final usr = respuestas[p.id] ?? '—';
            final ok = p.respuestaCorrecta == usr;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ok ? const Color(0xFFF1F8E9) : const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ok ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
                  width: 1,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: ok ? const Color(0xFF2E7D32) : const Color(0xFFB00020), size: 20),
                  const SizedBox(width: 8),
                  Text('Pregunta ${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ok ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
                      )),
                ]),
                const SizedBox(height: 8),
                Text(p.textoPregunta,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  _RespuestaChip(letra: usr,
                      color: ok ? const Color(0xFF2E7D32) : const Color(0xFFB00020),
                      label: 'Tu respuesta'),
                  if (!ok) ...[
                    const SizedBox(width: 8),
                    _RespuestaChip(letra: p.respuestaCorrecta,
                        color: const Color(0xFF2E7D32), label: 'Correcta'),
                  ],
                ]),
                if (p.explicacion != null && p.explicacion!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(p.explicacion!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
                ],
              ]),
            );
          },
        ),
      ),
    ]),
  );
}

class _RespuestaChip extends StatelessWidget {
  final String letra; final Color color; final String label;
  const _RespuestaChip({required this.letra, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text('$label: $letra',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}
