import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../data/mantenimientos_db.dart';
import '../models/mantenimiento.dart';
import '../utils/fechas.dart';

/// Formulario para registrar o editar un mantenimiento de un aire.
class MantenimientoFormPage extends StatefulWidget {
  final int aireId;
  final Mantenimiento? mantenimiento;
  final String? contexto;
  const MantenimientoFormPage({
    super.key,
    required this.aireId,
    this.mantenimiento,
    this.contexto,
  });

  @override
  State<MantenimientoFormPage> createState() => _MantenimientoFormPageState();
}

class _MantenimientoFormPageState extends State<MantenimientoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _fecha =
      deIso(widget.mantenimiento?.fecha) ?? hoySinHora();
  late String _tipo = widget.mantenimiento?.tipo ?? 'preventivo';
  late String _estado = widget.mantenimiento?.estado ?? 'realizado';
  late bool _pagado = widget.mantenimiento?.pagado ?? false;
  late final _trabajo =
      TextEditingController(text: widget.mantenimiento?.trabajoRealizado);
  late final _costo = TextEditingController(
    text: widget.mantenimiento?.costo?.toString() ?? '',
  );
  late final _tecnico =
      TextEditingController(text: widget.mantenimiento?.tecnico);
  bool _guardando = false;

  @override
  void dispose() {
    _trabajo.dispose();
    _costo.dispose();
    _tecnico.dispose();
    super.dispose();
  }

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida != null && mounted) {
      setState(() => _fecha = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_estado == 'realizado' && _fecha.isAfter(hoySinHora())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Un mantenimiento realizado no puede tener fecha futura. '
            'Corrige la fecha o cámbialo a "Programado".',
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    final m = Mantenimiento(
      id: widget.mantenimiento?.id,
      aireId: widget.aireId,
      fecha: aIso(_fecha),
      tipo: _tipo,
      estado: _estado,
      trabajoRealizado: _vacioANulo(_trabajo.text),
      costo: double.tryParse(_costo.text.trim().replaceAll(',', '.')),
      pagado: _pagado,
      tecnico: _vacioANulo(_tecnico.text),
    );

    try {
      await BaseDatos.instancia.guardarMantenimiento(m);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.mantenimiento == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(esNuevo ? 'Registrar mantenimiento' : 'Editar mantenimiento'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.contexto != null) ...[
                  Text(
                    widget.contexto!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                InkWell(
                  onTap: _elegirFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha del mantenimiento *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(formatoFecha(aIso(_fecha))),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in tiposMantenimiento.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    helperText:
                        'Programado: visita agendada, con cuenta regresiva hasta su fecha. '
                        'Realizado: ya se hizo.',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in estadosMantenimiento.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _estado = v ?? _estado),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trabajo,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Trabajo realizado',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costo,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Costo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return double.tryParse(t.replaceAll(',', '.')) == null
                        ? 'Número inválido'
                        : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pagado'),
                  value: _pagado,
                  onChanged: (v) => setState(() => _pagado = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tecnico,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Técnico',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
