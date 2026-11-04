import 'package:flutter/material.dart';

import '../utils/numeros.dart';
import 'modelos.dart';

/// Diálogo para crear o editar una línea (cantidad, precio, descuento, ITBIS).
/// Devuelve la línea editada, o null si se cancela.
Future<LineaVenta?> editarLinea(BuildContext context, LineaVenta inicial) {
  final formKey = GlobalKey<FormState>();
  final desc = TextEditingController(text: inicial.descripcion);
  final cantidad = TextEditingController(text: formatoCantidad(inicial.cantidad));
  final unidad = TextEditingController(text: inicial.unidad);
  final precio = TextEditingController(
    text: inicial.precioUnitario == 0 ? '' : formatoCantidad(inicial.precioUnitario),
  );
  final descuento = TextEditingController(
    text: inicial.descuentoPct == 0 ? '' : formatoCantidad(inicial.descuentoPct),
  );
  final itbis = TextEditingController(text: formatoCantidad(inicial.itbisPct));
  const decimales = TextInputType.numberWithOptions(decimal: true);

  String? porcentaje(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = leerNumero(t);
    if (n == null || n < 0 || n > 100) return '0 a 100';
    return null;
  }

  return showDialog<LineaVenta>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(inicial.productoId == null ? 'Concepto' : 'Artículo'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: desc,
                  autofocus: inicial.descripcion.isEmpty,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe una descripción'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cantidad,
                        keyboardType: decimales,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = leerNumero(v ?? '');
                          return (n == null || n <= 0)
                              ? 'Mayor que cero'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unidad,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: precio,
                  keyboardType: decimales,
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario (sin ITBIS)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final n = leerNumero(t);
                    return (n == null || n < 0) ? 'Número inválido' : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: descuento,
                        keyboardType: decimales,
                        decoration: const InputDecoration(
                          labelText: 'Descuento %',
                          border: OutlineInputBorder(),
                        ),
                        validator: porcentaje,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: itbis,
                        keyboardType: decimales,
                        decoration: const InputDecoration(
                          labelText: 'ITBIS %',
                          border: OutlineInputBorder(),
                        ),
                        validator: porcentaje,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              ctx,
              LineaVenta(
                id: inicial.id,
                productoId: inicial.productoId,
                descripcion: desc.text.trim(),
                cantidad: leerNumero(cantidad.text)!,
                unidad: unidad.text.trim().isEmpty ? 'unidad' : unidad.text.trim(),
                precioUnitario: leerNumero(precio.text) ?? 0,
                descuentoPct: leerNumero(descuento.text) ?? 0,
                itbisPct: leerNumero(itbis.text) ?? 0,
              ),
            );
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}
