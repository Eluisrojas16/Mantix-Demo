/// Redondea a 2 decimales (la mitad se redondea hacia arriba).
double redondear2(double v) => (v * 100).roundToDouble() / 100;

/// 1500 -> "1,500.00" (sin símbolo de moneda; sirve para tablas y PDF)
String formatoDinero(double v) {
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
  return '$signo${buf.toString()}.${partes[1]}';
}
