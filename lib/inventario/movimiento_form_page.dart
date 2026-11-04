import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'inventario_db.dart';
import 'modelos.dart';

/// Formulario para registrar una entrada, salida o ajuste de un producto.
class MovimientoFormPage extends StatefulWidget {
  final ProductoConStock producto;
  final String tipo; // entrada, salida o ajuste
  const MovimientoFormPage({
    super.key,
    required this.producto,
    required this.tipo,
  });

  @override
  State<MovimientoFormPage> createState() => _MovimientoFormPageState();
}

class _MovimientoFormPageState extends State<MovimientoFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = hoySinHora();
  late String _origen = origenesMovimiento[widget.tipo]!.keys.first;
  final _cantidad = TextEditingController();
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
    _cantidad.dispose();
    _costo.dispose();
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
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
    if (elegida != null && mounted) {
      setState(() => _fecha = elegida);
    }
  }

  String? _validarCantidad(String? v) {
    final n = leerNumero(v ?? '');
    if (n == null) return 'Escribe una cantidad';
    final stock = widget.producto.stock;
    final unidad = widget.producto.producto.unidad;
    switch (widget.tipo) {
      case 'entrada':
        return n > 0 ? null : 'Debe ser mayor que cero';
      case 'salida':
        if (n <= 0) return 'Debe ser mayor que cero';
        if (n > stock) {
          return 'Solo hay ${formatoCantidad(stock)} $unidad en existencia';
        }
        return null;
      default: // ajuste
        if (n == 0) return 'No puede ser cero';
        if (stock + n < 0) {
          return 'Dejaría la existencia en negativo (hay ${formatoCantidad(stock)} $unidad)';
        }
        return null;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final m = Movimiento(
      productoId: widget.producto.producto.id!,
      fecha: aIso(_fecha),
      tipo: widget.tipo,
      cantidad: leerNumero(_cantidad.text)!,
      costoUnitario:
          widget.tipo == 'entrada' ? leerNumero(_costo.text) : null,
      origen: _origen,
      referencia: _vacioANulo(_referencia.text),
      nota: _vacioANulo(_nota.text),
    );

    try {
      await BaseDatos.instancia.registrarMovimiento(m);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto.producto;
    final esAjuste = widget.tipo == 'ajuste';
    return Scaffold(
      appBar: AppBar(
        title: Text('${nombresTipoMovimiento[widget.tipo]} de inventario'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'Existencia actual: ${formatoCantidad(widget.producto.stock)} ${p.unidad}',
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
                TextFormField(
                  controller: _cantidad,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: esAjuste,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad *',
                    helperText: esAjuste
                        ? 'Positivo suma, negativo resta (ej. -2)'
                        : null,
                    suffixText: p.unidad,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validarCantidad,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _origen,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in origenesMovimiento[widget.tipo]!.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _origen = v ?? _origen),
                ),
                if (widget.tipo == 'entrada') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _costo,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo unitario',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return leerNumero(t) == null ? 'Número inválido' : null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referencia,
                  decoration: const InputDecoration(
                    labelText: 'Referencia',
                    helperText: 'Ej. proveedor o número de factura de compra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
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
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
