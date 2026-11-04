-- Migracion del inventario a la version 8: control por numero de serie.
-- La tabla unidad la crea inventario.sql. Aqui solo se agrega la marca al producto.

ALTER TABLE producto ADD COLUMN maneja_serial INTEGER NOT NULL DEFAULT 0 CHECK (maneja_serial IN (0,1));
