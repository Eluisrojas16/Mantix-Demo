-- Tabla de cuotas para ventas a crédito
CREATE TABLE IF NOT EXISTS cuota (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    factura_id        INTEGER NOT NULL REFERENCES factura(id) ON DELETE CASCADE,
    numero            INTEGER NOT NULL,
    fecha_vencimiento TEXT NOT NULL,
    monto             REAL NOT NULL,
    estado            TEXT NOT NULL DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente', 'pagada')),
    fecha_pago        TEXT,
    monto_pagado      REAL NOT NULL DEFAULT 0,
    mora_cobrada      REAL NOT NULL DEFAULT 0,
    notas             TEXT
);

CREATE INDEX IF NOT EXISTS idx_cuota_factura ON cuota(factura_id);
CREATE INDEX IF NOT EXISTS idx_cuota_vencimiento ON cuota(fecha_vencimiento);
CREATE INDEX IF NOT EXISTS idx_cuota_estado ON cuota(estado);
