import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'cotizacion_detalle_page.dart';
import 'cotizacion_form_page.dart';
import 'modelos.dart';
import 'ventas_db.dart';

/// Pestaña "Cotizaciones" de Ventas: lista, buscador, filtro y creación.
class CotizacionesTab extends StatefulWidget {
  const CotizacionesTab({super.key});

  @override
  State<CotizacionesTab> createState() => _CotizacionesTabState();
}

class _CotizacionesTabState extends State<CotizacionesTab> {
  final _busqueda = TextEditingController();
  String? _estado;
  late Future<List<Cotizacion>> _futuro = _cargar();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<List<Cotizacion>> _cargar() => BaseDatos.instancia.listarCotizaciones(
        filtro: _busqueda.text,
        estado: _estado,
      );

  void _recargar() {
    setState(() {
      _futuro = _cargar();
    });
  }

  Future<void> _nueva() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const CotizacionFormPage()),
    );
    if (id == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CotizacionDetallePage(cotizacionId: id),
      ),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _abrir(Cotizacion c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CotizacionDetallePage(cotizacionId: c.id!),
      ),
    );
    if (!mounted) return;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cotización'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => _recargar(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por cliente o número (COT-0001)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in estadosCotizacion.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _estado == e.key,
                        onSelected: (s) {
                          _estado = s ? e.key : null;
                          _recargar();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Cotizacion>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final lista = snap.data ?? [];
                if (lista.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay cotizaciones. Toca "Nueva cotización" para crear la primera.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return ListTile(
                      title: Text('${c.numero} · ${c.clienteNombre ?? ''}'),
                      subtitle: Text(
                        [
                          estadosCotizacion[c.estado] ?? c.estado,
                          if (c.vencida) 'Vencida',
                          'Fecha ${formatoFecha(c.fecha)}',
                        ].join(' · '),
                      ),
                      trailing: Text(
                        formatoMoneda(c.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => _abrir(c),
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
