import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import 'catalogos_db.dart';
import 'dialogos.dart';
import 'modelos.dart';

/// Administra las listas que luego se seleccionan en los productos:
/// marcas con sus modelos, y categorías.
class CatalogosPage extends StatelessWidget {
  const CatalogosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marcas, modelos y categorías'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Marcas y modelos'),
              Tab(text: 'Categorías'),
            ],
          ),
        ),
        body: const TabBarView(children: [_MarcasTab(), _CategoriasTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Marcas y modelos

class _MarcasTab extends StatefulWidget {
  const _MarcasTab();

  @override
  State<_MarcasTab> createState() => _MarcasTabState();
}

class _MarcasTabState extends State<_MarcasTab> {
  late Future<List<ItemCatalogo>> _futuro = BaseDatos.instancia.listarMarcas();

  void _recargar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarMarcas();
    });
  }

  Future<void> _agregarMarca() async {
    final n = await pedirTexto(context, titulo: 'Nueva marca');
    if (n == null) return;
    await BaseDatos.instancia.crearMarca(n);
    if (!mounted) return;
    _recargar();
  }

  Future<void> _renombrarMarca(ItemCatalogo m) async {
    final n = await pedirTexto(
      context,
      titulo: 'Renombrar marca',
      inicial: m.nombre,
    );
    if (n == null || !mounted) return;
    try {
      await BaseDatos.instancia.renombrarMarca(m.id, n);
    } catch (e) {
      if (!mounted) return;
      aviso(
        context,
        e.toString().contains('UNIQUE')
            ? 'Ya existe una marca con ese nombre.'
            : 'No se pudo renombrar: $e',
      );
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _eliminarMarca(ItemCatalogo m) async {
    final usados = await BaseDatos.instancia.productosConMarca(m.id);
    if (!mounted) return;
    if (usados > 0) {
      aviso(
        context,
        'No se puede eliminar: la usan $usados producto(s). '
        'Cámbiales la marca primero.',
      );
      return;
    }
    final ok = await confirmar(
      context,
      'Eliminar marca',
      m.cantidad > 0
          ? '¿Eliminar ${m.nombre} y sus ${m.cantidad} modelos?'
          : '¿Eliminar ${m.nombre}?',
    );
    if (!ok || !mounted) return;
    await BaseDatos.instancia.eliminarMarca(m.id);
    if (!mounted) return;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _agregarMarca,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar marca'),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ItemCatalogo>>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final marcas = snap.data ?? [];
                  if (marcas.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay marcas. Agrega la primera para '
                          'poder elegirla al crear productos.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      for (final m in marcas)
                        ExpansionTile(
                          key: PageStorageKey('marca-${m.id}'),
                          title: Text(m.nombre),
                          subtitle: Text(
                            m.cantidad == 1 ? '1 modelo' : '${m.cantidad} modelos',
                          ),
                          children: [
                            _ModelosDeMarca(
                              marca: m,
                              onCambio: _recargar,
                              onRenombrarMarca: () => _renombrarMarca(m),
                              onEliminarMarca: () => _eliminarMarca(m),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelosDeMarca extends StatefulWidget {
  final ItemCatalogo marca;
  final VoidCallback onCambio;
  final VoidCallback onRenombrarMarca;
  final VoidCallback onEliminarMarca;
  const _ModelosDeMarca({
    required this.marca,
    required this.onCambio,
    required this.onRenombrarMarca,
    required this.onEliminarMarca,
  });

  @override
  State<_ModelosDeMarca> createState() => _ModelosDeMarcaState();
}

class _ModelosDeMarcaState extends State<_ModelosDeMarca> {
  late Future<List<ItemCatalogo>> _futuro =
      BaseDatos.instancia.listarModelosDe(widget.marca.id);

  void _recargar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarModelosDe(widget.marca.id);
    });
    widget.onCambio();
  }

  Future<void> _agregar() async {
    final n = await pedirTexto(
      context,
      titulo: 'Nuevo modelo de ${widget.marca.nombre}',
    );
    if (n == null) return;
    await BaseDatos.instancia.crearModelo(widget.marca.id, n);
    if (!mounted) return;
    _recargar();
  }

  Future<void> _renombrar(ItemCatalogo mo) async {
    final n = await pedirTexto(
      context,
      titulo: 'Renombrar modelo',
      inicial: mo.nombre,
    );
    if (n == null || !mounted) return;
    try {
      await BaseDatos.instancia.renombrarModelo(mo.id, n);
    } catch (e) {
      if (!mounted) return;
      aviso(
        context,
        e.toString().contains('UNIQUE')
            ? 'Esa marca ya tiene un modelo con ese nombre.'
            : 'No se pudo renombrar: $e',
      );
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _eliminar(ItemCatalogo mo) async {
    if (mo.cantidad > 0) {
      aviso(
        context,
        'No se puede eliminar: lo usan ${mo.cantidad} producto(s). '
        'Cámbiales el modelo primero.',
      );
      return;
    }
    final ok = await confirmar(
      context,
      'Eliminar modelo',
      '¿Eliminar ${mo.nombre}?',
    );
    if (!ok || !mounted) return;
    await BaseDatos.instancia.eliminarModelo(mo.id);
    if (!mounted) return;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ItemCatalogo>>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        final modelos = snap.data ?? [];
        return Column(
          children: [
            if (modelos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Esta marca aún no tiene modelos.'),
              ),
            for (final mo in modelos)
              ListTile(
                dense: true,
                title: Text(mo.nombre),
                subtitle: mo.cantidad > 0
                    ? Text(mo.cantidad == 1
                        ? 'En 1 producto'
                        : 'En ${mo.cantidad} productos')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Renombrar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _renombrar(mo),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _eliminar(mo),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _agregar,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar modelo'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onRenombrarMarca,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Renombrar marca'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEliminarMarca,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar marca'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Categorías

class _CategoriasTab extends StatefulWidget {
  const _CategoriasTab();

  @override
  State<_CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends State<_CategoriasTab> {
  late Future<List<ItemCatalogo>> _futuro =
      BaseDatos.instancia.listarCategorias();

  void _recargar() {
    setState(() {
      _futuro = BaseDatos.instancia.listarCategorias();
    });
  }

  Future<void> _agregar() async {
    final n = await pedirTexto(context, titulo: 'Nueva categoría');
    if (n == null) return;
    await BaseDatos.instancia.crearCategoria(n);
    if (!mounted) return;
    _recargar();
  }

  Future<void> _renombrar(ItemCatalogo c) async {
    final n = await pedirTexto(
      context,
      titulo: 'Renombrar categoría',
      inicial: c.nombre,
    );
    if (n == null || !mounted) return;
    try {
      await BaseDatos.instancia.renombrarCategoria(c.id, n);
    } catch (e) {
      if (!mounted) return;
      aviso(
        context,
        e.toString().contains('UNIQUE')
            ? 'Ya existe una categoría con ese nombre.'
            : 'No se pudo renombrar: $e',
      );
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _eliminar(ItemCatalogo c) async {
    if (c.cantidad > 0) {
      aviso(
        context,
        'No se puede eliminar: la usan ${c.cantidad} producto(s). '
        'Cámbiales la categoría primero.',
      );
      return;
    }
    final ok = await confirmar(
      context,
      'Eliminar categoría',
      '¿Eliminar ${c.nombre}?',
    );
    if (!ok || !mounted) return;
    await BaseDatos.instancia.eliminarCategoria(c.id);
    if (!mounted) return;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _agregar,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar categoría'),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ItemCatalogo>>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final categorias = snap.data ?? [];
                  if (categorias.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay categorías. Agrega la primera para '
                          'poder elegirla al crear productos.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: categorias.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = categorias[i];
                      return ListTile(
                        title: Text(c.nombre),
                        subtitle: Text(
                          c.cantidad == 1
                              ? '1 producto'
                              : '${c.cantidad} productos',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Renombrar',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _renombrar(c),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _eliminar(c),
                            ),
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
      ),
    );
  }
}
