import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Licencia de demostración: la demo arranca la primera vez que se abre y
/// vence tras [duracionDemo] (una hora). Vencida, la app se bloquea con la
/// pantalla de «Demo expirada». La fecha/hora de inicio queda en un archivo
/// del equipo con una firma mezclada con sal, para que editarla a mano no sirva.
const Duration duracionDemo = Duration(hours: 1);

const String _nombreArchivo = 'mantix_demo.lic';
const String _sal = 'MantixDemo_v1_2026_ClaveLocal';

class EstadoDemo {
  final bool expirada;

  /// Minutos que quedan (0 si está vencida).
  final int minutosRestantes;

  /// Cuándo vence, legible («AAAA-MM-DD a las HH:MM»).
  final String expiraEl;

  const EstadoDemo({
    required this.expirada,
    required this.minutosRestantes,
    required this.expiraEl,
  });
}

/// Lee (o crea) la licencia local y decide si la demo sigue válida.
Future<EstadoDemo> verificarDemo() async {
  final dir = await getApplicationSupportDirectory();
  final archivo = File('${dir.path}/$_nombreArchivo');

  DateTime inicio;
  if (archivo.existsSync()) {
    final contenido = archivo.readAsStringSync().trim();
    final partes = contenido.split('|');
    final inicioTexto = partes.isNotEmpty ? partes[0] : '';
    final firma = partes.length > 1 ? partes[1] : '';
    final inicioLeido = DateTime.tryParse(inicioTexto);
    // Hora ilegible o firma incorrecta (alguien la alteró a mano): vencida.
    if (inicioLeido == null || firma != _firma(inicioTexto)) {
      return EstadoDemo(
        expirada: true,
        minutosRestantes: 0,
        expiraEl: inicioTexto,
      );
    }
    inicio = inicioLeido;
  } else {
    inicio = DateTime.now();
    final iso = inicio.toIso8601String();
    archivo.writeAsStringSync('$iso|${_firma(iso)}');
  }

  final vence = inicio.add(duracionDemo);
  final restanteMs = vence.difference(DateTime.now()).inMilliseconds;
  final iso = vence.toIso8601String();
  return EstadoDemo(
    expirada: restanteMs <= 0,
    minutosRestantes: restanteMs > 0 ? (restanteMs / 60000).ceil() : 0,
    expiraEl: '${iso.substring(0, 10)} a las ${iso.substring(11, 16)}',
  );
}

/// Mezcla la fecha con una sal constante. No es criptografía fuerte, pero
/// evita que la hora se cambie editando el archivo al paso.
String _firma(String fecha) {
  var x = 0x4D414E54; // 'MANT'
  final s = fecha + _sal;
  for (var i = 0; i < s.length; i++) {
    x = (x * 31 + s.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return x.toRadixString(16).padLeft(8, '0');
}
