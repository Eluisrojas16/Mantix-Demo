import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import 'modelos.dart';
import 'seriales_db.dart';

/// Salida de almacén: se marcan los números de serie exactos que se despachan.
class SalidaSerialesPage extends StatefulWidget {
  final ProductoConStock producto;
  const SalidaSerialesPage({super.key, required this.producto});

  @override
  State<SalidaSerialesPage> createState() => _SalidaSerialesPageState();
}

class _SalidaSerialesPageState extends State<SalidaSerialesPage> {
  late final Future<List<Unidad>> _futuro = BaseDatos.instancia
      .listarUnidades(widget.producto.producto.id!)
      .then((todas) => todas.where((u) => u.enStock).toList());
  final _busqueda = TextEditingController();
  final _seleccion = <int>{};
  DateTime _fecha = hoySinHora();
  String _origen = origenesMovimiento['salida']!.keys.first;
  final _referencia = TextEditingController();
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _busqueda.dispose();
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: hoySinHora(),
    );
    if (elegida != null && mounted) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    if (_seleccion.isEmpty) {
      _aviso('Marca al menos un número de serie.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await BaseDatos.instancia.registrarSalidaSeriales(
        productoId: widget.producto.producto.id!,
        fecha: aIso(_fecha),
        unidadIds: _seleccion.toList(),
        origen: _origen,
        referencia: _vacioANulo(_referencia.text),
        nota: _vacioANulo(_nota.text),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(e is StateError ? e.message : 'No se pudo guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto.producto;
    return Scaffold(
      appBar: AppBar(title: const Text('Salida de seriales')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: (_seleccion.isEmpty || _guardando) ? null : _guardar,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(
              _guardando
                  ? 'Guardando...'
                  : 'Registrar salida (${_seleccion.length})',
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              InkWell(
                onTap: _elegirFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(formatoFecha(aIso(_fecha))),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _origen,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  helperText: 'Las ventas se registrarán desde las facturas.',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in origenesMovimiento['salida']!.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _origen = v ?? _origen),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referencia,
                decoration: const InputDecoration(
                  labelText: 'Referencia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nota,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Elige los seriales que salen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
                  if (snap.hasError) {
                    return Text('Error: ${snap.error}');
                  }
                  final q = _busqueda.text.trim().toLowerCase();
                  final unidades = (snap.data ?? [])
                      .where((u) => q.isEmpty || u.serial.toLowerCase().contains(q))
                      .toList();
                  if (unidades.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No hay seriales en existencia.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final u in unidades)
                        CheckboxListTile(
                          value: _seleccion.contains(u.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _seleccion.add(u.id);
                            } else {
                              _seleccion.remove(u.id);
                            }
                          }),
                          title: Text(
                            u.serial,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Entrada ${formatoFecha(u.fechaEntrada)}'),
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
