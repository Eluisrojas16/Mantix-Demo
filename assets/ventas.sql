-- Ventas: datos del negocio y cotizaciones (mas adelante, facturas).
-- Depende de clientes e inventario. El inventario no depende de ventas.

-- Una sola fila (id = 1) con los datos del negocio. El logo se guarda dentro de la base
-- (asi viaja con las copias de seguridad).
CREATE TABLE IF NOT EXISTS negocio (
    id                INTEGER PRIMARY KEY CHECK (id = 1),
    nombre            TEXT NOT NULL,
    rnc               TEXT,
    direccion         TEXT,
    telefono          TEXT,
    correo            TEXT,
    itbis_porcentaje  REAL NOT NULL DEFAULT 18,
    vigencia_dias     INTEGER NOT NULL DEFAULT 15,
    condiciones       TEXT,
    logo              BLOB
);

INSERT OR IGNORE INTO negocio (id, nombre) VALUES (1, 'Mi negocio');

-- Los totales se guardan al guardar la cotizacion (se calculan siempre en un solo lugar).
-- No se puede eliminar un cliente que tenga cotizaciones.
CREATE TABLE IF NOT EXISTS cotizacion (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id      INTEGER NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT,
    fecha           TEXT NOT NULL,
    vigencia_hasta  TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'borrador'
                    CHECK (estado IN ('borrador','enviada','aceptada','rechazada','facturada')),
    notas           TEXT,
    subtotal        REAL NOT NULL DEFAULT 0,
    itbis           REAL NOT NULL DEFAULT 0,
    total           REAL NOT NULL DEFAULT 0,
    creado_en       TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Cada linea copia la descripcion y el precio: si cambias el producto despues,
-- la cotizacion no se altera. producto_id queda vacio para conceptos libres.
CREATE TABLE IF NOT EXISTS cotizacion_linea (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    cotizacion_id    INTEGER NOT NULL REFERENCES cotizacion(id) ON DELETE CASCADE,
    orden            INTEGER NOT NULL DEFAULT 0,
    producto_id      INTEGER REFERENCES producto(id) ON DELETE SET NULL,
    descripcion      TEXT NOT NULL,
    cantidad         REAL NOT NULL CHECK (cantidad > 0),
    unidad           TEXT NOT NULL DEFAULT 'unidad',
    precio_unitario  REAL NOT NULL DEFAULT 0,
    descuento_pct    REAL NOT NULL DEFAULT 0,
    itbis_pct        REAL NOT NULL DEFAULT 18
);

CREATE INDEX IF NOT EXISTS idx_cotizacion_cliente ON cotizacion(cliente_id);

CREATE INDEX IF NOT EXISTS idx_cotizacion_linea ON cotizacion_linea(cotizacion_id, orden);
