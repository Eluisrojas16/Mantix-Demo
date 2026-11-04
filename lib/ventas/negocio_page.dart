import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/base_datos.dart';
import '../inventario/layout.dart';
import '../utils/numeros.dart';
import 'logo.dart';
import 'modelos.dart';
import 'pdf_documentos.dart';
import 'ventas_db.dart';
import 'vista_pdf_page.dart';

/// Datos del negocio y logo: aparecen en las cotizaciones y facturas.
class NegocioPage extends StatefulWidget {
  const NegocioPage({super.key});

  @override
  State<NegocioPage> createState() => _NegocioPageState();
}

class _NegocioPageState extends State<NegocioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _rnc = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _itbis = TextEditingController();
  final _vigencia = TextEditingController();
  final _condiciones = TextEditingController();
  Uint8List? _logo;
  String? _avisoLogo;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _rnc,
      _direccion,
      _telefono,
      _correo,
      _itbis,
      _vigencia,
      _condiciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final n = await BaseDatos.instancia.obtenerNegocio();
    if (!mounted) return;
    setState(() {
      _nombre.text = n.nombre;
      _rnc.text = n.rnc ?? '';
      _direccion.text = n.direccion ?? '';
      _telefono.text = n.telefono ?? '';
      _correo.text = n.correo ?? '';
      _itbis.text = formatoCantidad(n.itbisPorcentaje);
      _vigencia.text = n.vigenciaDias.toString();
      _condiciones.text = n.condiciones ?? '';
      _logo = n.logo;
      _cargando = false;
    });
  }

  String? _vacioANulo(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Los datos tal como están ahora en el formulario (sin guardar todavía).
  Negocio _negocioActual() => Negocio(
        nombre: _nombre.text.trim().isEmpty
            ? 'Nombre del negocio'
            : _nombre.text.trim(),
        rnc: _vacioANulo(_rnc.text.replaceAll(RegExp(r'\D'), '')),
        direccion: _vacioANulo(_direccion.text),
        telefono: _vacioANulo(_telefono.text),
        correo: _vacioANulo(_correo.text),
        itbisPorcentaje: leerNumero(_itbis.text) ?? 18,
        vigenciaDias: int.tryParse(_vigencia.text.trim()) ?? 15,
        condiciones: _vacioANulo(_condiciones.text),
        logo: _logo,
      );

  // ------------------------------------------------------------ logo

  Future<void> _elegirLogo() async {
    try {
      // file_picker 13: pickFile() devuelve el archivo elegido (o null si se cancela)
      final archivo = await FilePicker.pickFile(type: FileType.image);
      if (archivo == null) return;
      final Uint8List bytes = await archivo.readAsBytes();
      final preparado = prepararLogo(bytes);
      if (!mounted) return;
      if (preparado == null) {
        _aviso('No se pudo leer la imagen. Usa un archivo PNG o JPG.');
        return;
      }
      setState(() {
        _logo = preparado.bytes;
        _avisoLogo = preparado.advertencia;
      });
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo abrir el selector de archivos: $e');
    }
  }

  void _quitarLogo() {
    setState(() {
      _logo = null;
      _avisoLogo = null;
    });
  }

  Future<void> _verHojaEjemplo() async {
    final negocio = _negocioActual();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VistaPdfPage(
          titulo: 'Hoja de ejemplo',
          nombreArchivo: 'ejemplo.pdf',
          generar: () => generarPdfDocumento(
            negocio: negocio,
            logo: negocio.logo,
            doc: documentoDeEjemplo(),
          ),
        ),
      ),
    );
  }

  /// Imita el encabezado del PDF: el logo arriba y los datos del negocio debajo.
  Widget _vistaEncabezado() {
    return ListenableBuilder(
      listenable:
          Listenable.merge([_nombre, _rnc, _direccion, _telefono, _correo]),
      builder: (context, _) {
        final lineas = [
          if (_rnc.text.trim().isNotEmpty) 'RNC ${_rnc.text.trim()}',
          if (_direccion.text.trim().isNotEmpty) _direccion.text.trim(),
          if (_telefono.text.trim().isNotEmpty) 'Tel. ${_telefono.text.trim()}',
          if (_correo.text.trim().isNotEmpty) _correo.text.trim(),
        ];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_logo != null) ...[
                SizedBox(
                  width: logoAncho,
                  height: logoAlto,
                  child: Image.memory(
                    _logo!,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _nombre.text.trim().isEmpty
                    ? 'Nombre del negocio'
                    : _nombre.text.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              for (final l in lineas)
                Text(l, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ guardar

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await BaseDatos.instancia.guardarNegocio(_negocioActual());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del negocio guardados.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo guardar: $e');
    }
  }

  Widget _texto(
    TextEditingController c,
    String etiqueta, {
    String? ayuda,
    TextInputType? teclado,
    int maxLineas = 1,
    TextCapitalization capitalizar = TextCapitalization.none,
    String? Function(String?)? validar,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: teclado,
      maxLines: maxLineas,
      textCapitalization: capitalizar,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        border: const OutlineInputBorder(),
      ),
      validator: validar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del negocio')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      CamposResponsivos(
                        hijos: [
                          const TituloSeccion('Identificación'),
                          _texto(
                            _nombre,
                            'Nombre del negocio *',
                            capitalizar: TextCapitalization.words,
                            validar: (v) => (v == null || v.trim().isEmpty)
                                ? 'El nombre es obligatorio'
                                : null,
                          ),
                          _texto(
                            _rnc,
                            'RNC',
                            teclado: TextInputType.number,
                            ayuda: 'Con o sin guiones',
                          ),
                          _texto(
                            _direccion,
                            'Dirección',
                            capitalizar: TextCapitalization.sentences,
                          ),
                          _texto(
                            _telefono,
                            'Teléfono',
                            teclado: TextInputType.phone,
                          ),
                          _texto(
                            _correo,
                            'Correo electrónico',
                            teclado: TextInputType.emailAddress,
                          ),
                          const TituloSeccion('Logo'),
                          CampoCompleto(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: _elegirLogo,
                                      icon: const Icon(Icons.image_outlined),
                                      label: Text(
                                        _logo == null
                                            ? 'Elegir logo'
                                            : 'Cambiar logo',
                                      ),
                                    ),
                                    if (_logo != null)
                                      TextButton.icon(
                                        onPressed: _quitarLogo,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Quitar logo'),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: _verHojaEjemplo,
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      label: const Text('Ver hoja de ejemplo'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Usa PNG o JPG, de preferencia con fondo '
                                  'transparente o blanco y de al menos 600 px de '
                                  'ancho. El logo se ajusta a un recuadro fijo '
                                  'sin deformarse.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (_avisoLogo != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber,
                                        color: Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _avisoLogo!,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Text('Así se verá el encabezado:'),
                                const SizedBox(height: 6),
                                _vistaEncabezado(),
                              ],
                            ),
                          ),
                          const TituloSeccion('Cotizaciones y facturas'),
                          _texto(
                            _itbis,
                            'ITBIS por defecto (%)',
                            ayuda: 'Confírmalo con tu contador',
                            teclado: const TextInputType.numberWithOptions(
                                decimal: true),
                            validar: (v) {
                              final n = leerNumero(v ?? '');
                              if (n == null || n < 0 || n > 100) {
                                return 'Un número entre 0 y 100';
                              }
                              return null;
                            },
                          ),
                          _texto(
                            _vigencia,
                            'Vigencia de las cotizaciones (días)',
                            teclado: TextInputType.number,
                            validar: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n < 1 || n > 365) {
                                return 'Un número entre 1 y 365';
                              }
                              return null;
                            },
                          ),
                          CampoCompleto(
                            _texto(
                              _condiciones,
                              'Condiciones o notas al pie',
                              ayuda:
                                  'Se copia en cada cotización nueva. Ej. forma de pago, garantía.',
                              maxLineas: 4,
                              capitalizar: TextCapitalization.sentences,
                            ),
                          ),
                          CampoCompleto(
                            FilledButton.icon(
                              onPressed: _guardando ? null : _guardar,
                              icon: const Icon(Icons.save),
                              label: Text(
                                _guardando ? 'Guardando...' : 'Guardar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
