import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/numeros.dart';
import 'catalogos_db.dart';
import 'catalogos_page.dart';
import 'inventario_db.dart';
import 'modelos.dart';
import 'producto_detalle_page.dart';
import 'producto_form_page.dart';
import 'widgets.dart';

/// Lista general del inventario con buscador y filtros por clase y categoría.
class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final _busqueda = TextEditingController();
  String? _clase;
  int? _categoriaId;
  bool _verInactivos = false;
  late Future<List<ProductoConStock>> _futuro = _cargar();
  late Future<List<ItemCatalogo>> _categorias =
      BaseDatos.instancia.listarCategorias();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<List<ProductoConStock>> _cargar() =>
      BaseDatos.instancia.listarProductos(
        filtro: _busqueda.text,
        categoriaId: _categoriaId,
        clase: _clase,
        soloActivos: !_verInactivos,
      );

  void _recargar() {
    setState(() {
      _futuro = _cargar();
      _categorias = BaseDatos.instancia.listarCategorias();
    });
  }

  Future<void> _nuevoProducto() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductoFormPage()),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _abrirProducto(Producto p) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProductoDetallePage(productoId: p.id!)),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _abrirCatalogos() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CatalogosPage()),
    );
    if (!mounted) return;
    _categoriaId = null; // la categoría elegida pudo haberse eliminado
    _recargar();
  }

  Widget _chip(String texto, bool seleccionado, ValueChanged<bool> alCambiar) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ChoiceChip(
          label: Text(texto),
          selected: seleccionado,
          onSelected: alCambiar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Marcas, modelos y categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: _abrirCatalogos,
          ),
          IconButton(
            tooltip: _verInactivos
                ? 'Ocultar productos inactivos'
                : 'Mostrar productos inactivos',
            icon: Icon(
              _verInactivos ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              _verInactivos = !_verInactivos;
              _recargar();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoProducto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
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
                hintText: 'Buscar por nombre, código, marca, modelo o parte',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FutureBuilder<List<ItemCatalogo>>(
            future: _categorias,
            builder: (context, snap) {
              final categorias = snap.data ?? [];
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final e in clasesProducto.entries)
                      _chip(e.value, _clase == e.key, (s) {
                        _clase = s ? e.key : null;
                        _recargar();
                      }),
                    if (categorias.isNotEmpty)
                      const Center(
                        child: SizedBox(
                          height: 28,
                          child: VerticalDivider(width: 24),
                        ),
                      ),
                    for (final c in categorias)
                      _chip(c.nombre, _categoriaId == c.id, (s) {
                        _categoriaId = s ? c.id : null;
                        _recargar();
                      }),
                  ],
                ),
              );
            },
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
                        'No hay productos. Toca "Nuevo producto" para agregar el primero.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final alertas = items
                    .where((i) => i.estado == 'agotado' || i.estado == 'bajo')
                    .length;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${items.length} productos'
                          '${alertas > 0 ? ' · $alertas con stock bajo o agotado' : ''}'
                          ' · Valor en inventario '
                          '${formatoMoneda(items.fold<double>(0, (s, i) => s + (i.producto.controlaExistencia ? i.stock * (i.producto.costo ?? 0) : 0)))}',
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final p = item.producto;
                          final detalle = [
                            [p.marcaNombre, p.modeloNombre]
                                .whereType<String>()
                                .join(' '),
                            if (p.numeroParte != null) 'Parte ${p.numeroParte}',
                            if (p.codigo != null) 'Cód. ${p.codigo}',
                          ].where((s) => s.isNotEmpty).join(' · ');
                          final estadoTxt = textoEstadoStock(item.estado);
                          return ListTile(
                            title: Text(
                              p.nombre,
                              style: p.activo
                                  ? null
                                  : const TextStyle(color: Colors.grey),
                            ),
                            subtitle: Text(
                              [
                                if (detalle.isNotEmpty) detalle,
                                if (p.clase != 'producto') clasesProducto[p.clase] ?? p.clase,
                                if (p.categoriaNombre != null) p.categoriaNombre!,
                                if (p.usaSerial) 'Con serial',
                                if (estadoTxt != null) estadoTxt,
                                if (!p.activo) 'Inactivo',
                              ].join(' · '),
                            ),
                            trailing: p.controlaExistencia
                                ? Text(
                                    '${formatoCantidad(item.stock)} ${p.unidad}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorEstadoStock(item.estado),
                                    ),
                                  )
                                : null,
                            onTap: () => _abrirProducto(p),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
