import 'package:flutter/material.dart';

/// Marca un campo para que ocupe todo el ancho aunque haya dos columnas.
class CampoCompleto extends StatelessWidget {
  final Widget child;
  const CampoCompleto(this.child, {super.key});

  @override
  Widget build(BuildContext context) => child;
}

/// Título de sección (ocupa todo el ancho).
class TituloSeccion extends StatelessWidget {
  final String texto;
  const TituloSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// Acomoda los campos en dos columnas cuando hay espacio y en una sola si no.
class CamposResponsivos extends StatelessWidget {
  final List<Widget> hijos;
  const CamposResponsivos({super.key, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const espacio = 16.0;
        final dosColumnas = c.maxWidth >= 640;
        final ancho = dosColumnas ? (c.maxWidth - espacio) / 2 : c.maxWidth;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final h in hijos)
              SizedBox(
                width: (h is CampoCompleto || h is TituloSeccion)
                    ? c.maxWidth
                    : ancho,
                child: h,
              ),
          ],
        );
      },
    );
  }
}
