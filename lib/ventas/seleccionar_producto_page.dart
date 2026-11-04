import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../inventario/inventario_db.dart';
import '../inventario/modelos.dart' show ProductoConStock, clasesProducto;
import '../inventario/widgets.dart';
import '../utils/numeros.dart';

/// Lista con buscador para elegir un artículo del inventario. Devuelve el ProductoConStock.
class SeleccionarProductoPage extends StatefulWidget {
  const SeleccionarProductoPage({super.key});

  @override
  State<SeleccionarProductoPage> createState() =>
      _SeleccionarProductoPageState();
}

class _SeleccionarProductoPageState extends State<SeleccionarProductoPage> {
  final _busqueda = TextEditingController();
  late Future<List<ProductoConStock>> _futuro =
      BaseDatos.instancia.listarProductos();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarProductos(filtro: _busqueda.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir artículo del inventario')),
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
                hintText: 'Buscar por nombre, código, marca, modelo o parte',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ProductoConStock>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay artículos. Para un servicio o mano de obra, '
                        'usa "Agregar concepto".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final p = item.producto;
                    final detalle = [
                      [p.marcaNombre, p.modeloNombre]
                          .whereType<String>()
                          .join(' '),
                      if (p.clase != 'producto') clasesProducto[p.clase] ?? p.clase,
                      if (p.precioVenta != null) formatoMoneda(p.precioVenta),
                    ].where((s) => s.isNotEmpty).join(' · ');
                    return ListTile(
                      title: Text(p.nombre),
                      subtitle: detalle.isEmpty ? null : Text(detalle),
                      trailing: p.controlaExistencia
                          ? Text(
                              '${formatoCantidad(item.stock)} ${p.unidad}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorEstadoStock(item.estado),
                              ),
                            )
                          : const Text('Sin control'),
                      onTap: () => Navigator.pop(context, item),
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
