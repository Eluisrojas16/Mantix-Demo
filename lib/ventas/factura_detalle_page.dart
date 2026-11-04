import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../inventario/dialogos.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'factura_modelos.dart';
import 'facturas_db.dart';
import 'modelos.dart';
import 'pdf_documentos.dart';
import 'ventas_db.dart';
import 'vista_pdf_page.dart';

class _Datos {
  final Factura factura;
  final List<LineaVenta> lineas;
  final List<Cuota> cuotas;
  _Datos(this.factura, this.lineas, this.cuotas);
}

/// Vista de una factura emitida: datos, financiamiento, cuotas, líneas y acciones.
class FacturaDetallePage extends StatefulWidget {
  final int facturaId;
  const FacturaDetallePage({super.key, required this.facturaId});

  @override
  State<FacturaDetallePage> createState() => _FacturaDetallePageState();
}

class _FacturaDetallePageState extends State<FacturaDetallePage> {
  late Future<_Datos?> _datos = _cargar();

  Future<_Datos?> _cargar() async {
    final f = await BaseDatos.instancia.obtenerFactura(widget.facturaId);
    if (f == null) return null;
    final l = await BaseDatos.instancia.listarLineasFactura(f.id!);
    final c = await BaseDatos.instancia.listarCuotasFactura(f.id!);
    return _Datos(f, l, c);
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _verPdf(_Datos datos) async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    final doc = documentoDeFactura(datos.factura, datos.lineas, datos.cuotas);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: datos.factura.numero,
          nombreArchivo: '${datos.factura.numero}.pdf',
          generar: () => generarPdfDocumento(
            negocio: negocio,
            logo: negocio.logo,
            doc: doc,
          ),
        ),
      ),
    );
  }

  Future<void> _marcarPagadaContado(Factura f) async {
    final ok = await confirmar(
      context,
      'Marcar como pagada',
      '¿Confirmas que la factura ${f.numero} ha sido saldada en su totalidad?',
      textoConfirmar: 'Confirmar pago',
    );
    if (!ok || !mounted) return;
    try {
      await BaseDatos.instancia.marcarFacturaPagada(f.id!);
    } catch (e) {
      if (!mounted) return;
      aviso(context, e is StateError ? e.message : 'No se pudo cobrar: $e');
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _cobrarCuota(Factura f, Cuota c) async {
    final dias = diasHasta(c.fechaVencimiento);
    final estaVencida = !c.pagada && dias != null && dias < 0;
    final moraSugerida = (estaVencida && f.moraPct > 0)
        ? double.parse((c.saldo * (f.moraPct / 100)).toStringAsFixed(2))
        : 0.0;
    var aplicarMora = moraSugerida > 0;
    final montoCtrl = TextEditingController(text: formatoCantidad(c.saldo));
    final notasCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final montoAbono = leerNumero(montoCtrl.text) ?? 0.0;
          final moraFinal = aplicarMora ? moraSugerida : 0.0;
          final totalCobro = montoAbono + moraFinal;
          return AlertDialog(
            title: Text('Abonar a cuota ${c.numero} · ${f.numero}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.clienteNombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Vencimiento: ${formatoFecha(c.fechaVencimiento)} · Saldo cuota: ${formatoMoneda(c.saldo)}'),
                  const Divider(height: 24),
                  TextField(
                    controller: montoCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto a abonar (RD\$) *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (estaVencida) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: aplicarMora,
                            onChanged: (v) {
                              setDialogState(() => aplicarMora = v ?? true);
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Cobrar mora (${formatoCantidad(f.moraPct)}%): + ${formatoMoneda(moraSugerida)}',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a recibir:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        formatoMoneda(totalCobro),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota o referencia (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: montoAbono <= 0 ? null : () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar pago'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmado != true || !mounted) return;
    final abonoFinal = leerNumero(montoCtrl.text) ?? 0.0;
    if (abonoFinal <= 0) return;

    try {
      await BaseDatos.instancia.registrarAbonoFactura(
        facturaId: f.id!,
        montoAbono: abonoFinal,
        moraCobrada: aplicarMora ? moraSugerida : 0.0,
        notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abono de ${formatoMoneda(abonoFinal)} registrado exitosamente.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      _recargar();
    } catch (e) {
      if (!mounted) return;
      aviso(context, e is StateError ? e.message : 'No se pudo registrar el pago: $e');
    }
  }

  Future<void> _asignarNcf(Factura f) async {
    final ncf = await pedirTexto(
      context,
      titulo: 'NCF de ${f.numero}',
      inicial: f.ncf,
      etiqueta: 'NCF (comprobante fiscal)',
      capitalizar: TextCapitalization.characters,
    );
    if (ncf == null || !mounted) return;
    try {
      await BaseDatos.instancia.asignarNcf(f.id!, ncf);
    } catch (e) {
      if (!mounted) return;
      aviso(
        context,
        e is StateError
            ? e.message
            : (e.toString().contains('UNIQUE')
                ? 'Ese NCF ya está registrado en otra factura.'
                : 'No se pudo guardar: $e'),
      );
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Future<void> _anular(Factura f) async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Anular ${f.numero}',
      etiqueta: 'Motivo de la anulación *',
      capitalizar: TextCapitalization.sentences,
    );
    if (motivo == null || motivo.trim().isEmpty || !mounted) return;
    try {
      await BaseDatos.instancia.anularFactura(f.id!, motivo.trim());
    } catch (e) {
      if (!mounted) return;
      aviso(context, e is StateError ? e.message : 'No se pudo anular: $e');
      return;
    }
    if (!mounted) return;
    _recargar();
  }

  Widget _fila(IconData icono, String? texto) {
    if (texto == null || texto.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Colors.grey.shade700),
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
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final datos = snap.data;
        if (datos == null) {
          return const Scaffold(
            body: Center(child: Text('La factura no existe.')),
          );
        }
        final f = datos.factura;

        return Scaffold(
          appBar: AppBar(
            title: Text(f.numero),
            actions: [
              IconButton(
                tooltip: 'Ver PDF',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _verPdf(datos),
              ),
              if (!f.anulada)
                PopupMenuButton<String>(
                  onSelected: (op) {
                    switch (op) {
                      case 'pagada':
                        _marcarPagadaContado(f);
                      case 'ncf':
                        _asignarNcf(f);
                      case 'anular':
                        _anular(f);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!f.saldada && !f.esCredito)
                      const PopupMenuItem(
                        value: 'pagada',
                        child: Text('Marcar como pagada'),
                      ),
                    PopupMenuItem(
                      value: 'ncf',
                      child:
                          Text(f.ncf == null ? 'Asignar NCF' : 'Corregir NCF'),
                    ),
                    const PopupMenuItem(value: 'anular', child: Text('Anular')),
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
                  if (f.anulada)
                    Card(
                      color: const Color(0xFFFFCDD2),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'FACTURA ANULADA'
                          '${f.motivoAnulacion != null ? '\nMotivo: ${f.motivoAnulacion}' : ''}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
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
                                  f.numero,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  f.saldada
                                      ? 'Saldada / Pagada'
                                      : (estadosFactura[f.estado] ?? f.estado),
                                ),
                                backgroundColor: f.saldada
                                    ? Colors.green.shade100
                                    : null,
                              ),
                            ],
                          ),
                          _fila(Icons.person, f.clienteNombre),
                          _fila(Icons.badge, f.clienteDocumento),
                          _fila(Icons.phone, f.clienteTelefono),
                          _fila(Icons.home, f.clienteDireccion),
                          _fila(Icons.event, 'Fecha ${formatoFecha(f.fecha)}'),
                          _fila(
                            Icons.credit_card,
                            'Condición: ${f.esCredito ? 'Crédito (${f.cantidadCuotas} cuotas ${f.frecuenciaPago}es)' : 'Al Contado'}',
                          ),
                          _fila(
                            Icons.confirmation_number_outlined,
                            f.ncf == null ? 'Sin NCF' : 'NCF ${f.ncf}',
                          ),
                          if (f.cotizacionId != null)
                            _fila(
                              Icons.request_quote_outlined,
                              'Generada desde la cotización '
                              '${numeroCotizacion(f.cotizacionId!)}',
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Si es crédito, mostrar plan de financiamiento y cuotas
                  if (f.esCredito) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan de Financiamiento y Cuotas',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Text('Inicial: ${formatoMoneda(f.inicial)}'),
                                Text('Interés: ${formatoCantidad(f.interesPct)}%'),
                                Text('Financiado: ${formatoMoneda(f.totalFinanciado)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Saldo pendiente: ${formatoMoneda(f.saldoPendiente)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: f.saldoPendiente > 0
                                          ? Colors.red.shade800
                                          : Colors.green.shade800,
                                    )),
                              ],
                            ),
                            const Divider(height: 20),
                            for (final cuota in datos.cuotas) ...[
                              Builder(builder: (ctx) {
                                final dias = diasHasta(cuota.fechaVencimiento);
                                final vencida =
                                    !cuota.pagada && dias != null && dias < 0;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Cuota ${cuota.numero} de ${f.cantidadCuotas} · ${formatoMoneda(cuota.monto)}'),
                                  subtitle: Text(
                                    cuota.pagada
                                        ? 'Pagada el ${formatoFecha(cuota.fechaPago)}'
                                        : (cuota.esAbonoParcial
                                            ? 'Abonado: ${formatoMoneda(cuota.montoPagado)} · Restan: ${formatoMoneda(cuota.saldo)} (Vence ${formatoFecha(cuota.fechaVencimiento)})'
                                            : 'Vence el ${formatoFecha(cuota.fechaVencimiento)}'
                                                '${vencida ? ' (vencida hace ${-dias} días)' : ''}'),
                                    style: TextStyle(
                                      color: vencida ? Colors.red.shade800 : null,
                                    ),
                                  ),
                                  trailing: cuota.pagada
                                      ? const Chip(
                                          avatar: Icon(Icons.check, size: 16, color: Colors.green),
                                          label: Text('Saldada'),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: f.anulada ? null : () => _cobrarCuota(f, cuota),
                                          child: Text(cuota.esAbonoParcial ? 'Abonar' : 'Cobrar'),
                                        ),
                                );
                              }),
                              const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
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
                          [
                            '${formatoCantidad(l.cantidad)} ${l.unidad}'
                                ' × ${formatoMoneda(l.precioUnitario)}'
                                '${l.descuentoPct > 0 ? ' · desc. ${formatoCantidad(l.descuentoPct)}%' : ''}'
                                ' · ITBIS ${formatoCantidad(l.itbisPct)}%',
                            if (l.seriales.isNotEmpty)
                              'Serial: ${l.seriales.join(', ')}',
                          ].join('\n'),
                        ),
                        isThreeLine: l.seriales.isNotEmpty,
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
                          _filaTotal('Subtotal', f.subtotal),
                          _filaTotal('ITBIS', f.itbis),
                          const Divider(),
                          _filaTotal('Total Factura', f.total, fuerte: true),
                          if (f.esCredito) ...[
                            _filaTotal('Total Financiado', f.totalFinanciado),
                            _filaTotal('Saldo Pendiente', f.saldoPendiente,
                                fuerte: f.saldoPendiente > 0),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (f.notas != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(f.notas!),
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
