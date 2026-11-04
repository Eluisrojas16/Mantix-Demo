import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'modelos.dart';
import 'ventas_db.dart';

/// Elegir una cotización para facturarla. Solo aparecen las que se pueden facturar
/// (no rechazadas ni ya facturadas). Devuelve la Cotizacion.
class SeleccionarCotizacionPage extends StatefulWidget {
  const SeleccionarCotizacionPage({super.key});

  @override
  State<SeleccionarCotizacionPage> createState() =>
      _SeleccionarCotizacionPageState();
}

class _SeleccionarCotizacionPageState extends State<SeleccionarCotizacionPage> {
  final _busqueda = TextEditingController();
  late Future<List<Cotizacion>> _futuro = _cargar();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<List<Cotizacion>> _cargar() async {
    final todas =
        await BaseDatos.instancia.listarCotizaciones(filtro: _busqueda.text);
    return todas
        .where((c) => c.estado != 'rechazada' && c.estado != 'facturada')
        .toList();
  }

  void _buscar() {
    setState(() {
      _futuro = _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir cotización')),
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
                hintText: 'Buscar por cliente o número (COT-0001)',
                border: OutlineInputBorder(),
              ),
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
                        'No hay cotizaciones pendientes de facturar.',
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
