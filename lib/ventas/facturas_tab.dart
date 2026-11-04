import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'factura_detalle_page.dart';
import 'factura_form_page.dart';
import 'factura_modelos.dart';
import 'facturas_db.dart';
import 'modelos.dart';
import 'seleccionar_cotizacion_page.dart';

/// Pestaña "Facturas" de Ventas: lista, buscador, filtro y creación.
class FacturasTab extends StatefulWidget {
  const FacturasTab({super.key});

  @override
  State<FacturasTab> createState() => _FacturasTabState();
}

class _FacturasTabState extends State<FacturasTab> {
  final _busqueda = TextEditingController();
  String? _estado;
  late Future<List<Factura>> _futuro = _cargar();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<List<Factura>> _cargar() => BaseDatos.instancia.listarFacturas(
        filtro: _busqueda.text,
        estado: _estado,
      );

  void _recargar() {
    setState(() {
      _futuro = _cargar();
    });
  }

  Future<void> _nueva() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Factura nueva'),
              subtitle: const Text('Desde cero, eligiendo cliente y artículos'),
              onTap: () => Navigator.pop(ctx, 'nueva'),
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined),
              title: const Text('Desde una cotización'),
              subtitle: const Text('Usa los datos de una cotización ya hecha'),
              onTap: () => Navigator.pop(ctx, 'cotizacion'),
            ),
          ],
        ),
      ),
    );
    if (opcion == null || !mounted) return;

    Cotizacion? cotizacion;
    if (opcion == 'cotizacion') {
      cotizacion = await Navigator.of(context).push<Cotizacion>(
        MaterialPageRoute(builder: (_) => const SeleccionarCotizacionPage()),
      );
      if (cotizacion == null || !mounted) return;
    }
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => FacturaFormPage(cotizacion: cotizacion)),
    );
    if (id == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FacturaDetallePage(facturaId: id)),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _abrir(Factura f) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FacturaDetallePage(facturaId: f.id!)),
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
        label: const Text('Nueva factura'),
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
                hintText: 'Buscar por cliente, número (FAC-0001) o NCF',
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
                for (final e in estadosFactura.entries)
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
            child: FutureBuilder<List<Factura>>(
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
                        'No hay facturas. Toca "Nueva factura" para emitir la primera.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = lista[i];
                    return ListTile(
                      title: Text('${f.numero} · ${f.clienteNombre}'),
                      subtitle: Text(
                        [
                          f.esCredito
                              ? 'Crédito (${f.cantidadCuotas} cuotas)'
                              : 'Contado',
                          f.saldada
                              ? 'Saldada'
                              : (estadosFactura[f.estado] ?? f.estado),
                          if (f.esCredito && !f.saldada)
                            'Pendiente: ${formatoMoneda(f.saldoPendiente)}',
                          if (f.ncf != null) 'NCF ${f.ncf}',
                          'Fecha ${formatoFecha(f.fecha)}',
                        ].join(' · '),
                      ),
                      trailing: Text(
                        formatoMoneda(f.total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              f.anulada ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      onTap: () => _abrir(f),
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
