/// 5.0 -> "5", 2.5 -> "2.5", 2.25 -> "2.25"
String formatoCantidad(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// 1500 -> "RD$ 1,500.00"
String formatoMoneda(double? v) {
  if (v == null) return '—';
  final partes = v.toStringAsFixed(2).split('.');
  final entero = partes[0];
  final negativo = entero.startsWith('-');
  final digitos = negativo ? entero.substring(1) : entero;
  final buf = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buf.write(',');
    buf.write(digitos[i]);
  }
  final signo = negativo ? '-' : '';
  return 'RD\$ $signo${buf.toString()}.${partes[1]}';
}

/// Texto -> número (acepta coma decimal). Null si está vacío o no es número.
double? leerNumero(String s) =>
    double.tryParse(s.trim().replaceAll(',', '.'));
