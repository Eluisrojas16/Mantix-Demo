import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../data/mantenimientos_db.dart';
import '../utils/fechas.dart';
import 'aire_detalle_page.dart';
import 'registrar_mantenimiento_page.dart';

/// Pantalla "Siguiente mantenimiento": aires ordenados por fecha de próximo servicio.
/// Los aires que aún no tienen un mantenimiento realizado van en una sección aparte.
class ProximosPage extends StatefulWidget {
  const ProximosPage({super.key});

  @override
  State<ProximosPage> createState() => _ProximosPageState();
}

class _ProximosPageState extends State<ProximosPage> {
  late Future<List<Map<String, Object?>>> _futuro =
      BaseDatos.instancia.proximosMantenimientos();

  Future<void> _recargar() async {
    setState(() {
      _futuro = BaseDatos.instancia.proximosMantenimientos();
    });
    await _futuro;
  }

  Future<void> _abrirAire(Map<String, Object?> fila) async {
    final aire = await BaseDatos.instancia.obtenerAire(fila['aire_id'] as int);
    if (!mounted || aire == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AireDetallePage(
          aire: aire,
          nombreCliente: fila['nombre_apellido'] as String,
        ),
      ),
    );
    if (!mounted) return;
    await _recargar();
  }

  Future<void> _registrar() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegistrarMantenimientoPage()),
    );
    if (ok == true && mounted) {
      await _recargar();
    }
  }

  Widget _encabezado(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _tile(Map<String, Object?> f) {
    final siguiente = f['siguiente_mantenimiento'] as String?;
    final ultimo = f['ultimo_mantenimiento'] as String?;
    final etiqueta = f['origen_siguiente'] == 'programado'
        ? 'Visita programada'
        : 'Próximo mantenimiento';
    return ListTile(
      title: Text('${f['nombre_apellido']} · ${f['posicion']}'),
      subtitle: Text(
        '${f['marca'] ?? ''} ${f['modelo'] ?? ''}'.trim() +
            '\n'
                '${siguiente != null ? '$etiqueta: ${formatoFecha(siguiente)}' : 'Último: ${formatoFecha(ultimo)}'}',
      ),
      isThreeLine: true,
      onTap: () => _abrirAire(f),
      trailing: siguiente != null
          ? chipVencimiento(siguiente)
          : const Chip(
              label: Text('Sin primer mantenimiento'),
              backgroundColor: Color(0xFFFFE0B2),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Próximos mantenimientos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrar,
        icon: const Icon(Icons.add),
        label: const Text('Registrar mantenimiento'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error con la base de datos:\n${snap.error}'),
              ),
            );
          }
          final filas = snap.data ?? [];
          if (filas.isEmpty) {
            return const Center(child: Text('No hay aires registrados.'));
          }
          final conFecha =
              filas.where((f) => f['siguiente_mantenimiento'] != null).toList();
          final sinFecha =
              filas.where((f) => f['siguiente_mantenimiento'] == null).toList();

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (conFecha.isNotEmpty) _encabezado('Por fecha de mantenimiento'),
                for (final f in conFecha) ...[
                  _tile(f),
                  const Divider(height: 1),
                ],
                if (sinFecha.isNotEmpty)
                  _encabezado('Sin primer mantenimiento registrado'),
                for (final f in sinFecha) ...[
                  _tile(f),
                  const Divider(height: 1),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
