-- Mantix: esquema inicial (SQLite)
PRAGMA foreign_keys = ON;

CREATE TABLE cliente (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_cliente     TEXT NOT NULL DEFAULT 'consumidor'
                     CHECK (tipo_cliente IN ('consumidor','empresa')),
    nombre_apellido  TEXT NOT NULL,          -- consumidor: nombre y apellido. empresa: nombre de la empresa
    cedula           TEXT UNIQUE,            -- solo consumidor final (texto, no número)
    rnc              TEXT,                   -- solo empresa
    contacto         TEXT,                   -- persona de contacto (empresa)
    telefono         TEXT,
    direccion        TEXT,
    notas            TEXT,
    creado_en        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX idx_cliente_rnc ON cliente(rnc);

CREATE TABLE aire (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id          INTEGER NOT NULL REFERENCES cliente(id) ON DELETE CASCADE,
    posicion            TEXT,                -- ej. "sala", "cuarto principal"
    marca               TEXT,
    modelo              TEXT,
    tipo                TEXT,                -- split, ventana, cassette...
    btu                 INTEGER,
    serial              TEXT,
    periodicidad_meses  INTEGER NOT NULL DEFAULT 6,
    activo              INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1))
);

CREATE TABLE mantenimiento (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    aire_id            INTEGER NOT NULL REFERENCES aire(id) ON DELETE CASCADE,
    fecha              TEXT NOT NULL,        -- formato AAAA-MM-DD
    tipo               TEXT NOT NULL DEFAULT 'preventivo'
                       CHECK (tipo IN ('preventivo','correctivo','instalacion')),
    estado             TEXT NOT NULL DEFAULT 'programado'
                       CHECK (estado IN ('programado','realizado','cancelado')),
    trabajo_realizado  TEXT,
    costo              REAL,
    pagado             INTEGER NOT NULL DEFAULT 0 CHECK (pagado IN (0,1)),
    tecnico            TEXT
);

CREATE INDEX idx_aire_cliente      ON aire(cliente_id);
CREATE INDEX idx_mant_aire_fecha   ON mantenimiento(aire_id, fecha);

-- Vista: último y siguiente mantenimiento (calculados, no guardados)
CREATE VIEW v_proximos_mantenimientos AS
SELECT
    a.id                      AS aire_id,
    c.id                      AS cliente_id,
    c.nombre_apellido,
    c.telefono,
    a.posicion,
    a.marca,
    a.modelo,
    ult.ultimo_mantenimiento,
    prog.fecha_programada,
    COALESCE(
        prog.fecha_programada,
        date(ult.ultimo_mantenimiento, '+' || a.periodicidad_meses || ' months')
    )                         AS siguiente_mantenimiento,
    CASE WHEN prog.fecha_programada IS NOT NULL
         THEN 'programado' ELSE 'calculado' END AS origen_siguiente
FROM aire a
JOIN cliente c ON c.id = a.cliente_id
LEFT JOIN (
    SELECT aire_id, MAX(fecha) AS ultimo_mantenimiento
    FROM mantenimiento
    WHERE estado = 'realizado'
    GROUP BY aire_id
) ult ON ult.aire_id = a.id
LEFT JOIN (
    SELECT m.aire_id, MIN(m.fecha) AS fecha_programada
    FROM mantenimiento m
    WHERE m.estado = 'programado'
      AND m.fecha > COALESCE(
            (SELECT MAX(r.fecha) FROM mantenimiento r
             WHERE r.aire_id = m.aire_id AND r.estado = 'realizado'),
            '0000-00-00')
    GROUP BY m.aire_id
) prog ON prog.aire_id = a.id
WHERE a.activo = 1;

-- Datos de ejemplo
INSERT INTO cliente (nombre_apellido, cedula, telefono, direccion)
VALUES ('Juan Pérez', '00112345678', '809-555-0101', 'Calle Principal #12, Santo Domingo Este');

INSERT INTO aire (cliente_id, posicion, marca, modelo, tipo, btu, periodicidad_meses)
VALUES (1, 'Sala', 'LG', 'Dual Inverter', 'split', 12000, 6),
       (1, 'Cuarto principal', 'Samsung', 'WindFree', 'split', 18000, 6);

INSERT INTO mantenimiento (aire_id, fecha, tipo, estado, trabajo_realizado, costo, pagado, tecnico)
VALUES (1, '2026-04-10', 'preventivo', 'realizado', 'Limpieza de filtros y serpentín', 1500, 1, 'Marcos'),
       (2, '2026-02-20', 'preventivo', 'realizado', 'Limpieza general y revisión de gas', 1800, 1, 'Marcos');
