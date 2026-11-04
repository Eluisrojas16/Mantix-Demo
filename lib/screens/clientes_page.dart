import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../models/cliente.dart';
import 'cliente_detalle_page.dart';
import 'cliente_form_page.dart';

/// Lista de clientes con buscador, crear, editar y eliminar.
class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _busqueda = TextEditingController();
  late Future<List<Cliente>> _futuro = BaseDatos.instancia.listarClientes();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarClientes(_busqueda.text);
    });
  }

  Future<void> _abrirFormulario([Cliente? cliente]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteFormPage(cliente: cliente)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _abrirDetalle(Cliente cliente) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ClienteDetallePage(cliente: cliente)),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _confirmarEliminar(Cliente c) async {
    final aires = await BaseDatos.instancia.contarAires(c.id!);
    if (!mounted) return;
    final mensaje = aires == 0
        ? '¿Eliminar a ${c.nombreApellido}?'
        : '¿Eliminar a ${c.nombreApellido}? También se borrarán sus $aires '
            'aires y todo su historial de mantenimientos.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await BaseDatos.instancia.eliminarCliente(c.id!);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('FOREIGN KEY')
                  ? 'No se puede eliminar: tiene cotizaciones registradas.'
                  : 'No se pudo eliminar: $e',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => _recargar(),
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
                  return const Center(child: Text('No hay clientes.'));
                }
                return ListView.separated(
                  itemCount: clientes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = clientes[i];
                    final detalle = [
                      if (c.telefono != null) c.telefono!,
                      if (c.esEmpresa && c.rnc != null)
                        'RNC ${c.rnc}'
                      else if (!c.esEmpresa && c.cedula != null)
                        'Cédula ${c.cedula}',
                    ].join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        child: c.esEmpresa
                            ? const Icon(Icons.business)
                            : Text(c.nombreApellido[0].toUpperCase()),
                      ),
                      title: Text(c.nombreApellido),
                      subtitle: detalle.isEmpty ? null : Text(detalle),
                      onTap: () => _abrirDetalle(c),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) {
                          if (op == 'editar') _abrirFormulario(c);
                          if (op == 'eliminar') _confirmarEliminar(c);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'editar', child: Text('Editar')),
                          PopupMenuItem(
                              value: 'eliminar', child: Text('Eliminar')),
                        ],
                      ),
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
