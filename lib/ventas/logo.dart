import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Tamaño del recuadro donde se ajusta el logo (en puntos, igual en PDF y en pantalla).
const logoAncho = 150.0;
const logoAlto = 64.0;

class LogoPreparado {
  final Uint8List bytes; // PNG listo para guardar y para el PDF
  final int ancho; // tamaño de la imagen original
  final int alto;
  final String? advertencia;
  const LogoPreparado(this.bytes, this.ancho, this.alto, this.advertencia);
}

/// Lee la imagen elegida (PNG, JPG, GIF, WebP o BMP), la reduce si es enorme y
/// la convierte a PNG conservando la transparencia. Devuelve null si no se puede leer.
LogoPreparado? prepararLogo(Uint8List original) {
  final imagen = img.decodeImage(original);
  if (imagen == null) return null;

  final ancho = imagen.width;
  final alto = imagen.height;

  // Un logo no necesita más de 600 px: así el PDF y la base de datos no pesan de más.
  const maximo = 600;
  var salida = imagen;
  if (ancho > maximo || alto > maximo) {
    salida = ancho >= alto
        ? img.copyResize(imagen,
            width: maximo, interpolation: img.Interpolation.average)
        : img.copyResize(imagen,
            height: maximo, interpolation: img.Interpolation.average);
  }
  final png = Uint8List.fromList(img.encodePng(salida));

  String? advertencia;
  if (ancho < 300) {
    advertencia =
        'La imagen es pequeña ($ancho × $alto px) y puede verse borrosa al '
        'imprimir. Lo ideal es que tenga al menos 600 px de ancho.';
  } else if (alto > ancho) {
    advertencia =
        'El logo es más alto que ancho, así que se verá pequeño dentro del '
        'recuadro. Un logo horizontal luce mejor en el encabezado.';
  }
  return LogoPreparado(png, ancho, alto, advertencia);
}
