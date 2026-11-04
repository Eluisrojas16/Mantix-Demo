import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'modelos.dart';
import 'seriales.dart';
import 'seriales_db.dart';

/// Entrada de unidades con número de serie: se pegan o escriben los seriales.
class EntradaSerialesPage extends StatefulWidget {
  final ProductoConStock producto;
  const EntradaSerialesPage({super.key, required this.producto});

  @override
  State<EntradaSerialesPage> createState() => _EntradaSerialesPageState();
}

class _EntradaSerialesPageState extends State<EntradaSerialesPage> {
  DateTime _fecha = hoySinHora();
  String _origen = 'compra';
  final _seriales = TextEditingController();
  late final _costo = TextEditingController(
    text: widget.producto.producto.costo == null
        ? ''
        : formatoCantidad(widget.producto.producto.costo!),
  );
  final _referencia = TextEditingController();
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _seriales.dispose();
    _costo.dispose();
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
    final lista = parsearSeriales(_seriales.text);
    if (lista.isEmpty) {
      _aviso('Escribe al menos un número de serie.');
      return;
    }
    final repetidos = serialesRepetidos(lista);
    if (repetidos.isNotEmpty) {
      _aviso('Hay seriales repetidos en la lista: ${repetidos.join(', ')}');
      return;
    }
    final costoTexto = _costo.text.trim();
    final costo = leerNumero(costoTexto);
    if (costoTexto.isNotEmpty && costo == null) {
      _aviso('El costo no es un número válido.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await BaseDatos.instancia.registrarEntradaSeriales(
        productoId: widget.producto.producto.id!,
        fecha: aIso(_fecha),
        seriales: lista,
        costoUnitario: costo,
        origen: _origen,
        referencia: _vacioANulo(_referencia.text),
        nota: _vacioANulo(_nota.text),
        reingresar: _origen == 'devolucion',
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
      appBar: AppBar(title: const Text('Entrada de seriales')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
              Text(
                'En existencia: ${formatoCantidad(widget.producto.stock)} ${p.unidad}',
              ),
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
              TextField(
                controller: _seriales,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Números de serie *',
                  helperText:
                      'Uno por línea. También puedes pegar una lista separada por comas.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              ListenableBuilder(
                listenable: _seriales,
                builder: (context, _) {
                  final lista = parsearSeriales(_seriales.text);
                  final repetidos = serialesRepetidos(lista);
                  return Text(
                    '${lista.length} ${lista.length == 1 ? 'serial' : 'seriales'}'
                    '${repetidos.isEmpty ? '' : ' · Repetidos en la lista: ${repetidos.join(', ')}'}',
                    style: TextStyle(
                      color: repetidos.isEmpty ? null : Colors.red,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _origen,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  helperText:
                      'En una devolución, un serial ya despachado vuelve a existencia.',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in origenesMovimiento['entrada']!.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _origen = v ?? _origen),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _costo,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Costo unitario',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referencia,
                decoration: const InputDecoration(
                  labelText: 'Referencia',
                  helperText: 'Ej. proveedor o número de factura de compra',
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
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando...' : 'Guardar entrada'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
