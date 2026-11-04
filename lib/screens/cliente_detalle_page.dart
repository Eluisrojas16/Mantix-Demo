import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../models/aire.dart';
import '../models/cliente.dart';
import 'aire_detalle_page.dart';
import 'aire_form_page.dart';
import 'cliente_form_page.dart';

/// Ficha del cliente: sus datos y la lista de sus aires acondicionados.
class ClienteDetallePage extends StatefulWidget {
  final Cliente cliente;
  const ClienteDetallePage({super.key, required this.cliente});

  @override
  State<ClienteDetallePage> createState() => _ClienteDetallePageState();
}

class _ClienteDetallePageState extends State<ClienteDetallePage> {
  late Cliente _cliente = widget.cliente;
  late Future<List<Aire>> _aires =
      BaseDatos.instancia.listarAires(widget.cliente.id!);

  Future<void> _recargar() async {
    final c = await BaseDatos.instancia.obtenerCliente(_cliente.id!);
    if (!mounted) return;
    setState(() {
      if (c != null) _cliente = c;
      _aires = BaseDatos.instancia.listarAires(_cliente.id!);
    });
  }

  Future<void> _editarCliente() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteFormPage(cliente: _cliente)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _abrirFormularioAire([Aire? aire]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AireFormPage(clienteId: _cliente.id!, aire: aire),
      ),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _abrirAire(Aire aire) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AireDetallePage(
          aire: aire,
          nombreCliente: _cliente.nombreApellido,
        ),
      ),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _confirmarEliminarAire(Aire a) async {
    final historial = await BaseDatos.instancia.contarMantenimientos(a.id!);
    if (!mounted) return;
    final nombre = a.posicion ?? 'este aire';
    final mensaje = historial == 0
        ? '¿Eliminar $nombre?'
        : '¿Eliminar $nombre? También se borrarán sus $historial '
            'mantenimientos registrados.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar aire'),
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
      await BaseDatos.instancia.eliminarAire(a.id!);
      if (!mounted) return;
      _recargar();
    }
  }

  Widget _fila(IconData icono, String? texto) {
    if (texto == null || texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _cliente;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.nombreApellido),
        actions: [
          IconButton(
            tooltip: 'Editar cliente',
            icon: const Icon(Icons.edit),
            onPressed: _editarCliente,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioAire(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar aire'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombreApellido,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _fila(Icons.phone, c.telefono),
                      if (c.esEmpresa) ...[
                        _fila(Icons.business, 'Empresa'),
                        _fila(Icons.badge,
                            c.rnc == null ? null : 'RNC ${c.rnc}'),
                        _fila(Icons.person,
                            c.contacto == null ? null : 'Contacto: ${c.contacto}'),
                      ] else
                        _fila(Icons.badge,
                            c.cedula == null ? null : 'Cédula ${c.cedula}'),
                      _fila(Icons.home, c.direccion),
                      _fila(Icons.notes, c.notas),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aires acondicionados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Aire>>(
                future: _aires,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text('Error: ${snap.error}');
                  }
                  final aires = snap.data ?? [];
                  if (aires.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Este cliente aún no tiene aires registrados.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final a in aires)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.ac_unit,
                              color: a.activo ? null : Colors.grey,
                            ),
                            title: Text(a.posicion ?? 'Sin posición'),
                            subtitle: Text(
                              [
                                [a.marca, a.modelo]
                                    .whereType<String>()
                                    .join(' '),
                                if (a.tipo != null) a.tipo!,
                                if (a.btu != null) '${a.btu} BTU',
                                'cada ${a.periodicidadMeses} meses',
                                if (!a.activo) 'Inactivo',
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            onTap: () => _abrirAire(a),
                            trailing: PopupMenuButton<String>(
                              onSelected: (op) {
                                if (op == 'editar') _abrirFormularioAire(a);
                                if (op == 'eliminar') _confirmarEliminarAire(a);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'editar', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar')),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
