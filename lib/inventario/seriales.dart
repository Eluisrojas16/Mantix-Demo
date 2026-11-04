/// Convierte un texto pegado (uno por línea, o separados por coma, punto y coma
/// o tabulador) en una lista de números de serie, sin espacios sobrantes.
List<String> parsearSeriales(String texto) {
  return texto
      .split(RegExp(r'[\n\r,;\t]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Seriales que aparecen más de una vez en la misma lista (sin importar mayúsculas).
List<String> serialesRepetidos(List<String> lista) {
  final vistos = <String>{};
  final repetidos = <String>{};
  for (final s in lista) {
    if (!vistos.add(s.toLowerCase())) repetidos.add(s);
  }
  return repetidos.toList();
}
