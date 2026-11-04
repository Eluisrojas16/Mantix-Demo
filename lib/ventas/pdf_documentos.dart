import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cliente.dart';
import '../utils/dinero.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'logo.dart';
import 'factura_modelos.dart';
import 'modelos.dart';

/// Todo lo que necesita una hoja: sirve para cotizaciones y, más adelante, facturas.
class DocumentoPdf {
  final String titulo; // COTIZACIÓN, FACTURA...
  final String numero;
  final List<MapEntry<String, String>> datos; // Fecha, Válida hasta...
  final String clienteNombre;
  final List<String> clienteDetalle; // RNC o cédula, teléfono, dirección
  final List<LineaVenta> lineas;
  final Totales totales;
  final String? notas;
  final List<Cuota>? cuotas;
  final Factura? factura;

  const DocumentoPdf({
    required this.titulo,
    required this.numero,
    required this.datos,
    required this.clienteNombre,
    required this.clienteDetalle,
    required this.lineas,
    required this.totales,
    this.notas,
    this.cuotas,
    this.factura,
  });
}

DocumentoPdf documentoDeCotizacion(
  Cotizacion c,
  Cliente? cli,
  List<LineaVenta> lineas,
) {
  return DocumentoPdf(
    titulo: 'COTIZACIÓN',
    numero: c.numero,
    datos: [
      MapEntry('Fecha', formatoFecha(c.fecha)),
      MapEntry('Válida hasta', formatoFecha(c.vigenciaHasta)),
    ],
    clienteNombre: c.clienteNombre ?? cli?.nombreApellido ?? '',
    clienteDetalle: [
      if (cli != null && cli.esEmpresa && cli.rnc != null) 'RNC ${cli.rnc}',
      if (cli != null && !cli.esEmpresa && cli.cedula != null)
        'Cédula ${cli.cedula}',
      if (cli?.telefono != null) 'Tel. ${cli!.telefono}',
      if (cli?.direccion != null) cli!.direccion!,
    ],
    lineas: lineas,
    totales: Totales(c.subtotal, c.itbis),
    notas: c.notas,
  );
}

/// Hoja de ejemplo para ver cómo queda el encabezado con el logo del negocio.
DocumentoPdf documentoDeEjemplo() {
  final hoy = hoySinHora();
  final lineas = [
    const LineaVenta(
      descripcion: 'Aire acondicionado split 12,000 BTU · Marca Modelo',
      precioUnitario: 25000,
      descuentoPct: 10,
    ),
    const LineaVenta(
      descripcion: 'Instalación estándar (mano de obra)',
      precioUnitario: 3500,
    ),
    const LineaVenta(
      descripcion: 'Tubería de cobre',
      cantidad: 2.5,
      unidad: 'metro',
      precioUnitario: 320,
    ),
  ];
  return DocumentoPdf(
    titulo: 'COTIZACIÓN',
    numero: 'COT-0001',
    datos: [
      MapEntry('Fecha', formatoFecha(aIso(hoy))),
      MapEntry(
        'Válida hasta',
        formatoFecha(aIso(DateTime(hoy.year, hoy.month, hoy.day + 15))),
      ),
    ],
    clienteNombre: 'Cliente de ejemplo',
    clienteDetalle: const ['Cédula 000-0000000-0', 'Tel. 809-000-0000'],
    lineas: lineas,
    totales: Totales.de(lineas),
    notas: 'Esta es una hoja de ejemplo para que veas cómo quedará el '
        'encabezado con los datos y el logo de tu negocio.',
  );
}

/// Genera el PDF (tamaño carta). El logo se ajusta a un recuadro fijo sin deformarse.
Future<Uint8List> generarPdfDocumento({
  required Negocio negocio,
  Uint8List? logo,
  required DocumentoPdf doc,
}) async {
  final pdf = pw.Document(
    title: '${doc.titulo} ${doc.numero}',
    author: negocio.nombre,
  );

  final azul = PdfColor.fromInt(0xFF1F3A5F);
  final imagenLogo = logo == null ? null : pw.MemoryImage(logo);

  pw.Widget celda(
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

  pw.Widget filaTotal(String texto, String valor, {bool fuerte = false}) {
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

  pw.Widget caja(List<pw.Widget> hijos) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: hijos,
      ),
    );
  }

  final infoNegocio = <String>[
    if (negocio.rnc != null) 'RNC ${negocio.rnc}',
    if (negocio.direccion != null) negocio.direccion!,
    if (negocio.telefono != null) 'Tel. ${negocio.telefono}',
    if (negocio.correo != null) negocio.correo!,
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (contexto) => [
        // ---- Encabezado: logo arriba y los datos del negocio debajo
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (imagenLogo != null) ...[
              pw.Container(
                width: logoAncho,
                height: logoAlto,
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
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 18),

        // ---- Título y número
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              doc.titulo,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: azul,
              ),
            ),
            pw.Text(
              doc.numero,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // ---- Cliente y fechas
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: caja([
                pw.Text(
                  'CLIENTE',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  doc.clienteNombre,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                for (final l in doc.clienteDetalle)
                  pw.Text(l, style: const pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.SizedBox(width: 12),
            pw.SizedBox(
              width: 190,
              child: caja([
                for (final d in doc.datos)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          d.key,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          d.value,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // ---- Tabla de líneas
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(5),
            1: const pw.FixedColumnWidth(58),
            2: const pw.FixedColumnWidth(64),
            3: const pw.FixedColumnWidth(40),
            4: const pw.FixedColumnWidth(40),
            5: const pw.FixedColumnWidth(72),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: azul),
              children: [
                celda('Descripción', encabezado: true),
                celda('Cant.', encabezado: true, alinear: pw.TextAlign.right),
                celda('Precio', encabezado: true, alinear: pw.TextAlign.right),
                celda('Desc.', encabezado: true, alinear: pw.TextAlign.right),
                celda('ITBIS', encabezado: true, alinear: pw.TextAlign.right),
                celda('Importe', encabezado: true, alinear: pw.TextAlign.right),
              ],
            ),
            for (final l in doc.lineas)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          l.descripcion,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (l.seriales.isNotEmpty)
                          pw.Text(
                            'Serial: ${l.seriales.join(', ')}',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  celda(
                    '${formatoCantidad(l.cantidad)} ${l.unidad}',
                    alinear: pw.TextAlign.right,
                  ),
                  celda(formatoDinero(l.precioUnitario),
                      alinear: pw.TextAlign.right),
                  celda(
                    l.descuentoPct > 0 ? '${formatoCantidad(l.descuentoPct)}%' : '-',
                    alinear: pw.TextAlign.right,
                  ),
                  celda('${formatoCantidad(l.itbisPct)}%',
                      alinear: pw.TextAlign.right),
                  celda(formatoDinero(l.base), alinear: pw.TextAlign.right),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),

        // ---- Totales
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                filaTotal('Subtotal', formatoDinero(doc.totales.subtotal)),
                filaTotal('ITBIS', formatoDinero(doc.totales.itbis)),
                pw.Divider(color: PdfColors.grey500, thickness: 0.5),
                filaTotal(
                  'TOTAL',
                  'RD\$ ${formatoDinero(doc.totales.total)}',
                  fuerte: true,
                ),
              ],
            ),
          ),
        ),

        // ---- Plan de financiamiento si es a crédito
        if (doc.cuotas != null &&
            doc.cuotas!.isNotEmpty &&
            doc.factura?.esCredito == true) ...[
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PLAN DE FINANCIAMIENTO Y CUOTAS',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: azul)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Inicial: RD\$ ${formatoDinero(doc.factura!.inicial)}',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Interés: ${formatoCantidad(doc.factura!.interesPct)}%',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        'Total financiado: RD\$ ${formatoDinero(doc.factura!.totalFinanciado)}',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Saldo pendiente: RD\$ ${formatoDinero(doc.factura!.saldoPendiente)}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text('Cuota',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text('Vencimiento',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text('Monto',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right)),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text('Estado',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center)),
                      ],
                    ),
                    for (final c in doc.cuotas!)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(
                                  'Cuota ${c.numero} de ${doc.factura!.cantidadCuotas}',
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(formatoFecha(c.fechaVencimiento),
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text('RD\$ ${formatoDinero(c.monto)}',
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(c.pagada ? 'Pagada' : 'Pendiente',
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center)),
                        ],
                      ),
                  ],
                ),
                if (doc.factura!.moraPct > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                      '* Pagos posteriores a la fecha de vencimiento generarán un recargo por mora del ${formatoCantidad(doc.factura!.moraPct)}%.',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.red800)),
                ],
              ],
            ),
          ),
        ],

        // ---- Condiciones o notas
        if (doc.notas != null && doc.notas!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Condiciones y notas',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(doc.notas!, style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ),
  );

  return pdf.save();
}

/// Datos de una factura emitida listos para el PDF (con los seriales de cada línea).
DocumentoPdf documentoDeFactura(
  Factura f,
  List<LineaVenta> lineas, [
  List<Cuota> cuotas = const [],
]) {
  final esCredito = f.esCredito;
  return DocumentoPdf(
    titulo: f.anulada ? 'FACTURA ANULADA' : 'FACTURA',
    numero: f.numero,
    datos: [
      MapEntry('Fecha', formatoFecha(f.fecha)),
      if (f.ncf != null) MapEntry('NCF', f.ncf!),
      MapEntry(
        'Condición',
        esCredito
            ? 'Crédito (${f.cantidadCuotas} cuotas ${f.frecuenciaPago}es)'
            : 'Al Contado',
      ),
      MapEntry(
        'Estado',
        f.saldada ? 'Saldada / Pagada' : (f.anulada ? 'Anulada' : 'Pendiente'),
      ),
      if (f.cotizacionId != null)
        MapEntry('Cotización', numeroCotizacion(f.cotizacionId!)),
    ],
    clienteNombre: f.clienteNombre,
    clienteDetalle: [
      if (f.clienteDocumento != null) f.clienteDocumento!,
      if (f.clienteTelefono != null) 'Tel. ${f.clienteTelefono}',
      if (f.clienteDireccion != null) f.clienteDireccion!,
    ],
    lineas: lineas,
    totales: Totales(f.subtotal, f.itbis),
    notas: f.notas,
    cuotas: cuotas,
    factura: f,
  );
}
