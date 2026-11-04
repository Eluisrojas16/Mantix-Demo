import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../data/mantenimientos_db.dart';
import '../models/aire.dart';
import '../models/mantenimiento.dart';
import '../utils/fechas.dart';
import 'aire_form_page.dart';
import 'mantenimiento_form_page.dart';

class _Datos {
  final List<Mantenimiento> historial;
  final Map<String, Object?>? proximo;
  _Datos(this.historial, this.proximo);
}

/// Ficha de un aire: sus datos, último/siguiente mantenimiento y su historial.
class AireDetallePage extends StatefulWidget {
  final Aire aire;
  final String nombreCliente;
  const AireDetallePage({
    super.key,
    required this.aire,
    required this.nombreCliente,
  });

  @override
  State<AireDetallePage> createState() => _AireDetallePageState();
}

class _AireDetallePageState extends State<AireDetallePage> {
  late Aire _aire = widget.aire;
  late Future<_Datos> _datos = _cargar();

  Future<_Datos> _cargar() async {
    final h = await BaseDatos.instancia.listarMantenimientos(_aire.id!);
    final p = await BaseDatos.instancia.proximoDeAire(_aire.id!);
    return _Datos(h, p);
  }

  Future<void> _recargar() async {
    final a = await BaseDatos.instancia.obtenerAire(_aire.id!);
    if (!mounted) return;
    setState(() {
      if (a != null) _aire = a;
      _datos = _cargar();
    });
  }

  Future<void> _editarAire() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AireFormPage(clienteId: _aire.clienteId, aire: _aire),
      ),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _abrirFormulario([Mantenimiento? m]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MantenimientoFormPage(
              aireId: _aire.id!,
              mantenimiento: m,
              contexto: '${widget.nombreCliente} · ${_aire.posicion ?? 'Aire'}',
            ),
      ),
    );
    if (guardado == true) _recargar();
  }

  /// Abre el formulario con la visita programada ya marcada como realizada.
  /// Si su fecha es futura, propone la de hoy. No se guarda hasta que presiones Guardar.
  Future<void> _marcarRealizado(Mantenimiento m) async {
    final hoy = hoySinHora();
    final fecha = deIso(m.fecha);
    final fechaFinal =
        (fecha != null && fecha.isAfter(hoy)) ? aIso(hoy) : m.fecha;
    await _abrirFormulario(
      Mantenimiento(
        id: m.id,
        aireId: m.aireId,
        fecha: fechaFinal,
        tipo: m.tipo,
        estado: 'realizado',
        trabajoRealizado: m.trabajoRealizado,
        costo: m.costo,
        pagado: m.pagado,
        tecnico: m.tecnico,
      ),
    );
  }

  Future<void> _confirmarEliminar(Mantenimiento m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mantenimiento'),
        content: Text('¿Eliminar el registro del ${formatoFecha(m.fecha)}?'),
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
      await BaseDatos.instancia.eliminarMantenimiento(m.id!);
      if (!mounted) return;
      _recargar();
    }
  }

  IconData _icono(String estado) {
    switch (estado) {
      case 'realizado':
        return Icons.check_circle;
      case 'programado':
        return Icons.schedule;
      default:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _aire;
    final lineas = [
      [a.marca, a.modelo].whereType<String>().join(' '),
      [
        if (a.tipo != null) a.tipo!,
        if (a.btu != null) '${a.btu} BTU',
      ].join(' · '),
      if (a.serial != null) 'Serial ${a.serial}',
      'Mantenimiento cada ${a.periodicidadMeses} meses',
      if (!a.activo) 'Equipo inactivo',
    ].where((s) => s.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(a.posicion ?? 'Aire'),
        actions: [
          IconButton(
            tooltip: 'Editar aire',
            icon: const Icon(Icons.edit),
            onPressed: _editarAire,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Registrar mantenimiento'),
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
                        widget.nombreCliente,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      for (final l in lineas) Text(l),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<_Datos>(
                future: _datos,
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
                  final datos = snap.data!;
                  final ultimo =
                      datos.proximo?['ultimo_mantenimiento'] as String?;
                  final siguiente =
                      datos.proximo?['siguiente_mantenimiento'] as String?;
                  final chip = chipVencimiento(siguiente);
                  final origen =
                      datos.proximo?['origen_siguiente'] as String?;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: !a.activo
                              ? const Text('Equipo inactivo: no se calcula siguiente mantenimiento.')
                              : (ultimo == null && siguiente == null)
                                  ? const Text(
                                      'Aún no hay un mantenimiento realizado. '
                                      'Registra el primero para que empiece el conteo.',
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Último'),
                                              Text(
                                                formatoFecha(ultimo),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                origen == 'programado'
                                                    ? 'Visita programada'
                                                    : 'Siguiente (calculado)',
                                              ),
                                              Text(
                                                formatoFecha(siguiente),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              if (chip != null) chip,
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Historial de mantenimientos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (datos.historial.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Todavía no hay mantenimientos registrados.'),
                          ),
                        ),
                      for (final m in datos.historial)
                        Card(
                          child: ListTile(
                            leading: Icon(_icono(m.estado)),
                            title: Text(
                              '${formatoFecha(m.fecha)} · '
                              '${tiposMantenimiento[m.tipo] ?? m.tipo}'
                              '${m.estado == 'realizado' ? '' : ' (${estadosMantenimiento[m.estado] ?? m.estado})'}',
                            ),
                            subtitle: Text(
                              [
                                if (m.trabajoRealizado != null) m.trabajoRealizado!,
                                if (m.costo != null)
                                  'RD\$ ${m.costo!.toStringAsFixed(2)}'
                                  '${m.pagado ? ' · Pagado' : ' · Pendiente de pago'}',
                                if (m.tecnico != null) 'Técnico: ${m.tecnico}',
                              ].join('\n'),
                            ),
                            isThreeLine: m.trabajoRealizado != null && m.costo != null,
                            onTap: () => _abrirFormulario(m),
                            trailing: PopupMenuButton<String>(
                              onSelected: (op) {
                                if (op == 'realizado') _marcarRealizado(m);
                                if (op == 'editar') _abrirFormulario(m);
                                if (op == 'eliminar') _confirmarEliminar(m);
                              },
                              itemBuilder: (_) => [
                                if (m.estado == 'programado')
                                  const PopupMenuItem(
                                      value: 'realizado',
                                      child: Text('Marcar como realizado')),
                                const PopupMenuItem(
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
