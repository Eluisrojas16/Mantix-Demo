import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../usuarios/usuario_modelos.dart';
import '../utils/dinero.dart';
import '../utils/fechas.dart';
import '../ventas/vista_pdf_page.dart';
import '../ventas/ventas_db.dart';
import 'reportes_pdf.dart';

String formatearMonto(double v) => 'RD\$ ${formatoDinero(v)}';

class ReportesPage extends StatefulWidget {
  final Usuario usuario;
  const ReportesPage({super.key, required this.usuario});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Cobros'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Inventario'),
            Tab(icon: Icon(Icons.point_of_sale), text: 'Cierre'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CobrosTab(usuario: widget.usuario),
          _InventarioTab(usuario: widget.usuario),
          _CierreTab(usuario: widget.usuario),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTE DE COBROS
// ─────────────────────────────────────────────────────────────────────────────

class _CobrosTab extends StatefulWidget {
  final Usuario usuario;
  const _CobrosTab({required this.usuario});

  @override
  State<_CobrosTab> createState() => _CobrosTabState();
}

class _CobrosTabState extends State<_CobrosTab> {
  DateTime _desde = DateTime.now().copyWith(day: 1);
  DateTime _hasta = DateTime.now();
  bool _cargando = false;
  List<Map<String, Object?>> _filas = [];
  double _totalCapital = 0;
  double _totalMora = 0;
  double _totalGeneral = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final d = await BaseDatos.instancia.db;
    final desdeStr = aIso(_desde);
    final hastaStr = aIso(_hasta);
    final filas = await d.rawQuery('''
      SELECT
        pa.id,
        pa.fecha,
        pa.fecha_hora,
        pa.monto_capital,
        pa.mora_cobrada,
        pa.monto_total,
        pa.metodo_pago,
        pa.referencia,
        pa.banco,
        pa.voucher,
        pa.notas,
        pa.usuario_nombre,
        f.cliente_nombre
      FROM pago_abono pa
      JOIN factura f ON f.id = pa.factura_id
      WHERE pa.fecha >= ? AND pa.fecha <= ?
      ORDER BY pa.fecha_hora DESC
    ''', [desdeStr, hastaStr]);

    double cap = 0, mora = 0, total = 0;
    for (final r in filas) {
      cap   += (r['monto_capital']  as num?)?.toDouble() ?? 0;
      mora  += (r['mora_cobrada']   as num?)?.toDouble() ?? 0;
      total += (r['monto_total']    as num?)?.toDouble() ?? 0;
    }

    setState(() {
      _filas = filas;
      _totalCapital = cap;
      _totalMora = mora;
      _totalGeneral = total;
      _cargando = false;
    });
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = picked;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
    _cargar();
  }

  Future<void> _verPdf() async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: 'Reporte de cobros',
          nombreArchivo:
              'reporte_cobros_${aIso(_desde)}_al_${aIso(_hasta)}.pdf',
          generar: () => generarPdfReporteCobros(
            negocio: negocio,
            desde: _desde,
            hasta: _hasta,
            filas: _filas,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // ── Filtros ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _FechaBoton(
                  label: 'Desde',
                  fecha: _desde,
                  onTap: () => _elegirFecha(esDesde: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FechaBoton(
                  label: 'Hasta',
                  fecha: _hasta,
                  onTap: () => _elegirFecha(esDesde: false),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
              IconButton(
                tooltip: 'Exportar PDF',
                onPressed: _filas.isEmpty ? null : _verPdf,
                icon: const Icon(Icons.picture_as_pdf),
              ),
            ],
          ),
        ),

        // ── Totales ──────────────────────────────────────────────────────
        if (!_cargando)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _Cifra(label: 'Capital', valor: _totalCapital),
                    const Spacer(),
                    _Cifra(label: 'Mora', valor: _totalMora),
                    const Spacer(),
                    _Cifra(
                      label: 'Total cobrado',
                      valor: _totalGeneral,
                      negrita: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Lista ────────────────────────────────────────────────────────
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _filas.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin cobros en el período seleccionado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _filas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _TarjetaCobro(fila: _filas[i]),
                    ),
        ),
      ],
    );
  }
}

class _TarjetaCobro extends StatelessWidget {
  final Map<String, Object?> fila;
  const _TarjetaCobro({required this.fila});

  @override
  Widget build(BuildContext context) {
    final monto      = (fila['monto_total']   as num?)?.toDouble() ?? 0;
    final mora       = (fila['mora_cobrada']  as num?)?.toDouble() ?? 0;
    final metodo     = fila['metodo_pago']    as String? ?? '';
    final banco      = fila['banco']          as String?;
    final voucher    = fila['voucher']        as String?;
    final notas      = fila['notas']          as String?;
    final usuario    = fila['usuario_nombre'] as String? ?? 'Admin';
    final cliente    = fila['cliente_nombre'] as String? ?? '';
    final fecha      = fila['fecha']          as String? ?? '';
    final ref        = fila['referencia']     as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cliente,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatearMonto(monto),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Etiqueta(fecha),
                _Etiqueta('Por: $usuario'),
                _Etiqueta(metodo),
                if (banco != null && banco.isNotEmpty) _Etiqueta('🏦 $banco'),
                if (voucher != null && voucher.isNotEmpty)
                  _Etiqueta('Voucher: $voucher'),
                if (ref != null && ref.isNotEmpty) _Etiqueta('Ref: $ref'),
                if (mora > 0) _Etiqueta('Mora: ${formatearMonto(mora)}', rojo: true),
              ],
            ),
            if (notas != null && notas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Nota: $notas',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTE DE INVENTARIO
// ─────────────────────────────────────────────────────────────────────────────

class _InventarioTab extends StatefulWidget {
  final Usuario usuario;
  const _InventarioTab({required this.usuario});

  @override
  State<_InventarioTab> createState() => _InventarioTabState();
}

class _InventarioTabState extends State<_InventarioTab> {
  DateTime _desde = DateTime.now().copyWith(day: 1);
  DateTime _hasta = DateTime.now();
  bool _cargando = false;
  List<Map<String, Object?>> _filas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final d = await BaseDatos.instancia.db;
    final desdeStr = aIso(_desde);
    final hastaStr = aIso(_hasta);
    final filas = await d.rawQuery('''
      SELECT
        m.id,
        m.fecha,
        m.tipo,
        m.cantidad,
        m.origen   AS motivo,
        m.referencia,
        m.nota     AS notas,
        m.usuario_nombre,
        p.nombre   AS producto_nombre,
        p.codigo   AS producto_codigo
      FROM movimiento_inventario m
      JOIN producto p ON p.id = m.producto_id
      WHERE m.fecha >= ? AND m.fecha <= ?
      ORDER BY m.fecha DESC, m.id DESC
    ''', [desdeStr, hastaStr]);
    setState(() {
      _filas = filas;
      _cargando = false;
    });
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = picked;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
    _cargar();
  }

  Future<void> _verPdf() async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: 'Reporte de inventario',
          nombreArchivo:
              'reporte_inventario_${aIso(_desde)}_al_${aIso(_hasta)}.pdf',
          generar: () => generarPdfReporteInventario(
            negocio: negocio,
            desde: _desde,
            hasta: _hasta,
            filas: _filas,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _FechaBoton(
                  label: 'Desde',
                  fecha: _desde,
                  onTap: () => _elegirFecha(esDesde: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FechaBoton(
                  label: 'Hasta',
                  fecha: _hasta,
                  onTap: () => _elegirFecha(esDesde: false),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
              IconButton(
                tooltip: 'Exportar PDF',
                onPressed: _filas.isEmpty ? null : _verPdf,
                icon: const Icon(Icons.picture_as_pdf),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _filas.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin movimientos en el período seleccionado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _filas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _TarjetaMovimiento(fila: _filas[i]),
                    ),
        ),
      ],
    );
  }
}

class _TarjetaMovimiento extends StatelessWidget {
  final Map<String, Object?> fila;
  const _TarjetaMovimiento({required this.fila});

  @override
  Widget build(BuildContext context) {
    final tipo      = fila['tipo']             as String? ?? '';
    final cantidad  = (fila['cantidad'] as num?)?.toDouble() ?? 0;
    final fecha     = fila['fecha']            as String? ?? '';
    final producto  = fila['producto_nombre']  as String? ?? '';
    final codigo    = fila['producto_codigo']  as String?;
    final motivo    = fila['motivo']           as String?;
    final ref       = fila['referencia']       as String?;
    final notas     = fila['notas']            as String?;
    final usuario   = fila['usuario_nombre']   as String?;
    final esEntrada = tipo == 'entrada';
    final color     = esEntrada ? Colors.green.shade700 : Colors.red.shade700;
    final signo     = esEntrada ? '+' : '-';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esEntrada
              ? Colors.green.shade50
              : Colors.red.shade50,
          child: Icon(
            esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(producto, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (codigo != null && codigo.isNotEmpty) Text('Código: $codigo'),
            if (motivo != null && motivo.isNotEmpty) Text(motivo),
            if (ref != null && ref.isNotEmpty) Text('Ref: $ref'),
            if (notas != null && notas.isNotEmpty)
              Text(notas, style: const TextStyle(fontStyle: FontStyle.italic)),
            Text('Por: ${usuario ?? 'Admin'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$signo${cantidad % 1 == 0 ? cantidad.toInt() : cantidad}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(fecha, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIERRE DE CAJA
// ─────────────────────────────────────────────────────────────────────────────

/// Un día de cobros agrupados por el usuario que los hizo: quién cobró,
/// a qué clientes con qué montos y por dónde entró el dinero (banco/voucher).
class _CierreTab extends StatefulWidget {
  final Usuario usuario;
  const _CierreTab({required this.usuario});

  @override
  State<_CierreTab> createState() => _CierreTabState();
}

class _CierreTabState extends State<_CierreTab> {
  late DateTime _fecha;
  bool _cargando = false;
  List<Map<String, Object?>> _filas = [];
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime.now();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final d = await BaseDatos.instancia.db;
    final filas = await d.rawQuery('''
      SELECT
        pa.id,
        pa.fecha,
        pa.fecha_hora,
        pa.monto_capital,
        pa.mora_cobrada,
        pa.monto_total,
        pa.metodo_pago,
        pa.referencia,
        pa.banco,
        pa.voucher,
        pa.notas,
        pa.usuario_nombre,
        f.cliente_nombre
      FROM pago_abono pa
      JOIN factura f ON f.id = pa.factura_id
      WHERE pa.fecha = ?
      ORDER BY pa.usuario_nombre COLLATE NOCASE,
               pa.fecha_hora ASC
    ''', [aIso(_fecha)]);

    double t = 0;
    for (final r in filas) {
      t += (r['monto_total'] as num?)?.toDouble() ?? 0;
    }
    setState(() {
      _filas = filas;
      _total = t;
      _cargando = false;
    });
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _fecha = picked);
    _cargar();
  }

  /// Cobros del día agrupados por el usuario que los hizo.
  Map<String, List<Map<String, Object?>>> get _porUsuario {
    final grupos = <String, List<Map<String, Object?>>>{};
    for (final f in _filas) {
      final u = (f['usuario_nombre'] as String?)?.trim();
      grupos.putIfAbsent(
          u == null || u.isEmpty ? 'Admin' : u, () => []).add(f);
    }
    return grupos;
  }

  Future<void> _verPdf() async {
    final negocio = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: 'Cierre de caja',
          nombreArchivo: 'cierre_caja_${aIso(_fecha)}.pdf',
          generar: () => generarPdfCierreCaja(
            negocio: negocio,
            fecha: _fecha,
            grupos: _porUsuario,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grupos = _porUsuario;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _FechaBoton(
                  label: 'Fecha',
                  fecha: _fecha,
                  onTap: _elegirFecha,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
              IconButton(
                tooltip: 'Exportar PDF',
                onPressed: _filas.isEmpty ? null : _verPdf,
                icon: const Icon(Icons.picture_as_pdf),
              ),
            ],
          ),
        ),

        // ── Total del día ────────────────────────────────────────────────
        if (!_cargando)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Cobrado el ${aIso(_fecha)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total del día',
                            style: TextStyle(fontSize: 11)),
                        Text(
                          formatearMonto(_total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Cobros agrupados por usuario ─────────────────────────────────
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _filas.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin cobros ese día.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: [
                        for (final e in grupos.entries) ...[
                          _CabeceraUsuario(
                            nombre: e.key,
                            total: [for (final f in e.value) f]
                                .fold<double>(
                              0,
                              (t, f) =>
                                  t +
                                  ((f['monto_total'] as num?)?.toDouble() ??
                                      0),
                            ),
                          ),
                          for (final f in e.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _TarjetaCobro(fila: f),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

class _CabeceraUsuario extends StatelessWidget {
  final String nombre;
  final double total;
  const _CabeceraUsuario({required this.nombre, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          formatearMonto(total),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares compartidos
// ─────────────────────────────────────────────────────────────────────────────

class _FechaBoton extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final VoidCallback onTap;
  const _FechaBoton({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text('$label: ${aIso(fecha)}', overflow: TextOverflow.ellipsis),
    );
  }
}

class _Cifra extends StatelessWidget {
  final String label;
  final double valor;
  final bool negrita;
  const _Cifra({required this.label, required this.valor, this.negrita = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          formatearMonto(valor),
          style: TextStyle(
            fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
            fontSize: negrita ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool rojo;
  const _Etiqueta(this.texto, {this.rojo = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(texto, style: TextStyle(fontSize: 11, color: rojo ? Colors.red : null)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: rojo ? Colors.red.shade50 : null,
    );
  }
}
