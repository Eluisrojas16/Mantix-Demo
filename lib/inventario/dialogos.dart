import 'package:flutter/material.dart';

/// Pide un texto corto (por ejemplo, el nombre de una marca). Null si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  String? inicial,
  String etiqueta = 'Nombre',
  TextCapitalization capitalizar = TextCapitalization.words,
}) async {
  final controlador = TextEditingController(text: inicial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: controlador,
        autofocus: true,
        textCapitalization: capitalizar,
        decoration: InputDecoration(
          labelText: etiqueta,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

/// Pregunta si se confirma una acción. [textoConfirmar] es el texto del botón.
Future<bool> confirmar(
  BuildContext context,
  String titulo,
  String mensaje, {
  String textoConfirmar = 'Eliminar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return r == true;
}

void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}
