-- Inventario general. Independiente de clientes y ventas.
-- Marcas, modelos y categorias son listas que administra el usuario.

CREATE TABLE IF NOT EXISTS categoria (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre  TEXT NOT NULL UNIQUE COLLATE NOCASE
);

CREATE TABLE IF NOT EXISTS marca (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre  TEXT NOT NULL UNIQUE COLLATE NOCASE
);

CREATE TABLE IF NOT EXISTS modelo (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    marca_id  INTEGER NOT NULL REFERENCES marca(id) ON DELETE CASCADE,
    nombre    TEXT NOT NULL COLLATE NOCASE,
    UNIQUE (marca_id, nombre)
);

CREATE INDEX IF NOT EXISTS idx_modelo_marca ON modelo(marca_id);

-- clase: producto y material controlan existencia. miscelaneo no la controla
-- y sirve para facturar conceptos sin inventario (mano de obra, instalacion...)
-- maneja_serial = 1: cada unidad tiene su numero de serie (tabla unidad)
CREATE TABLE IF NOT EXISTS producto (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo         TEXT UNIQUE,
    nombre         TEXT NOT NULL,
    clase          TEXT NOT NULL DEFAULT 'producto'
                   CHECK (clase IN ('producto','material','miscelaneo')),
    categoria_id   INTEGER REFERENCES categoria(id) ON DELETE SET NULL,
    marca_id       INTEGER REFERENCES marca(id) ON DELETE SET NULL,
    modelo_id      INTEGER REFERENCES modelo(id) ON DELETE SET NULL,
    numero_parte   TEXT,
    descripcion    TEXT,
    unidad         TEXT NOT NULL DEFAULT 'unidad',
    costo          REAL,
    precio_venta   REAL,
    stock_minimo   REAL NOT NULL DEFAULT 0,
    activo         INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1)),
    maneja_serial  INTEGER NOT NULL DEFAULT 0 CHECK (maneja_serial IN (0,1)),
    creado_en      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- El stock no se guarda: se calcula sumando los movimientos.
CREATE TABLE IF NOT EXISTS movimiento_inventario (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    producto_id     INTEGER NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
    fecha           TEXT NOT NULL,
    tipo            TEXT NOT NULL CHECK (tipo IN ('entrada','salida','ajuste')),
    cantidad        REAL NOT NULL,
    costo_unitario  REAL,
    origen          TEXT NOT NULL DEFAULT 'manual',
    referencia      TEXT,
    nota            TEXT,
    creado_en       TEXT NOT NULL DEFAULT (datetime('now')),
    CHECK ((tipo = 'ajuste' AND cantidad <> 0)
        OR (tipo IN ('entrada','salida') AND cantidad > 0))
);

CREATE INDEX IF NOT EXISTS idx_mov_producto
    ON movimiento_inventario(producto_id, fecha);

CREATE VIEW IF NOT EXISTS v_stock AS
SELECT
    p.id AS producto_id,
    COALESCE(SUM(CASE m.tipo
                   WHEN 'entrada' THEN m.cantidad
                   WHEN 'salida'  THEN -m.cantidad
                   ELSE m.cantidad
                 END), 0) AS stock
FROM producto p
LEFT JOIN movimiento_inventario m ON m.producto_id = p.id
GROUP BY p.id;

-- Una fila por cada unidad con numero de serie. El serial es unico en todo el sistema
-- (sin importar mayusculas) y nunca se borra: asi no se puede repetir ni reutilizar.
CREATE TABLE IF NOT EXISTS unidad (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    producto_id            INTEGER NOT NULL REFERENCES producto(id) ON DELETE CASCADE,
    serial                 TEXT NOT NULL UNIQUE COLLATE NOCASE,
    estado                 TEXT NOT NULL DEFAULT 'en_stock'
                           CHECK (estado IN ('en_stock','despachado')),
    movimiento_entrada_id  INTEGER REFERENCES movimiento_inventario(id) ON DELETE SET NULL,
    movimiento_salida_id   INTEGER REFERENCES movimiento_inventario(id) ON DELETE SET NULL,
    creado_en              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_unidad_producto ON unidad(producto_id, estado);
