import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../models/aire.dart';
import 'aire_form_page.dart';
import 'mantenimiento_form_page.dart';

/// Segundo paso de "Registrar mantenimiento": elegir cuál aire del cliente.
class ElegirAirePage extends StatefulWidget {
  final int clienteId;
  final String nombreCliente;
  const ElegirAirePage({
    super.key,
    required this.clienteId,
    required this.nombreCliente,
  });

  @override
  State<ElegirAirePage> createState() => _ElegirAirePageState();
}

class _ElegirAirePageState extends State<ElegirAirePage> {
  late Future<List<Aire>> _futuro = _cargar();

  Future<List<Aire>> _cargar() async {
    final todos = await BaseDatos.instancia.listarAires(widget.clienteId);
    return todos.where((a) => a.activo).toList();
  }

  Future<void> _agregarAire() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AireFormPage(clienteId: widget.clienteId),
      ),
    );
    if (guardado == true && mounted) {
      setState(() {
        _futuro = _cargar();
      });
    }
  }

  Future<void> _elegir(Aire a) async {
    final contexto = '${widget.nombreCliente} · ${a.posicion ?? 'Aire'}';
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MantenimientoFormPage(aireId: a.id!, contexto: contexto),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mantenimiento registrado: $contexto')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreCliente),
        actions: [
          IconButton(
            tooltip: 'Agregar aire',
            icon: const Icon(Icons.add),
            onPressed: _agregarAire,
          ),
        ],
      ),
      body: FutureBuilder<List<Aire>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final aires = snap.data ?? [];
          if (aires.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Este cliente no tiene aires activos.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _agregarAire,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar aire'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('¿A cuál aire le registras el mantenimiento?'),
              ),
              for (final a in aires) ...[
                ListTile(
                  leading: const Icon(Icons.ac_unit),
                  title: Text(a.posicion ?? 'Sin posición'),
                  subtitle: Text(
                    [
                      [a.marca, a.modelo].whereType<String>().join(' '),
                      if (a.tipo != null) a.tipo!,
                      if (a.btu != null) '${a.btu} BTU',
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _elegir(a),
                ),
                const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}
