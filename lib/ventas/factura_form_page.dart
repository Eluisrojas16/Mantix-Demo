import 'package:flutter/material.dart';

import '../data/aires_db.dart';
import '../data/base_datos.dart';
import '../inventario/dialogos.dart';
import '../inventario/inventario_db.dart';
import '../inventario/layout.dart';
import '../inventario/modelos.dart' show ProductoConStock, Unidad;
import '../inventario/seleccionar_seriales_page.dart';
import '../models/cliente.dart';
import '../utils/dinero.dart';
import '../utils/fechas.dart';
import '../utils/numeros.dart';
import 'factura_modelos.dart';
import 'facturas_db.dart';
import 'linea_dialogo.dart';
import 'modelos.dart';
import 'seleccionar_cliente_page.dart';
import 'seleccionar_producto_page.dart';
import 'ventas_db.dart';

/// Formulario para emitir una factura: nueva, o a partir de una cotización.
/// Al emitirla devuelve su id.
class FacturaFormPage extends StatefulWidget {
  final Cotizacion? cotizacion;
  const FacturaFormPage({super.key, this.cotizacion});

  @override
  State<FacturaFormPage> createState() => _FacturaFormPageState();
}

class _FacturaFormPageState extends State<FacturaFormPage> {
  Negocio _negocio = const Negocio(nombre: '');
  Cliente? _cliente;
  DateTime _fecha = hoySinHora();
  List<LineaVenta> _lineas = [];
  final Map<int, ProductoConStock> _prod = {};
  final _ncf = TextEditingController();
  final _notas = TextEditingController();

  // Condiciones de venta
  String _condicionVenta = 'contado'; // 'contado', 'credito'
  bool _pagada = true; // Para contado: ¿pagada de inmediato?

  // Datos de crédito y cuotas
  String _frecuencia = 'mensual'; // 'semanal', 'quincenal', 'mensual'
  final _cuotas = TextEditingController(text: '6');
  final _inicial = TextEditingController(text: '0');
  final _interes = TextEditingController(text: '0');
  final _mora = TextEditingController(text: '5');

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ncf.dispose();
    _notas.dispose();
    _cuotas.dispose();
    _inicial.dispose();
    _interes.dispose();
    _mora.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    final q = widget.cotizacion;
    Cliente? cliente;
    var lineas = <LineaVenta>[];
    if (q != null) {
      cliente = await BaseDatos.instancia.obtenerCliente(q.clienteId);
      lineas = await BaseDatos.instancia.listarLineasCotizacion(q.id!);
    }
    for (final l in lineas) {
      await _cargarProducto(l.productoId);
    }
    if (!mounted) return;
    setState(() {
      _negocio = negocio;
      _cliente = cliente;
      _lineas = lineas;
      _notas.text = q?.notas ?? '';
      _cargando = false;
    });
  }

  Future<void> _cargarProducto(int? id) async {
    if (id == null) return;
    final p = await BaseDatos.instancia.obtenerProducto(id);
    if (p != null) _prod[id] = p;
  }

  void _aviso(String texto) => aviso(context, texto);

  // ------------------------------------------------------------ qué pide cada línea

  bool _usaSerial(LineaVenta l) =>
      l.productoId != null &&
      (_prod[l.productoId]?.producto.usaSerial ?? false);

  /// Producto que se controla por cantidad (no por serial).
  bool _controlaCantidad(LineaVenta l) {
    final p = l.productoId == null ? null : _prod[l.productoId];
    return p != null && p.producto.controlaExistencia && !p.producto.usaSerial;
  }

  double _pedido(int productoId) => _lineas
      .where((l) => l.productoId == productoId)
      .fold<double>(0, (s, l) => s + l.cantidad);

  // ------------------------------------------------------------ selección

  Future<void> _elegirCliente() async {
    final c = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (_) => const SeleccionarClientePage()),
    );
    if (c == null || !mounted) return;
    setState(() => _cliente = c);
  }

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (f == null || !mounted) return;
    setState(() => _fecha = f);
  }

  Future<void> _agregarProducto() async {
    final sel = await Navigator.of(context).push<ProductoConStock>(
      MaterialPageRoute(builder: (_) => const SeleccionarProductoPage()),
    );
    if (sel == null || !mounted) return;
    final p = sel.producto;
    final detalle =
        [p.marcaNombre, p.modeloNombre].whereType<String>().join(' ');
    _prod[p.id!] = sel;
    final linea = await editarLinea(
      context,
      LineaVenta(
        productoId: p.id,
        descripcion: detalle.isEmpty ? p.nombre : '${p.nombre} · $detalle',
        unidad: p.unidad,
        precioUnitario: p.precioVenta ?? 0,
        itbisPct: _negocio.itbisPorcentaje,
      ),
    );
    if (linea == null || !mounted) return;
    setState(() => _lineas = [..._lineas, linea]);
  }

  Future<void> _agregarConcepto() async {
    final linea = await editarLinea(
      context,
      LineaVenta(
        descripcion: '',
        itbisPct: _negocio.itbisPorcentaje,
      ),
    );
    if (linea == null || !mounted) return;
    setState(() => _lineas = [..._lineas, linea]);
  }

  Future<void> _editarLinea(int i) async {
    final anterior = _lineas[i];
    final editada = await editarLinea(context, anterior);
    if (editada == null || !mounted) return;
    setState(() {
      final copia = [..._lineas];
      copia[i] = _usaSerial(anterior) &&
              editada.cantidad.round() != anterior.cantidad.round()
          ? editada.conSeriales(const [], const [])
          : editada.conSeriales(anterior.unidadIds, anterior.seriales);
      _lineas = copia;
    });
  }

  void _eliminarLinea(int i) {
    setState(() {
      final copia = [..._lineas];
      copia.removeAt(i);
      _lineas = copia;
    });
  }

  Future<void> _elegirSeriales(int i) async {
    final l = _lineas[i];
    final otros = <int>{};
    for (var k = 0; k < _lineas.length; k++) {
      if (k != i) otros.addAll(_lineas[k].unidadIds);
    }
    final elegidas = await Navigator.of(context).push<List<Unidad>>(
      MaterialPageRoute(
        builder: (_) => SeleccionarSerialesPage(
          productoId: l.productoId!,
          nombre: l.descripcion,
          cantidad: l.cantidad.round(),
          preseleccion: l.unidadIds.toSet(),
          excluir: otros,
        ),
      ),
    );
    if (elegidas == null || !mounted) return;
    setState(() {
      final copia = [..._lineas];
      copia[i] = l.conSeriales(
        [for (final u in elegidas) u.id],
        [for (final u in elegidas) u.serial],
      );
      _lineas = copia;
    });
  }

  // ------------------------------------------------------------ emitir

  Future<void> _emitir() async {
    final cli = _cliente;
    if (cli == null) {
      _aviso('Elige un cliente.');
      return;
    }
    if (_lineas.isEmpty) {
      _aviso('Agrega al menos un artículo o concepto.');
      return;
    }
    for (final l in _lineas) {
      if (_usaSerial(l) && l.unidadIds.length != l.cantidad.round()) {
        _aviso('"${l.descripcion}": elige ${l.cantidad.round()} número(s) de serie.');
        return;
      }
    }
    final q = widget.cotizacion;
    final esCredito = _condicionVenta == 'credito';
    final ok = await confirmar(
      context,
      'Emitir factura',
      'Al emitirla se descuenta el inventario'
      '${esCredito ? ' y se genera el plan de cuotas en Cobranzas' : ''}'
      '${q != null ? ' y la cotización ${q.numero} queda bloqueada' : ''}. '
      'La factura no se podrá modificar, solo anular. ¿Emitir?',
      textoConfirmar: 'Emitir',
    );
    if (!ok || !mounted) return;

    setState(() => _guardando = true);
    final ncf = _ncf.text.trim();
    final notas = _notas.text.trim();

    final totales = Totales.de(_lineas);
    final inicialVal = (leerNumero(_inicial.text) ?? 0.0).clamp(0, totales.total).toDouble();
    final cuotasVal = (int.tryParse(_cuotas.text.trim()) ?? 1).clamp(1, 120);
    final interesVal = (leerNumero(_interes.text) ?? 0.0).clamp(0, 1000).toDouble();
    final moraVal = (leerNumero(_mora.text) ?? 5.0).clamp(0, 100).toDouble();

    final factura = Factura(
      clienteId: cli.id!,
      cotizacionId: q?.id,
      fecha: aIso(_fecha),
      ncf: ncf.isEmpty ? null : ncf,
      estado: (!esCredito && _pagada) ? 'pagada' : 'emitida',
      formaPago: (!esCredito && _pagada) ? 'Contado' : null,
      fechaPago: (!esCredito && _pagada) ? aIso(_fecha) : null,
      clienteNombre: cli.nombreApellido,
      clienteDocumento: cli.esEmpresa
          ? (cli.rnc == null ? null : 'RNC ${cli.rnc}')
          : (cli.cedula == null ? null : 'Cédula ${cli.cedula}'),
      clienteTelefono: cli.telefono,
      clienteDireccion: cli.direccion,
      notas: notas.isEmpty ? null : notas,
      condicionVenta: _condicionVenta,
      inicial: esCredito ? inicialVal : 0.0,
      interesPct: esCredito ? interesVal : 0.0,
      frecuenciaPago: esCredito ? _frecuencia : 'mensual',
      cantidadCuotas: esCredito ? cuotasVal : 1,
      moraPct: esCredito ? moraVal : 0.0,
    );
    try {
      final id = await BaseDatos.instancia.emitirFactura(factura, _lineas);
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(
        e is StateError
            ? e.message
            : (e.toString().contains('UNIQUE')
                ? 'Ese NCF ya está registrado en otra factura.'
                : 'No se pudo emitir: $e'),
      );
    }
  }

  // ------------------------------------------------------------ pantalla

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

  Widget _tarjetaLinea(int i) {
    final l = _lineas[i];
    final pid = l.productoId;
    final extra = <Widget>[];

    if (_usaSerial(l)) {
      final necesarios = l.cantidad.round();
      final completos = l.unidadIds.length == necesarios;
      extra.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l.seriales.isEmpty
                      ? 'Faltan los números de serie ($necesarios)'
                      : 'Seriales (${l.unidadIds.length} de $necesarios): '
                          '${l.seriales.join(', ')}',
                  style: TextStyle(color: completos ? null : Colors.orange),
                ),
              ),
              TextButton.icon(
                onPressed: () => _elegirSeriales(i),
                icon: const Icon(Icons.pin_outlined),
                label: Text(completos ? 'Cambiar' : 'Elegir seriales'),
              ),
            ],
          ),
        ),
      );
    } else if (_controlaCantidad(l) && pid != null) {
      final hay = _prod[pid]!.stock;
      final pide = _pedido(pid);
      final falta = pide > hay + 0.000001;
      extra.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Existencia: ${formatoCantidad(hay)} ${l.unidad}'
            '${falta ? ' · no alcanza para ${formatoCantidad(pide)}' : ''}',
            style: TextStyle(color: falta ? Colors.red : null),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(l.descripcion),
            subtitle: Text(
              '${formatoCantidad(l.cantidad)} ${l.unidad} × '
              '${formatoMoneda(l.precioUnitario)}'
              '${l.descuentoPct > 0 ? ' · desc. ${formatoCantidad(l.descuentoPct)}%' : ''}'
              ' · ITBIS ${formatoCantidad(l.itbisPct)}%',
            ),
            trailing: Text(
              formatoMoneda(l.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...extra,
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _editarLinea(i),
                child: const Text('Editar'),
              ),
              TextButton(
                onPressed: () => _eliminarLinea(i),
                child: const Text('Quitar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cli = _cliente;
    final q = widget.cotizacion;
    final totales = Totales.de(_lineas);

    final esCredito = _condicionVenta == 'credito';
    final inicialVal = (leerNumero(_inicial.text) ?? 0.0).clamp(0, totales.total).toDouble();
    final capitalVal = (totales.total - inicialVal).clamp(0, double.infinity).toDouble();
    final interesVal = (leerNumero(_interes.text) ?? 0.0).clamp(0, 1000).toDouble();
    final interesMonto = redondear2(capitalVal * (interesVal / 100));
    final totalFinanciado = redondear2(capitalVal + interesMonto);
    final cuotasVal = (int.tryParse(_cuotas.text.trim()) ?? 1).clamp(1, 120);
    final cuotaMonto = cuotasVal > 0 ? redondear2(totalFinanciado / cuotasVal) : 0.0;
    final moraPctVal = (leerNumero(_mora.text) ?? 5.0).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          q != null ? 'Facturar ${q.numero}' : 'Nueva factura',
        ),
      ),
      body: _lineas.isEmpty && _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: ListTile(
                          leading: Icon(
                            cli == null
                                ? Icons.person_add_outlined
                                : (cli.esEmpresa
                                    ? Icons.business
                                    : Icons.person),
                          ),
                          title: Text(
                            cli == null
                                ? 'Seleccionar cliente *'
                                : cli.nombreApellido,
                            style: TextStyle(
                              fontWeight:
                                  cli == null ? null : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            cli == null
                                ? 'Obligatorio'
                                : [
                                    if (cli.esEmpresa && cli.rnc != null)
                                      'RNC ${cli.rnc}',
                                    if (!cli.esEmpresa && cli.cedula != null)
                                      'Cédula ${cli.cedula}',
                                    if (cli.telefono != null) cli.telefono!,
                                  ].join(' · '),
                          ),
                          trailing: q != null
                              ? null
                              : FilledButton.tonal(
                                  onPressed: _elegirCliente,
                                  child: Text(cli == null ? 'Elegir' : 'Cambiar'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CamposResponsivos(
                        hijos: [
                          InkWell(
                            onTap: _elegirFecha,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha de la factura',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(formatoFecha(aIso(_fecha))),
                            ),
                          ),
                          TextField(
                            controller: _ncf,
                            decoration: const InputDecoration(
                              labelText: 'NCF (comprobante fiscal)',
                              helperText: 'Opcional. No se puede repetir.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          CampoCompleto(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Condición de venta',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'contado',
                                      label: Text('Al Contado'),
                                      icon: Icon(Icons.attach_money),
                                    ),
                                    ButtonSegment(
                                      value: 'credito',
                                      label: Text('A Crédito / Financiado'),
                                      icon: Icon(Icons.credit_score),
                                    ),
                                  ],
                                  selected: {_condicionVenta},
                                  onSelectionChanged: (s) =>
                                      setState(() => _condicionVenta = s.first),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                          if (!esCredito)
                            CampoCompleto(
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Pagada al emitir'),
                                subtitle: const Text(
                                  'Si se desmarca, queda pendiente de pago y aparecerá en Cobranzas.',
                                ),
                                value: _pagada,
                                onChanged: (v) => setState(() => _pagada = v),
                              ),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: _frecuencia,
                              decoration: const InputDecoration(
                                labelText: 'Frecuencia de cuotas',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'semanal',
                                    child: Text('Semanal (cada 7 días)')),
                                DropdownMenuItem(
                                    value: 'quincenal',
                                    child: Text('Quincenal (cada 15 días)')),
                                DropdownMenuItem(
                                    value: 'mensual',
                                    child: Text('Mensual (cada 30 días)')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _frecuencia = v ?? 'mensual'),
                            ),
                            TextField(
                              controller: _cuotas,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cantidad de cuotas',
                                hintText: 'Ej. 6',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            TextField(
                              controller: _inicial,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Inicial recibido (RD\$)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            TextField(
                              controller: _interes,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Interés de financiamiento (%)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            TextField(
                              controller: _mora,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Recargo por mora (% en atraso)',
                                hintText: '5',
                                helperText:
                                    'Se aplica si una cuota vence sin pagar.',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            CampoCompleto(
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.4),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Plan de financiamiento propuesto',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '• Total factura: ${formatoMoneda(totales.total)}\n'
                                        '• Inicial: - ${formatoMoneda(inicialVal)}\n'
                                        '• Capital a financiar: ${formatoMoneda(capitalVal)}\n'
                                        '• Interés ($interesVal%): + ${formatoMoneda(interesMonto)}\n'
                                        '• Total financiado: ${formatoMoneda(totalFinanciado)}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Divider(height: 16),
                                      Text(
                                        '$cuotasVal cuotas de ${formatoMoneda(cuotaMonto)} ($_frecuencia)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      Text(
                                        '1ª cuota vence el ${formatoFecha(aIso(calcularVencimientoCuota(_fecha, _frecuencia, 1)))}; '
                                        'última vence el ${formatoFecha(aIso(calcularVencimientoCuota(_fecha, _frecuencia, cuotasVal)))}.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700),
                                      ),
                                      if (moraPctVal > 0)
                                        Text(
                                          'Mora en caso de atraso: ${formatoCantidad(moraPctVal)}% sobre la cuota vencida.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade800),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Artículos y conceptos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _agregarProducto,
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Agregar artículo'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _agregarConcepto,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Agregar concepto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_lineas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Todavía no hay líneas. Un concepto sirve para '
                              'mano de obra, instalación u otros cobros sin inventario.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      for (var i = 0; i < _lineas.length; i++) _tarjetaLinea(i),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _filaTotal('Subtotal', totales.subtotal),
                              _filaTotal('ITBIS', totales.itbis),
                              const Divider(),
                              _filaTotal('Total', totales.total, fuerte: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notas,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _emitir,
                        icon: const Icon(Icons.receipt_long),
                        label:
                            Text(_guardando ? 'Emitiendo...' : 'Emitir factura'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
