-- assets/migracion_usuarios_v11.sql
-- Tabla de usuarios con permisos granulares por módulo
CREATE TABLE IF NOT EXISTS usuario (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT NOT NULL,
    usuario             TEXT NOT NULL UNIQUE COLLATE NOCASE,
    clave               TEXT NOT NULL,
    rol_base            TEXT NOT NULL DEFAULT 'personalizado'
                        CHECK (rol_base IN ('admin','cobrador','facturador','inventario','personalizado')),
    permiso_proximos    INTEGER NOT NULL DEFAULT 1,
    permiso_clientes    INTEGER NOT NULL DEFAULT 1,
    permiso_inventario  INTEGER NOT NULL DEFAULT 0,
    permiso_ventas      INTEGER NOT NULL DEFAULT 0,
    permiso_cobranzas   INTEGER NOT NULL DEFAULT 0,
    permiso_reportes    INTEGER NOT NULL DEFAULT 0,
    permiso_admin       INTEGER NOT NULL DEFAULT 0,
    activo              INTEGER NOT NULL DEFAULT 1,
    creado_en           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M','now','localtime'))
);

-- Tabla de registro de abonos con referencia al usuario que registró el pago
CREATE TABLE IF NOT EXISTS pago_abono (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    factura_id      INTEGER NOT NULL REFERENCES factura(id) ON DELETE CASCADE,
    fecha_hora      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M','now','localtime')),
    fecha           TEXT NOT NULL,
    monto_capital   REAL NOT NULL DEFAULT 0,
    mora_cobrada    REAL NOT NULL DEFAULT 0,
    monto_total     REAL NOT NULL,
    metodo_pago     TEXT NOT NULL DEFAULT 'Efectivo',
    referencia      TEXT,
    banco           TEXT,
    voucher         TEXT,
    notas           TEXT,
    usuario_id      INTEGER REFERENCES usuario(id),
    usuario_nombre  TEXT NOT NULL DEFAULT 'Admin'
);

CREATE INDEX IF NOT EXISTS idx_pago_abono_factura ON pago_abono(factura_id);
CREATE INDEX IF NOT EXISTS idx_pago_abono_fecha    ON pago_abono(fecha);
CREATE INDEX IF NOT EXISTS idx_pago_abono_usuario  ON pago_abono(usuario_id);

-- Usuario Administrador inicial (clave: admin)
INSERT OR IGNORE INTO usuario
    (nombre, usuario, clave, rol_base,
     permiso_proximos, permiso_clientes, permiso_inventario,
     permiso_ventas, permiso_cobranzas, permiso_reportes, permiso_admin)
VALUES
    ('Administrador', 'admin', 'admin', 'admin',
     1, 1, 1, 1, 1, 1, 1);
