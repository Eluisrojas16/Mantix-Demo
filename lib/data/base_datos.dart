import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/cliente.dart';

/// Acceso único a la base de datos SQLite.
class BaseDatos {
  BaseDatos._();
  static final BaseDatos instancia = BaseDatos._();

  /// Sube este número cuando cambie la estructura de la base.
  /// v2: la vista de próximos mantenimientos considera las visitas programadas.
  /// v3: clientes de tipo consumidor final o empresa (RNC y contacto).
  /// v4: módulo de inventario (assets/inventario.sql).
  /// v5: inventario con clases y catálogos de marcas, modelos y categorías.
  /// v6: ventas: datos del negocio y cotizaciones (assets/ventas.sql).
  /// v7: logo del negocio.
  /// v8: inventario por número de serie (tabla unidad).
  /// v9: facturas (assets/facturas.sql).
  /// v10: cuentas por cobrar y financiamiento a crédito (cuotas y moras).
  /// v11: sistema de usuarios, roles con cotejos de permisos y tabla de abonos.
  /// v12: banco y voucher en pago_abono (idempotente).
  /// v13: usuario que hizo cada movimiento de inventario (idempotente).
  static const _versionBase = 13;

  Database? _db;

  /// Llamar una vez en main(), antes de runApp().
  /// En Android usa sqflite normal; en escritorio usa la versión FFI.
  static void inicializarPlataforma() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get db async => _db ??= await _abrir();

  /// Sentencias SQL de un archivo de assets (sin comentarios ni PRAGMA).
  Future<List<String>> _sentencias(String asset) async {
    final sql = await rootBundle.loadString(asset);
    final sinComentarios = sql
        .split('\n')
        .where((linea) => !linea.trimLeft().startsWith('--'))
        .join('\n');
    return [
      for (final sentencia in sinComentarios.split(';'))
        if (sentencia.trim().isNotEmpty &&
            !sentencia.trim().toUpperCase().startsWith('PRAGMA'))
          sentencia.trim(),
    ];
  }

  Future<Database> _abrir() async {
    final carpeta = await getApplicationSupportDirectory();
    await carpeta.create(recursive: true);
    final ruta = p.join(carpeta.path, 'mantix.db');

    return openDatabase(
      ruta,
      version: _versionBase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Primera vez: crear todo a partir de los archivos de assets.
        for (final s in await _sentencias('assets/schema.sql')) {
          await db.execute(s);
        }
        for (final s in await _sentencias('assets/inventario.sql')) {
          await db.execute(s);
        }
        for (final s in await _sentencias('assets/ventas.sql')) {
          await db.execute(s);
        }
        for (final s in await _sentencias('assets/facturas.sql')) {
          await db.execute(s);
        }
        for (final s in await _sentencias('assets/cobranzas.sql')) {
          await db.execute(s);
        }
        for (final s
            in await _sentencias('assets/migracion_usuarios_v11.sql')) {
          await db.execute(s);
        }
      },
      onUpgrade: (db, anterior, nueva) async {
        if (anterior < 2) {
          // Se reemplaza solo la vista; los datos no se tocan.
          await db.execute('DROP VIEW IF EXISTS v_proximos_mantenimientos');
          for (final s in await _sentencias('assets/schema.sql')) {
            if (s.toUpperCase().startsWith('CREATE VIEW')) {
              await db.execute(s);
            }
          }
        }
        if (anterior < 3) {
          // Tipos de cliente. Los clientes existentes quedan como "consumidor".
          await db.execute(
            "ALTER TABLE cliente ADD COLUMN tipo_cliente TEXT NOT NULL "
            "DEFAULT 'consumidor' "
            "CHECK (tipo_cliente IN ('consumidor','empresa'))",
          );
          await db.execute('ALTER TABLE cliente ADD COLUMN rnc TEXT');
          await db.execute('ALTER TABLE cliente ADD COLUMN contacto TEXT');
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_cliente_rnc '
            'ON cliente(rnc)',
          );
        }
        if (anterior < 4) {
          // Inventario completo (ya con la estructura final): tablas nuevas.
          for (final s in await _sentencias('assets/inventario.sql')) {
            await db.execute(s);
          }
        } else {
          // Inventario ya existente: se crean las tablas nuevas (listas, unidades)
          // y se agregan las columnas que faltan, conservando los datos.
          if (anterior < 8) {
            for (final s in await _sentencias('assets/inventario.sql')) {
              await db.execute(s);
            }
          }
          if (anterior < 5) {
            for (final s
                in await _sentencias('assets/migracion_inventario_v5.sql')) {
              await db.execute(s);
            }
          }
          if (anterior < 8) {
            for (final s
                in await _sentencias('assets/migracion_inventario_v8.sql')) {
              await db.execute(s);
            }
          }
        }
        if (anterior < 6) {
          // Ventas completo (ya con el logo): tablas nuevas.
          for (final s in await _sentencias('assets/ventas.sql')) {
            await db.execute(s);
          }
        } else if (anterior < 7) {
          // Ventas ya existente: solo se agrega la columna del logo.
          for (final s in await _sentencias('assets/migracion_ventas_v7.sql')) {
            await db.execute(s);
          }
        }
        if (anterior < 9) {
          // Facturas: tablas nuevas, no tocan los datos existentes.
          for (final s in await _sentencias('assets/facturas.sql')) {
            await db.execute(s);
          }
        }
        if (anterior < 10) {
          // Cuentas por cobrar y crédito: columnas de financiamiento y tabla cuota.
          for (final s
              in await _sentencias('assets/migracion_cobranzas_v10.sql')) {
            await db.execute(s);
          }
        }
        if (anterior < 12) {
          // BD anteriores a v11 pueden tener pago_abono ya creada sin las
          // columnas nuevas. SQLite no admite ALTER condicional: se comprueba
          // el esquema real antes de modificar, sin perder los datos.
          final cols = (await db.rawQuery('PRAGMA table_info(pago_abono)'))
              .map((r) => r['name'] as String)
              .toSet();
          if (cols.isNotEmpty) {
            if (!cols.contains('banco')) {
              await db.execute('ALTER TABLE pago_abono ADD COLUMN banco TEXT');
            }
            if (!cols.contains('voucher')) {
              await db.execute('ALTER TABLE pago_abono ADD COLUMN voucher TEXT');
            }
            if (!cols.contains('usuario_id')) {
              await db.execute(
                'ALTER TABLE pago_abono '
                'ADD COLUMN usuario_id INTEGER REFERENCES usuario(id)',
              );
            }
            if (!cols.contains('usuario_nombre')) {
              await db.execute(
                "ALTER TABLE pago_abono "
                "ADD COLUMN usuario_nombre TEXT NOT NULL DEFAULT 'Admin'",
              );
            }
          }
          // Usuarios, roles con cotejos de permisos y registro de abonos.
          for (final s
              in await _sentencias('assets/migracion_usuarios_v11.sql')) {
            await db.execute(s);
          }
        }
        if (anterior < 13) {
          // Qué usuario hizo cada movimiento de inventario. Igual que en v12,
          // se comprueba el esquema real antes de alterar (idempotente).
          final cols = (await db.rawQuery(
            'PRAGMA table_info(movimiento_inventario)',
          ))
              .map((r) => r['name'] as String)
              .toSet();
          if (cols.isNotEmpty) {
            if (!cols.contains('usuario_id')) {
              await db.execute(
                'ALTER TABLE movimiento_inventario '
                'ADD COLUMN usuario_id INTEGER REFERENCES usuario(id)',
              );
            }
            if (!cols.contains('usuario_nombre')) {
              await db.execute(
                "ALTER TABLE movimiento_inventario "
                "ADD COLUMN usuario_nombre TEXT NOT NULL DEFAULT 'Admin'",
              );
            }
          }
        }
      },
    );
  }

  // ------------------------------------------------------------ Próximos mantenimientos

  /// Aires con su último y siguiente mantenimiento (vista v_proximos_mantenimientos).
  Future<List<Map<String, Object?>>> proximosMantenimientos() async {
    final d = await db;
    return d.rawQuery(
      'SELECT * FROM v_proximos_mantenimientos '
      'ORDER BY siguiente_mantenimiento',
    );
  }

  // ------------------------------------------------------------ Clientes

  Future<List<Cliente>> listarClientes([String filtro = '']) async {
    final d = await db;
    final f = filtro.trim();
    final filas = f.isEmpty
        ? await d.query('cliente', orderBy: 'nombre_apellido COLLATE NOCASE')
        : await d.query(
            'cliente',
            where: 'nombre_apellido LIKE ? OR cedula LIKE ? OR rnc LIKE ? '
                'OR telefono LIKE ? OR contacto LIKE ?',
            whereArgs: ['%$f%', '%$f%', '%$f%', '%$f%', '%$f%'],
            orderBy: 'nombre_apellido COLLATE NOCASE',
          );
    return filas.map(Cliente.fromMap).toList();
  }

  /// Inserta si no tiene id, actualiza si lo tiene. Devuelve el id.
  Future<int> guardarCliente(Cliente c) async {
    final d = await db;
    if (c.id == null) {
      return d.insert('cliente', c.toMap());
    }
    await d.update('cliente', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<int> contarAires(int clienteId) async {
    final d = await db;
    final r = await d.rawQuery(
      'SELECT COUNT(*) FROM aire WHERE cliente_id = ?',
      [clienteId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Ojo: por el esquema, borra también sus aires y mantenimientos (ON DELETE CASCADE).
  /// Falla si el cliente tiene cotizaciones o facturas (ON DELETE RESTRICT).
  Future<void> eliminarCliente(int id) async {
    final d = await db;
    await d.delete('cliente', where: 'id = ?', whereArgs: [id]);
  }
}
