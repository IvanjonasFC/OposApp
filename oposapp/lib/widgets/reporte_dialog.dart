import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/percent_indicator.dart';

class ReporteDialog extends StatefulWidget {
  final double nota;
  final String consejo;

  const ReporteDialog({
    super.key,
    required this.nota,
    required this.consejo,
  });

  @override
  State<ReporteDialog> createState() => _ReporteDialogState();
}

class _ReporteDialogState extends State<ReporteDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.nota >= 7.0) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _getNotaColor(double nota) {
    if (nota >= 7) return Colors.green;
    if (nota >= 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final colorNota = _getNotaColor(widget.nota);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Text(
                  '¡Test Completado! 🎉',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                CircularPercentIndicator(
                  radius: 60.0,
                  lineWidth: 12.0,
                  animation: true,
                  percent: widget.nota / 10,
                  center: Text(
                    "${widget.nota.toStringAsFixed(1)}/10",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: colorNota),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: colorNota,
                  backgroundColor: colorNota.withOpacity(0.2),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Consejos IA', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.consejo,
                        style: TextStyle(color: Colors.blue.shade900),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop();
                      // Si tuvieramos vista resumen: context.push('/resumen')
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Ver Respuestas'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      context.pop();
                      context.pushReplacement('/generate');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Nuevo Test'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    context.pop();
                    context.go('/home'); // Navega al inicio (dashboard gral por defecto)
                  },
                  child: const Text('Ir al Dashboard'),
                ),
              ],
            ),
          ),
          
          // Confetti Position
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }
}
