-- Migración a v10: Cuentas por Cobrar y Financiamiento

ALTER TABLE factura ADD COLUMN condicion_venta TEXT NOT NULL DEFAULT 'contado';
ALTER TABLE factura ADD COLUMN inicial REAL NOT NULL DEFAULT 0;
ALTER TABLE factura ADD COLUMN interes_pct REAL NOT NULL DEFAULT 0;
ALTER TABLE factura ADD COLUMN frecuencia_pago TEXT DEFAULT 'mensual';
ALTER TABLE factura ADD COLUMN cantidad_cuotas INTEGER NOT NULL DEFAULT 1;
ALTER TABLE factura ADD COLUMN mora_pct REAL NOT NULL DEFAULT 0;
ALTER TABLE factura ADD COLUMN total_financiado REAL NOT NULL DEFAULT 0;
ALTER TABLE factura ADD COLUMN saldo_pendiente REAL NOT NULL DEFAULT 0;

UPDATE factura SET total_financiado = total, saldo_pendiente = (CASE WHEN estado = 'pagada' THEN 0 ELSE total END);

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
