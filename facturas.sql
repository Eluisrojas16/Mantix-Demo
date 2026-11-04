-- Facturas. Depende de clientes, cotizaciones, inventario y seriales.

-- La factura guarda una COPIA de los datos del cliente al emitirse: si el cliente
-- cambia despues, la factura no cambia. Una factura no se edita: se anula.
-- El NCF (comprobante fiscal) es opcional pero no se puede repetir.
CREATE TABLE IF NOT EXISTS factura (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id         INTEGER NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT,
    cotizacion_id      INTEGER REFERENCES cotizacion(id) ON DELETE RESTRICT,
    fecha              TEXT NOT NULL,
    ncf                TEXT,
    estado             TEXT NOT NULL DEFAULT 'emitida'
                       CHECK (estado IN ('emitida','pagada','anulada')),
    forma_pago         TEXT,
    fecha_pago         TEXT,
    cliente_nombre     TEXT NOT NULL,
    cliente_documento  TEXT,
    cliente_telefono   TEXT,
    cliente_direccion  TEXT,
    notas              TEXT,
    subtotal           REAL NOT NULL DEFAULT 0,
    itbis              REAL NOT NULL DEFAULT 0,
    total              REAL NOT NULL DEFAULT 0,
    motivo_anulacion   TEXT,
    creado_en          TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_factura_ncf ON factura(ncf) WHERE ncf IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_factura_cliente ON factura(cliente_id);

CREATE TABLE IF NOT EXISTS factura_linea (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    factura_id       INTEGER NOT NULL REFERENCES factura(id) ON DELETE CASCADE,
    orden            INTEGER NOT NULL DEFAULT 0,
    producto_id      INTEGER REFERENCES producto(id) ON DELETE SET NULL,
    descripcion      TEXT NOT NULL,
    cantidad         REAL NOT NULL CHECK (cantidad > 0),
    unidad           TEXT NOT NULL DEFAULT 'unidad',
    precio_unitario  REAL NOT NULL DEFAULT 0,
    descuento_pct    REAL NOT NULL DEFAULT 0,
    itbis_pct        REAL NOT NULL DEFAULT 18
);

-- Los seriales (unidades) que se despacharon en cada linea de la factura.
CREATE TABLE IF NOT EXISTS factura_linea_serial (
    factura_linea_id  INTEGER NOT NULL REFERENCES factura_linea(id) ON DELETE CASCADE,
    unidad_id         INTEGER NOT NULL REFERENCES unidad(id) ON DELETE RESTRICT,
    PRIMARY KEY (factura_linea_id, unidad_id)
);
