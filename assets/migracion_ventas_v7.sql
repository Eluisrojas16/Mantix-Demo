-- Migracion de ventas de la version 6 a la 7. Se ejecuta una sola vez, sobre bases
-- que ya tenian la tabla negocio sin logo.

ALTER TABLE negocio ADD COLUMN logo BLOB;
