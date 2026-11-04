import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../data/buscar_db.dart';
import 'cliente_detalle_page.dart';
import 'cliente_form_page.dart';
import 'elegir_aire_page.dart';

/// Atajo: buscar un cliente (o el lugar de uno de sus aires), elegir el aire y
/// registrarle un mantenimiento. Cada cliente aparece una sola vez.
class RegistrarMantenimientoPage extends StatefulWidget {
  const RegistrarMantenimientoPage({super.key});

  @override
  State<RegistrarMantenimientoPage> createState() =>
      _RegistrarMantenimientoPageState();
}

class _RegistrarMantenimientoPageState
    extends State<RegistrarMantenimientoPage> {
  final _busqueda = TextEditingController();
  late Future<List<Map<String, Object?>>> _futuro =
      BaseDatos.instancia.buscarClientes();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _futuro = BaseDatos.instancia.buscarClientes(_busqueda.text);
    });
  }

  Future<void> _abrirCliente(Map<String, Object?> f) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ElegirAirePage(
          clienteId: f['cliente_id'] as int,
          nombreCliente: f['nombre_apellido'] as String,
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      Navigator.pop(context, true);
    } else {
      _buscar(); // por si se agregó un aire y cambió la cantidad
    }
  }

  /// Crea un cliente y abre su ficha para agregarle sus aires.
  Future<void> _nuevoCliente() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ClienteFormPage()),
    );
    if (ok != true || !mounted) return;
    final c = await BaseDatos.instancia.ultimoCliente();
    if (c == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ClienteDetallePage(cliente: c)),
    );
    if (!mounted) return;
    _buscar();
  }

  String _textoAires(int n) =>
      n == 0 ? 'Sin aires' : (n == 1 ? '1 aire' : '$n aires');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar mantenimiento'),
        actions: [
          TextButton.icon(
            onPressed: _nuevoCliente,
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo cliente'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _busqueda,
              autofocus: true,
              onChanged: (_) => _buscar(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, cédula/RNC, teléfono o lugar del aire',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final filas = snap.data ?? [];
                if (filas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No se encontró ningún cliente.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: _nuevoCliente,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Crear cliente nuevo'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: filas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = filas[i];
                    final nombre = f['nombre_apellido'] as String;
                    final tel = f['telefono'] as String?;
                    final n = (f['num_aires'] as int?) ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(nombre[0].toUpperCase()),
                      ),
                      title: Text(nombre),
                      subtitle: Text(
                        [if (tel != null) tel, _textoAires(n)].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrirCliente(f),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
