import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import 'usuario_modelos.dart';
import 'usuarios_db.dart';

/// Pide la contraseña actual y la nueva (con repetición) y la actualiza.
class CambiarPasswordPage extends StatefulWidget {
  final Usuario usuario;
  const CambiarPasswordPage({super.key, required this.usuario});

  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage> {
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();
  bool _ocultar = true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _repetirCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final actual = _actualCtrl.text.trim();
    final nueva = _nuevaCtrl.text.trim();
    final repetir = _repetirCtrl.text.trim();
    if (actual.isEmpty || nueva.isEmpty) {
      setState(() => _error = 'Llena la contraseña actual y la nueva.');
      return;
    }
    if (repetir != nueva) {
      setState(() => _error = 'La nueva contraseña y su repetición no son iguales.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final e = await BaseDatos.instancia
          .cambiarClave(widget.usuario.id!, actual, nueva);
      if (!mounted) return;
      if (e != null) {
        setState(() {
          _error = e;
          _guardando = false;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo guardar: $err';
        _guardando = false;
      });
    }
  }

  InputDecoration _campo(IconData icono, String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      prefixIcon: Icon(icono),
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        icon: Icon(
          _ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _ocultar = !_ocultar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
      ),
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
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(
                        Icons.lock_reset,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Para ${widget.usuario.nombre}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),

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
                      controller: _actualCtrl,
                      obscureText: _ocultar,
                      autofocus: true,
                      decoration: _campo(
                        Icons.lock_outline,
                        'Contraseña actual',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nuevaCtrl,
                      obscureText: _ocultar,
                      decoration:
                          _campo(Icons.key, 'Nueva contraseña'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _repetirCtrl,
                      obscureText: _ocultar,
                      decoration: _campo(
                        Icons.repeat,
                        'Repetir nueva contraseña',
                      ),
                      onSubmitted: (_) => _guardar(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label:
                            Text(_guardando ? 'Guardando...' : 'Guardar'),
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
