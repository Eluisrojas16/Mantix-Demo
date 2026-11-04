import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'dialogos.dart';
import 'entrada_seriales_page.dart';
import 'inventario_db.dart';
import 'modelos.dart';
import 'movimiento_form_page.dart';
import 'producto_form_page.dart';
import 'salida_seriales_page.dart';
import 'seriales_db.dart';
import 'widgets.dart';

class _Datos {
  final ProductoConStock? producto;
  final List<Movimiento> movimientos;
  final List<Unidad> unidades;
  _Datos(this.producto, this.movimientos, this.unidades);
}

/// Ficha de un producto: sus datos, existencia, unidades por serial y movimientos.
class ProductoDetallePage extends StatefulWidget {
  final int productoId;
  const ProductoDetallePage({super.key, required this.productoId});

  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  late Future<_Datos> _datos = _cargar();
  String? _filtroEstado = 'en_stock'; // en_stock, despachado o null (todas)
  final _busquedaSerial = TextEditingController();

  @override
  void dispose() {
    _busquedaSerial.dispose();
    super.dispose();
  }

  Future<_Datos> _cargar() async {
    final p = await BaseDatos.instancia.obtenerProducto(widget.productoId);
    final m = await BaseDatos.instancia.listarMovimientos(widget.productoId);
    final u = (p != null && p.producto.usaSerial)
        ? await BaseDatos.instancia.listarUnidades(widget.productoId)
        : <Unidad>[];
    return _Datos(p, m, u);
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _editar(Producto p) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductoFormPage(producto: p)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _nuevoMovimiento(ProductoConStock p, String tipo) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MovimientoFormPage(producto: p, tipo: tipo),
      ),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _entradaSeriales(ProductoConStock p) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntradaSerialesPage(producto: p)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _salidaSeriales(ProductoConStock p) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SalidaSerialesPage(producto: p)),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _corregirSerial(Unidad u) async {
    final nuevo = await pedirTexto(
      context,
      titulo: 'Corregir número de serie',
      inicial: u.serial,
      etiqueta: 'Número de serie',
      capitalizar: TextCapitalization.none,
    );
    if (nuevo == null || nuevo == u.serial || !mounted) return;
    try {
      await BaseDatos.instancia.cambiarSerial(u.id, nuevo);
    } catch (e) {
      if (!mounted) return;
      aviso(
        context,
        e is StateError
            ? e.message
            : (e.toString().contains('UNIQUE')
                ? 'Ese serial ya está registrado.'
                : 'No se pudo cambiar: $e'),
      );
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _confirmarEliminar(Movimiento m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(
          '¿Eliminar el movimiento del ${formatoFecha(m.fecha)}? '
          'La existencia se recalculará.',
        ),
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
      await BaseDatos.instancia.eliminarMovimiento(m.id!);
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

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'entrada':
        return Icons.add_circle_outline;
      case 'salida':
        return Icons.remove_circle_outline;
      default:
        return Icons.tune;
    }
  }

  /// Sección con los números de serie del producto.
  List<Widget> _seccionUnidades(List<Unidad> unidades) {
    final enStock = unidades.where((u) => u.enStock).length;
    final despachadas = unidades.length - enStock;
    final q = _busquedaSerial.text.trim().toLowerCase();
    final visibles = unidades
        .where((u) =>
            (_filtroEstado == null || u.estado == _filtroEstado) &&
            (q.isEmpty || u.serial.toLowerCase().contains(q)))
        .toList();
    return [
      const SizedBox(height: 24),
      Text(
        'Unidades por número de serie',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text('En existencia ($enStock)'),
            selected: _filtroEstado == 'en_stock',
            onSelected: (_) => setState(() => _filtroEstado = 'en_stock'),
          ),
          ChoiceChip(
            label: Text('Despachadas ($despachadas)'),
            selected: _filtroEstado == 'despachado',
            onSelected: (_) => setState(() => _filtroEstado = 'despachado'),
          ),
          ChoiceChip(
            label: Text('Todas (${unidades.length})'),
            selected: _filtroEstado == null,
            onSelected: (_) => setState(() => _filtroEstado = null),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _busquedaSerial,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Buscar serial',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      if (visibles.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No hay seriales con ese filtro.')),
        ),
      for (final u in visibles)
        Card(
          child: ListTile(
            leading: Icon(
              u.enStock
                  ? Icons.inventory_2_outlined
                  : Icons.local_shipping_outlined,
            ),
            title: Text(
              u.serial,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                'Entrada ${formatoFecha(u.fechaEntrada)}',
                if (!u.enStock)
                  'Salida ${formatoFecha(u.fechaSalida)} · '
                      '${etiquetaOrigen(u.origenSalida ?? '')}'
                      '${u.referenciaSalida != null ? ' · ${u.referenciaSalida}' : ''}',
              ].join('\n'),
            ),
            isThreeLine: !u.enStock,
            trailing: u.enStock
                ? IconButton(
                    tooltip: 'Corregir serial',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _corregirSerial(u),
                  )
                : null,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Datos>(
      future: _datos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        final datos = snap.data!;
        final item = datos.producto;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Este producto ya no existe.')),
          );
        }
        final p = item.producto;
        final estadoTxt = textoEstadoStock(item.estado);

        return Scaffold(
          appBar: AppBar(
            title: Text(p.nombre),
            actions: [
              IconButton(
                tooltip: 'Editar producto',
                icon: const Icon(Icons.edit),
                onPressed: () => _editar(p),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          _fila(Icons.label_outline,
                              clasesProducto[p.clase] ?? p.clase),
                          _fila(Icons.category, p.categoriaNombre),
                          _fila(
                            Icons.sell,
                            [p.marcaNombre, p.modeloNombre]
                                .whereType<String>()
                                .join(' '),
                          ),
                          _fila(Icons.tag,
                              p.codigo == null ? null : 'Código ${p.codigo}'),
                          _fila(
                              Icons.settings,
                              p.numeroParte == null
                                  ? null
                                  : 'Parte ${p.numeroParte}'),
                          _fila(Icons.notes, p.descripcion),
                          _fila(Icons.payments,
                              'Costo ${formatoMoneda(p.costo)} · Precio ${formatoMoneda(p.precioVenta)}'),
                          if (p.usaSerial)
                            _fila(Icons.pin_outlined,
                                'Se controla por número de serie'),
                          if (!p.activo) _fila(Icons.block, 'Producto inactivo'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!p.controlaExistencia)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Es un misceláneo: no controla existencia. '
                          'Se puede facturar sin inventario.',
                        ),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Existencia'),
                            Text(
                              '${formatoCantidad(item.stock)} ${p.unidad}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: colorEstadoStock(item.estado),
                                  ),
                            ),
                            if (estadoTxt != null)
                              Text(
                                estadoTxt,
                                style: TextStyle(
                                  color: colorEstadoStock(item.estado),
                                ),
                              ),
                            if (p.stockMinimo > 0)
                              Text(
                                'Mínimo: ${formatoCantidad(p.stockMinimo)} ${p.unidad}',
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (p.usaSerial)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _entradaSeriales(item),
                            icon: const Icon(Icons.add),
                            label: const Text('Entrada de seriales'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: item.stock > 0
                                ? () => _salidaSeriales(item)
                                : null,
                            icon: const Icon(Icons.remove),
                            label: const Text('Salida de seriales'),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _nuevoMovimiento(item, 'entrada'),
                            icon: const Icon(Icons.add),
                            label: const Text('Entrada'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _nuevoMovimiento(item, 'salida'),
                            icon: const Icon(Icons.remove),
                            label: const Text('Salida'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _nuevoMovimiento(item, 'ajuste'),
                            icon: const Icon(Icons.tune),
                            label: const Text('Ajuste'),
                          ),
                        ],
                      ),
                    if (p.usaSerial) ..._seccionUnidades(datos.unidades),
                    const SizedBox(height: 24),
                    Text(
                      'Movimientos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (datos.movimientos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Todavía no hay movimientos.'),
                        ),
                      ),
                    for (final m in datos.movimientos)
                      Card(
                        child: ListTile(
                          leading: Icon(_icono(m.tipo)),
                          title: Text(
                            '${formatoFecha(m.fecha)} · '
                            '${nombresTipoMovimiento[m.tipo] ?? m.tipo} '
                            '${m.efecto >= 0 ? '+' : '-'}'
                            '${formatoCantidad(m.efecto.abs())}',
                          ),
                          subtitle: Text(
                            [
                              etiquetaOrigen(m.origen),
                              if (m.referencia != null) m.referencia!,
                              if (m.nota != null) m.nota!,
                            ].join(' · '),
                          ),
                          // Los movimientos de facturas y los de productos con serial
                          // no se borran: así los seriales nunca quedan huérfanos.
                          trailing: (m.origen == 'factura' || m.origen == 'anulacion' || p.usaSerial)
                              ? null
                              : IconButton(
                                  tooltip: 'Eliminar movimiento',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _confirmarEliminar(m),
                                ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
