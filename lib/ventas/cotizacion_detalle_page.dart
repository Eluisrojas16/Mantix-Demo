import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../inventario/dialogos.dart';
import '../models/cliente.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'cotizacion_form_page.dart';
import 'cotizaciones_extra_db.dart';
import 'factura_detalle_page.dart';
import 'factura_form_page.dart';
import 'factura_modelos.dart';
import 'facturas_db.dart';
import 'modelos.dart';
import 'pdf_documentos.dart';
import 'ventas_db.dart';
import 'vista_pdf_page.dart';

class _Datos {
  final Cotizacion cotizacion;
  final Cliente? cliente;
  final List<LineaVenta> lineas;
  final Factura? factura; // la factura que salió de esta cotización, si hay
  _Datos(this.cotizacion, this.cliente, this.lineas, this.factura);
}

/// Vista de una cotización: datos, líneas, totales, cambio de estado, y facturarla.
/// Una cotización facturada ya no se puede modificar.
class CotizacionDetallePage extends StatefulWidget {
  final int cotizacionId;
  const CotizacionDetallePage({super.key, required this.cotizacionId});

  @override
  State<CotizacionDetallePage> createState() => _CotizacionDetallePageState();
}

class _CotizacionDetallePageState extends State<CotizacionDetallePage> {
  late Future<_Datos?> _datos = _cargar();

  Future<_Datos?> _cargar() async {
    final c = await BaseDatos.instancia.obtenerCotizacion(widget.cotizacionId);
    if (c == null) return null;
    final cli = await BaseDatos.instancia.obtenerCliente(c.clienteId);
    final l = await BaseDatos.instancia.listarLineasCotizacion(c.id!);
    final f = c.estado == 'facturada'
        ? await BaseDatos.instancia.facturaDeCotizacion(c.id!)
        : null;
    return _Datos(c, cli, l, f);
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _editar(Cotizacion c) async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => CotizacionFormPage(cotizacion: c)),
    );
    if (id != null) _recargar();
  }

  Future<void> _cambiarEstado(Cotizacion c, String estado) async {
    await BaseDatos.instancia.cambiarEstadoCotizacion(c.id!, estado);
    if (!mounted) return;
    _recargar();
  }

  Future<void> _duplicar(Cotizacion c) async {
    try {
      final nuevoId = await BaseDatos.instancia.duplicarCotizacion(c.id!);
      if (!mounted) return;
      aviso(context, 'Cotización duplicada como borrador.');
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => CotizacionDetallePage(cotizacionId: nuevoId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      aviso(context, 'No se pudo duplicar: $e');
    }
  }

  Future<void> _facturar(Cotizacion c) async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => FacturaFormPage(cotizacion: c)),
    );
    if (id == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FacturaDetallePage(facturaId: id)),
    );
    if (!mounted) return;
    _recargar();
  }

  Future<void> _eliminar(Cotizacion c) async {
    final ok = await confirmar(
      context,
      'Eliminar cotización',
      '¿Eliminar ${c.numero}? Esta acción no se puede deshacer.',
    );
    if (!ok || !mounted) return;
    await BaseDatos.instancia.eliminarCotizacion(c.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _verPdf(_Datos datos) async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    final doc = documentoDeCotizacion(
      datos.cotizacion,
      datos.cliente,
      datos.lineas,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: datos.cotizacion.numero,
          nombreArchivo: '${datos.cotizacion.numero}.pdf',
          generar: () => generarPdfDocumento(
            negocio: negocio,
            logo: negocio.logo,
            doc: doc,
          ),
        ),
      ),
    );
  }

  Widget _fila(IconData icono, String? texto) {
    if (texto == null || texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  Widget _filaTotal(String texto, double valor, {bool fuerte = false}) {
    final estilo = fuerte
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(texto, style: estilo),
          Text(formatoMoneda(valor), style: estilo),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Datos?>(
      future: _datos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        final datos = snap.data;
        if (datos == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Esta cotización ya no existe.')),
          );
        }
        final c = datos.cotizacion;
        final cli = datos.cliente;
        final facturada = c.estado == 'facturada';

        return Scaffold(
          appBar: AppBar(
            title: Text(c.numero),
            actions: [
              IconButton(
                tooltip: 'Ver PDF',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _verPdf(datos),
              ),
              if (!facturada)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editar(c),
                ),
              PopupMenuButton<String>(
                onSelected: (op) {
                  if (op == 'eliminar') {
                    _eliminar(c);
                  } else if (op == 'duplicar') {
                    _duplicar(c);
                  } else {
                    _cambiarEstado(c, op);
                  }
                },
                itemBuilder: (_) => [
                  if (!facturada)
                    for (final k in estadosCotizacionEditables)
                      if (k != c.estado)
                        PopupMenuItem(
                          value: k,
                          child: Text(
                            k == 'borrador'
                                ? 'Volver a borrador'
                                : 'Marcar como ${estadosCotizacion[k]!.toLowerCase()}',
                          ),
                        ),
                  const PopupMenuItem(
                    value: 'duplicar',
                    child: Text('Duplicar como borrador'),
                  ),
                  if (c.estado == 'borrador')
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar'),
                    ),
                ],
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (facturada)
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          datos.factura == null
                              ? 'Esta cotización ya fue facturada'
                              : 'Facturada en ${datos.factura!.numero}',
                        ),
                        subtitle: const Text(
                          'Ya no se puede modificar.',
                        ),
                        trailing: datos.factura == null
                            ? null
                            : TextButton(
                                onPressed: () async {
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => FacturaDetallePage(
                                        facturaId: datos.factura!.id!,
                                      ),
                                    ),
                                  );
                                  if (!mounted) return;
                                  _recargar();
                                },
                                child: const Text('Ver factura'),
                              ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.numero,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  estadosCotizacion[c.estado] ?? c.estado,
                                ),
                              ),
                              if (c.vencida) ...[
                                const SizedBox(width: 8),
                                const Chip(
                                  label: Text('Vencida'),
                                  backgroundColor: Color(0xFFFFCDD2),
                                ),
                              ],
                            ],
                          ),
                          _fila(
                            cli != null && cli.esEmpresa
                                ? Icons.business
                                : Icons.person,
                            c.clienteNombre,
                          ),
                          if (cli != null) ...[
                            _fila(
                              Icons.badge,
                              cli.esEmpresa
                                  ? (cli.rnc == null ? null : 'RNC ${cli.rnc}')
                                  : (cli.cedula == null
                                      ? null
                                      : 'Cédula ${cli.cedula}'),
                            ),
                            _fila(Icons.phone, cli.telefono),
                            _fila(Icons.home, cli.direccion),
                          ],
                          _fila(
                            Icons.event,
                            'Fecha ${formatoFecha(c.fecha)} · '
                            'Válida hasta ${formatoFecha(c.vigenciaHasta)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!facturada && c.estado != 'rechazada') ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _facturar(c),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Facturar esta cotización'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Artículos y conceptos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final l in datos.lineas)
                    Card(
                      child: ListTile(
                        title: Text(l.descripcion),
                        subtitle: Text(
                          '${formatoCantidad(l.cantidad)} ${l.unidad}'
                          ' × ${formatoMoneda(l.precioUnitario)}'
                          '${l.descuentoPct > 0 ? ' · desc. ${formatoCantidad(l.descuentoPct)}%' : ''}'
                          ' · ITBIS ${formatoCantidad(l.itbisPct)}%',
                        ),
                        trailing: Text(
                          formatoMoneda(l.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _filaTotal('Subtotal', c.subtotal),
                          _filaTotal('ITBIS', c.itbis),
                          const Divider(),
                          _filaTotal('Total', c.total, fuerte: true),
                        ],
                      ),
                    ),
                  ),
                  if (c.notas != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Condiciones o notas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(c.notas!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
