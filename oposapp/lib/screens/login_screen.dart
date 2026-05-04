import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class LoginScreen extends StatefulWidget {
  /// Si true, abre directamente en modo registro (ruta /register)
  final bool modoRegistroInicial;
  const LoginScreen({super.key, this.modoRegistroInicial = false});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nombreController = TextEditingController();

  bool _isLoading = false;
  late bool _isRegistro;  // se inicializa en initState segun widget.modoRegistroInicial
  bool _rgpdAceptado = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Paleta OposApp
  static const _naranja = Color(0xFFFF6B00);
  static const _naranjaOscuro = Color(0xFFE55A00);
  static const _fondo = Color(0xFFF5F5F5);
  static const _superficie = Colors.white;

  @override
  void initState() {
    super.initState();
    // Inicializar modo segun el parametro de la ruta
    _isRegistro = widget.modoRegistroInicial;
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  void _toggleModo() {
    _fadeController.reset();
    _slideController.reset();
    setState(() {
      _isRegistro = !_isRegistro;
      _rgpdAceptado = false;
      _confirmPasswordController.clear();
      _obscureConfirm = true;
    });
    _fadeController.forward();
    _slideController.forward();
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRegistro && !_rgpdAceptado) {
      _showSnack('Debes aceptar la política de privacidad', isError: false, icon: Icons.shield_outlined);
      return;
    }
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> response;
      if (_isRegistro) {
        response = await ApiService.registro(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nombre: _nombreController.text.trim(),
          rgpdAceptado: _rgpdAceptado,
        );
        _showSnack('¡Cuenta creada! Revisa tu email para verificarla 📧',
            isError: false, icon: Icons.check_circle_outline);
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        response = await ApiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      final rolStr = response['rol'] ?? 'USER';
      await AuthService.saveSession(
        token: response['token'],
        usuario: Usuario.fromJson(response),
        rol: rolStr,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        // 423 = cuenta bloqueada por brute force → icono candado
        final msg = e.toString();
        final esBloqueada = msg.contains('bloqueada') || msg.contains('423');
        _showSnack(
          msg,
          isError: true,
          icon: esBloqueada ? Icons.lock_outline_rounded : Icons.error_outline,
          duracion: esBloqueada ? 6 : 4,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError, required IconData icon, int duracion = 4}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: isError ? const Color(0xFFB00020) : const Color(0xFF2E7D32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
        ]),
        duration: Duration(seconds: duracion),
      ),
    );
  }


  InputDecoration _inputDeco(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _naranja),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFFF3E0),
        labelStyle: const TextStyle(color: Colors.black54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFCC80), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _naranja, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB00020), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── HERO SUPERIOR naranja ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                decoration: const BoxDecoration(
                  color: _naranja,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded,
                        size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text('OposApp',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    _isRegistro
                        ? 'Crea tu cuenta y empieza hoy'
                        : 'Prepara tus oposiciones con IA',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w400),
                  ),
                ]),
              ),


              // ── FORMULARIO con animación ───────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // Nombre (solo registro)
                          if (_isRegistro) ...[
                            TextFormField(
                              controller: _nombreController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDeco('Nombre', Icons.person_rounded),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Introduce tu nombre' : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDeco('Email', Icons.email_rounded),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Introduce tu email';
                              if (!v.contains('@') || !v.contains('.'))
                                return 'Email inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Contraseña con toggle visibilidad
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDeco(
                              'Contraseña',
                              Icons.lock_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _naranja,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Introduce tu contraseña';
                              if (v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirmar contraseña (solo registro)
                          if (_isRegistro) ...[
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: _inputDeco(
                                'Confirmar contraseña',
                                Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _naranja,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                                if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                          ],


                          // RGPD checkbox (solo registro)
                          if (_isRegistro) ...[
                            GestureDetector(
                              onTap: () => setState(() => _rgpdAceptado = !_rgpdAceptado),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _rgpdAceptado
                                      ? const Color(0xFFFFF3E0)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _rgpdAceptado
                                        ? _naranja
                                        : const Color(0xFFE0E0E0),
                                    width: _rgpdAceptado ? 2 : 1,
                                  ),
                                ),
                                child: Row(children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _rgpdAceptado
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      key: ValueKey(_rgpdAceptado),
                                      color: _rgpdAceptado
                                          ? _naranja
                                          : Colors.grey.shade400,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.black87),
                                        children: [
                                          const TextSpan(text: 'He leído y acepto la '),
                                          TextSpan(
                                            text: 'Política de Privacidad',
                                            style: const TextStyle(
                                                color: _naranja,
                                                decoration: TextDecoration.underline,
                                                fontWeight: FontWeight.w600),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () => _mostrarPrivacidad(),
                                          ),
                                          const TextSpan(text: ' (RGPD)'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],


                          // ── BOTÓN PRINCIPAL ──────────────────────
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _naranja,
                                disabledBackgroundColor: _naranja.withOpacity(0.5),
                                foregroundColor: Colors.white,
                                elevation: _isLoading ? 0 : 4,
                                shadowColor: _naranja.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Text(
                                        _isRegistro ? '🚀  Crear cuenta' : '▶  Iniciar sesión',
                                        key: ValueKey(_isRegistro),
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── TOGGLE login/registro ─────────────────
                          Center(
                            child: TextButton(
                              onPressed: _toggleModo,
                              style: TextButton.styleFrom(
                                foregroundColor: _naranja,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: Text(
                                _isRegistro
                                    ? '¿Ya tienes cuenta?  Inicia sesión →'
                                    : '¿No tienes cuenta?  Regístrate gratis →',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _mostrarPrivacidad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_outlined, color: _naranja),
            ),
            const SizedBox(width: 12),
            const Text('Política de Privacidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          const Text(
            'OposApp recoge tu email, nombre y actividad de estudio '
            'con el único fin de personalizar tu experiencia.\n\n'
            '🔒  Tus datos se almacenan en servidores propios (NAS Synology) '
            'situados en la UE y nunca se comparten con terceros.\n\n'
            '✏️  Puedes ejercer tu derecho de acceso, rectificación, '
            'portabilidad y supresión desde tu perfil en cualquier momento.',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _rgpdAceptado = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _naranja,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Entendido y acepto',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
