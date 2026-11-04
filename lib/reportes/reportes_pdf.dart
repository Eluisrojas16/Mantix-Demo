import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/dinero.dart';
import '../utils/fechas.dart';
import '../ventas/modelos.dart';

final _azul = PdfColor.fromInt(0xFF1F3A5F);

String _horaAhora() {
  final n = DateTime.now();
  String dos(int v) => v.toString().padLeft(2, '0');
  return '${dos(n.hour)}:${dos(n.minute)}';
}

/// La hora HH:MM dentro de una fecha_hora (como 'AAAA-MM-DD HH:MM:SS').
String _horaDe(String? fechaHora) {
  if (fechaHora == null || fechaHora.isEmpty) return '';
  final trozos = fechaHora.split(' ');
  final s = trozos.length > 1 ? trozos.last : fechaHora;
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// Encabezado y pie comunes a todos los reportes (igual estilo que facturas).
pw.MultiPage _base({
  required Negocio negocio,
  required String titulo,
  required String periodo,
  required List<pw.Widget> Function(pw.Context) contenido,
}) {
  final imagenLogo =
      negocio.logo == null ? null : pw.MemoryImage(negocio.logo!);

  final infoNegocio = <String>[
    if (negocio.rnc != null) 'RNC ${negocio.rnc}',
    if (negocio.direccion != null) negocio.direccion!,
    if (negocio.telefono != null) 'Tel. ${negocio.telefono}',
    if (negocio.correo != null) negocio.correo!,
  ];

  return pw.MultiPage(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(36),
    header: (contexto) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (imagenLogo != null) ...[
          pw.Container(
            width: 150,
            height: 64,
            alignment: pw.Alignment.bottomLeft,
            child: pw.Image(
              imagenLogo,
              fit: pw.BoxFit.contain,
              alignment: pw.Alignment.bottomLeft,
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Text(
          negocio.nombre,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        for (final l in infoNegocio)
          pw.Text(
            l,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _azul,
              ),
            ),
            pw.Text(
              periodo,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
    ),
    footer: (contexto) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado el ${formatoFecha(aIso(DateTime.now()))} a las ${_horaAhora()}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
    build: contenido,
  );
}

pw.Widget _celda(
  String texto, {
  bool encabezado = false,
  pw.TextAlign alinear = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Text(
      texto,
      textAlign: alinear,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: encabezado ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: encabezado ? PdfColors.white : PdfColors.black,
      ),
    ),
  );
}

pw.Widget _filaTotal(String texto, String valor, {bool fuerte = false}) {
  final estilo = pw.TextStyle(
    fontSize: fuerte ? 13 : 10,
    fontWeight: fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(texto, style: estilo), pw.Text(valor, style: estilo)],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTE DE COBROS
// ─────────────────────────────────────────────────────────────────────────────

/// PDF del reporte de cobros. Usa las mismas filas que la pantalla de reportes.
Future<Uint8List> generarPdfReporteCobros({
  required Negocio negocio,
  required DateTime desde,
  required DateTime hasta,
  required List<Map<String, Object?>> filas,
}) async {
  double capital = 0, mora = 0, total = 0;
  for (final r in filas) {
    capital += (r['monto_capital'] as num?)?.toDouble() ?? 0;
    mora += (r['mora_cobrada'] as num?)?.toDouble() ?? 0;
    total += (r['monto_total'] as num?)?.toDouble() ?? 0;
  }

  final pdf = pw.Document(
    title: 'Reporte de cobros',
    author: negocio.nombre,
  );

  pdf.addPage(
    _base(
      negocio: negocio,
      titulo: 'REPORTE DE COBROS',
      periodo: 'Del ${formatoFecha(aIso(desde))} al ${formatoFecha(aIso(hasta))}',
      contenido: (contexto) => [
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(52),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(58),
            3: const pw.FixedColumnWidth(62),
            4: const pw.FixedColumnWidth(52),
            5: const pw.FixedColumnWidth(66),
          },
          border: const pw.TableBorder(
            horizontalInside:
                pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _azul),
              children: [
                _celda('Fecha', encabezado: true),
                _celda('Cliente', encabezado: true),
                _celda('Método', encabezado: true),
                _celda('Cobró', encabezado: true),
                _celda('Mora', encabezado: true, alinear: pw.TextAlign.right),
                _celda('Monto', encabezado: true, alinear: pw.TextAlign.right),
              ],
            ),
            for (final r in filas) ...[
              () {
                final banco = r['banco'] as String?;
                final voucher = r['voucher'] as String?;
                final ref = r['referencia'] as String?;
                final notas = r['notas'] as String?;
                final moraRow = (r['mora_cobrada'] as num?)?.toDouble() ?? 0;
                final detalles = <String>[
                  if (ref != null && ref.isNotEmpty) 'Ref: $ref',
                  if (voucher != null && voucher.isNotEmpty) 'Voucher: $voucher',
                  if (banco != null && banco.isNotEmpty) banco,
                  if (notas != null && notas.isNotEmpty) notas,
                ];
                return pw.TableRow(
                  children: [
                    _celda(formatoFecha(r['fecha'] as String?)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5, vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            r['cliente_nombre'] as String? ?? '',
                            style: const pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          for (final d in detalles)
                            pw.Text(
                              d,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _celda(r['metodo_pago'] as String? ?? ''),
                    _celda(r['usuario_nombre'] as String? ?? ''),
                    _celda(
                      moraRow > 0 ? formatoDinero(moraRow) : '-',
                      alinear: pw.TextAlign.right,
                    ),
                    _celda(
                      formatoDinero(
                          (r['monto_total'] as num?)?.toDouble() ?? 0),
                      alinear: pw.TextAlign.right,
                    ),
                  ],
                );
              }(),
            ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 250,
            child: pw.Column(
              children: [
                _filaTotal('Capital cobrado', 'RD\$ ${formatoDinero(capital)}'),
                _filaTotal('Mora cobrada', 'RD\$ ${formatoDinero(mora)}'),
                pw.Divider(color: PdfColors.grey500, thickness: 0.5),
                _filaTotal('TOTAL COBRADO', 'RD\$ ${formatoDinero(total)}',
                    fuerte: true),
              ],
            ),
          ),
        ),
        if (filas.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Center(
              child: pw.Text(
                'Sin cobros en el período seleccionado.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ),
      ],
    ),
  );

  return pdf.save();
}

// ─────────────────────────────────────────────────────────────────────────────
// CIERRE DE CAJA
// ─────────────────────────────────────────────────────────────────────────────

/// PDF del cierre de caja: los cobros de un día agrupados por usuario,
/// con el detalle de cada cobro (cliente, método, banco/voucher) y totales.
Future<Uint8List> generarPdfCierreCaja({
  required Negocio negocio,
  required DateTime fecha,
  required Map<String, List<Map<String, Object?>>> grupos,
}) async {
  double totalDia = 0;
  for (final filas in grupos.values) {
    for (final r in filas) {
      totalDia += (r['monto_total'] as num?)?.toDouble() ?? 0;
    }
  }

  final pdf = pw.Document(
    title: 'Cierre de caja',
    author: negocio.nombre,
  );

  pdf.addPage(
    _base(
      negocio: negocio,
      titulo: 'CIERRE DE CAJA',
      periodo:
          'Cobros del ${formatoFecha(aIso(fecha))}',
      contenido: (contexto) => [
        for (final e in grupos.entries) ...[
          pw.Container(
            color: PdfColors.grey200,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  e.key,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _azul,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(46),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(56),
              3: const pw.FixedColumnWidth(56),
            },
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _azul),
                children: [
                  _celda('Hora', encabezado: true),
                  _celda('Cliente', encabezado: true),
                  _celda('Método / Banco', encabezado: true),
                  _celda('Monto', encabezado: true, alinear: pw.TextAlign.right),
                ],
              ),
                for (final r in e.value)
                  () {
                    final hora = _horaDe(r['fecha_hora'] as String?);
                    final metodo = r['metodo_pago'] as String?;
                    final banco = r['banco'] as String?;
                    final voucher = r['voucher'] as String?;
                    final ref = r['referencia'] as String?;
                    final notas = r['notas'] as String?;
                    final bajo = <String>[
                      if (banco != null && banco.isNotEmpty) banco,
                      if (voucher != null && voucher.isNotEmpty) 'V: $voucher',
                      if (ref != null && ref.isNotEmpty) 'Ref: $ref',
                      if (notas != null && notas.isNotEmpty) notas,
                    ];
                    return pw.TableRow(
                      children: [
                        _celda(hora),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              r['cliente_nombre'] as String? ?? '',
                              style: const pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                            for (final d in bajo)
                              pw.Text(
                                d,
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _celda(metodo != null && metodo.isNotEmpty
                          ? metodo
                          : ''),
                        _celda(
                          formatoDinero(
                              (r['monto_total'] as num?)?.toDouble() ?? 0),
                          alinear: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }(),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _celda(''),
                  _celda('Subtotal ${e.key}',
                      encabezado: true),
                  _celda(''),
                  _celda(
                      formatoDinero([for (final f in e.value) f]
                          .fold<double>(0,
                              (t, r) => t + ((r['monto_total'] as num?)?.toDouble() ?? 0))),
                      encabezado: true,
                      alinear: pw.TextAlign.right),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
        ],
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL DEL DÍA',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'RD\$ ${formatoDinero(totalDia)}',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (grupos.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Center(
              child: pw.Text(
                'Sin cobros ese día.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ),
      ],
    ),
  );

  return pdf.save();
}

/// PDF del reporte de movimientos de inventario.
Future<Uint8List> generarPdfReporteInventario({
  required Negocio negocio,
  required DateTime desde,
  required DateTime hasta,
  required List<Map<String, Object?>> filas,
}) async {
  int entradas = 0, salidas = 0;
  for (final r in filas) {
    if (r['tipo'] == 'entrada') {
      entradas++;
    } else {
      salidas++;
    }
  }

  final pdf = pw.Document(
    title: 'Reporte de movimientos de inventario',
    author: negocio.nombre,
  );

  pdf.addPage(
    _base(
      negocio: negocio,
      titulo: 'MOVIMIENTOS DE INVENTARIO',
      periodo: 'Del ${formatoFecha(aIso(desde))} al ${formatoFecha(aIso(hasta))}',
      contenido: (contexto) => [
        pw.Text(
          'Entradas: $entradas   ·   Salidas: $salidas',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(52),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(58),
            3: const pw.FixedColumnWidth(52),
          },
          border: const pw.TableBorder(
            horizontalInside:
                pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _azul),
              children: [
                _celda('Fecha', encabezado: true),
                _celda('Producto', encabezado: true),
                _celda('Tipo', encabezado: true),
                _celda('Cant.', encabezado: true, alinear: pw.TextAlign.right),
              ],
            ),
            for (final r in filas)
              () {
                final esEntrada = r['tipo'] == 'entrada';
                final codigo = r['producto_codigo'] as String?;
                final motivo = r['motivo'] as String?;
                final ref = r['referencia'] as String?;
                final notas = r['notas'] as String?;
                final usuario = r['usuario_nombre'] as String?;
                final detalles = <String>[
                  if (codigo != null && codigo.isNotEmpty) 'Código: $codigo',
                  if (motivo != null && motivo.isNotEmpty) motivo,
                  if (ref != null && ref.isNotEmpty) 'Ref: $ref',
                  if (notas != null && notas.isNotEmpty) notas,
                  'Por: ${usuario ?? 'Admin'}',
                ];
                final cantidad = (r['cantidad'] as num?)?.toDouble() ?? 0;
                return pw.TableRow(
                  children: [
                    _celda(formatoFecha(r['fecha'] as String?)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5, vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            r['producto_nombre'] as String? ?? '',
                            style: const pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          for (final d in detalles)
                            pw.Text(
                              d,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _celda(
                      esEntrada ? 'Entrada' : 'Salida',
                    ),
                    _celda(
                      '${esEntrada ? '+' : '-'}'
                      '${cantidad % 1 == 0 ? cantidad.toInt() : cantidad}',
                      alinear: pw.TextAlign.right,
                    ),
                  ],
                );
              }(),
          ],
        ),
        if (filas.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Center(
              child: pw.Text(
                'Sin movimientos en el período seleccionado.',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ),
      ],
    ),
  );

  return pdf.save();
}
