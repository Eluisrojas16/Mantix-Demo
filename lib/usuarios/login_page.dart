import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../licencia/licencia_demo.dart';
import 'usuario_modelos.dart';
import 'usuarios_db.dart';

class LoginPage extends StatefulWidget {
  final EstadoDemo? estadoDemo;
  const LoginPage({super.key, this.estadoDemo});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final usuario = _usuarioCtrl.text.trim();
    final clave = _claveCtrl.text.trim();
    if (usuario.isEmpty || clave.isEmpty) {
      setState(() => _error = 'Ingresa usuario y contraseña.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final u = await BaseDatos.instancia.autenticar(usuario, clave);
      if (!mounted) return;
      if (u == null) {
        setState(() {
          _error = 'Usuario o contraseña incorrectos.';
          _cargando = false;
        });
        return;
      }

      Sesion.instancia.iniciar(u);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tema.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mantix DEMO',
                      style: tema.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versión de prueba · 1 hora',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (widget.estadoDemo != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'Quedan ${widget.estadoDemo!.minutosRestantes} '
                          'min · vence el ${widget.estadoDemo!.expiraEl}',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                    color: Colors.red.shade900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _usuarioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _claveCtrl,
                      obscureText: _ocultarClave,
                      decoration: InputDecoration(
                        labelText: 'Contraseña / PIN',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarClave
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarClave = !_ocultarClave),
                        ),
                      ),
                      onSubmitted: (_) => _entrar(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _cargando ? null : _entrar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_cargando ? 'Accediendo...' : 'Iniciar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
