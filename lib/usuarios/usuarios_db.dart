import '../data/base_datos.dart';
import 'usuario_modelos.dart';

extension UsuariosDb on BaseDatos {
  Future<List<Usuario>> listarUsuarios({bool soloActivos = false}) async {
    final d = await db;
    final where = soloActivos ? 'WHERE activo = 1' : '';
    final filas = await d.rawQuery(
      'SELECT * FROM usuario $where ORDER BY id ASC',
    );
    return filas.map(Usuario.fromMap).toList();
  }

  Future<Usuario?> obtenerUsuario(int id) async {
    final d = await db;
    final filas =
        await d.query('usuario', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : Usuario.fromMap(filas.first);
  }

  Future<Usuario?> autenticar(String usuario, String clave) async {
    final d = await db;
    final filas = await d.query(
      'usuario',
      where: 'LOWER(usuario) = LOWER(?) AND clave = ? AND activo = 1',
      whereArgs: [usuario.trim(), clave.trim()],
      limit: 1,
    );
    return filas.isEmpty ? null : Usuario.fromMap(filas.first);
  }

  /// Cambia la clave del usuario. Devuelve null si quedó bien;
  /// el mensaje del problema en caso contrario.
  Future<String?> cambiarClave(int id, String actual, String nueva) async {
    final actualLimpia = actual.trim();
    final nuevaLimpia = nueva.trim();
    if (nuevaLimpia.length < 4) {
      return 'La nueva contraseña debe tener al menos 4 caracteres.';
    }
    if (nuevaLimpia == actualLimpia) {
      return 'La nueva contraseña debe ser distinta de la actual.';
    }
    final d = await db;
    final filas = await d.query(
      'usuario',
      columns: ['id', 'clave'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return 'El usuario no existe.';
    if (filas.first['clave'] != actualLimpia) {
      return 'La contraseña actual no es correcta.';
    }
    await d.update(
      'usuario',
      {'clave': nuevaLimpia},
      where: 'id = ?',
      whereArgs: [id],
    );
    return null;
  }

  Future<int> guardarUsuario(Usuario u) async {
    final d = await db;
    if (u.id == null) {
      return d.insert('usuario', u.toMap());
    }
    await d.update(
      'usuario',
      u.toMap(),
      where: 'id = ?',
      whereArgs: [u.id],
    );
    return u.id!;
  }

  Future<void> eliminarUsuario(int id) async {
    if (id == 1) {
      throw StateError('No se puede eliminar al usuario Administrador principal.');
    }
    final d = await db;
    await d.delete('usuario', where: 'id = ?', whereArgs: [id]);
  }
}
