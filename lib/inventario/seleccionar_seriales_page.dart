import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import 'modelos.dart';
import 'seriales_db.dart';

/// Elegir EXACTAMENTE [cantidad] números de serie en existencia de un producto.
/// Devuelve la lista de Unidad elegidas. [excluir] oculta las que ya se eligieron
/// en otra línea del mismo documento.
class SeleccionarSerialesPage extends StatefulWidget {
  final int productoId;
  final String nombre;
  final int cantidad;
  final Set<int> preseleccion;
  final Set<int> excluir;

  const SeleccionarSerialesPage({
    super.key,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    this.preseleccion = const {},
    this.excluir = const {},
  });

  @override
  State<SeleccionarSerialesPage> createState() =>
      _SeleccionarSerialesPageState();
}

class _SeleccionarSerialesPageState extends State<SeleccionarSerialesPage> {
  late final Future<List<Unidad>> _futuro = BaseDatos.instancia
      .listarUnidades(widget.productoId)
      .then((todas) => todas
          .where((u) => u.enStock && !widget.excluir.contains(u.id))
          .toList());
  late final Set<int> _sel = {...widget.preseleccion};
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _aceptar() async {
    final lista = await _futuro;
    if (!mounted) return;
    Navigator.pop(context, lista.where((u) => _sel.contains(u.id)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir números de serie')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _sel.length == widget.cantidad ? _aceptar : null,
            icon: const Icon(Icons.check),
            label: Text('Aceptar (${_sel.length} de ${widget.cantidad})'),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.nombre,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Elige ${widget.cantidad} ${widget.cantidad == 1 ? 'serial' : 'seriales'}.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar serial',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Unidad>>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) return Text('Error: ${snap.error}');
                  final q = _busqueda.text.trim().toLowerCase();
                  final unidades = (snap.data ?? [])
                      .where((u) =>
                          q.isEmpty || u.serial.toLowerCase().contains(q))
                      .toList();
                  if (unidades.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No hay seriales disponibles.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final u in unidades)
                        CheckboxListTile(
                          value: _sel.contains(u.id),
                          onChanged: (v) {
                            if (v == true && _sel.length >= widget.cantidad) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ya elegiste ${widget.cantidad}. '
                                    'Quita uno para elegir otro.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              if (v == true) {
                                _sel.add(u.id);
                              } else {
                                _sel.remove(u.id);
                              }
                            });
                          },
                          title: Text(
                            u.serial,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Entrada ${formatoFecha(u.fechaEntrada)}'),
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
