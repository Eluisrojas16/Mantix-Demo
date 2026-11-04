import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Muestra un PDF dentro de la app, con botones para imprimirlo o compartirlo.
class VistaPdfPage extends StatelessWidget {
  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function() generar;

  const VistaPdfPage({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.generar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: PdfPreview(
        build: (formato) => generar(),
        pdfFileName: nombreArchivo,
        initialPageFormat: PdfPageFormat.letter,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
