import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../models/cliente.dart';

/// Lista con buscador para elegir el cliente de un documento. Devuelve el Cliente.
class SeleccionarClientePage extends StatefulWidget {
  const SeleccionarClientePage({super.key});

  @override
  State<SeleccionarClientePage> createState() => _SeleccionarClientePageState();
}

class _SeleccionarClientePageState extends State<SeleccionarClientePage> {
  final _busqueda = TextEditingController();
  late Future<List<Cliente>> _futuro = BaseDatos.instancia.listarClientes();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarClientes(_busqueda.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir cliente')),
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
                hintText: 'Buscar por nombre, cédula/RNC o teléfono',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Cliente>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final clientes = snap.data ?? [];
                if (clientes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No se encontró ningún cliente. Créalo primero en la sección Clientes.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: clientes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = clientes[i];
                    final detalle = [
                      if (c.esEmpresa && c.rnc != null) 'RNC ${c.rnc}',
                      if (!c.esEmpresa && c.cedula != null) 'Cédula ${c.cedula}',
                      if (c.telefono != null) c.telefono!,
                    ].join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        child: c.esEmpresa
                            ? const Icon(Icons.business)
                            : Text(c.nombreApellido[0].toUpperCase()),
                      ),
                      title: Text(c.nombreApellido),
                      subtitle: detalle.isEmpty ? null : Text(detalle),
                      onTap: () => Navigator.pop(context, c),
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
