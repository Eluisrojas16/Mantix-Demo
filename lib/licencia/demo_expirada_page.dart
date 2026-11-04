import 'package:flutter/material.dart';

/// Pantalla que bloquea toda la app cuando la demo está vencida.
/// No se puede saltar: está antes del login en main.dart.
class DemoExpiradaPage extends StatelessWidget {
  const DemoExpiradaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Demo expirada',
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gracias por probar Mantix. Esta es la versión de '
                      'demostración y ya cumplió su tiempo de uso (1 hora).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Text(
                        'Para seguir usando el sistema en tu negocio, '
                        'comunicate con tu proveedor para obtener la '
                        'versión completa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontSize: 13,
                        ),
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
