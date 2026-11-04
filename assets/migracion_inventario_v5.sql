-- Migracion del inventario de la version 4 a la 5. Se ejecuta una sola vez,
-- sobre bases que ya tenian la tabla producto con marca, modelo y categoria como texto.
-- Los datos existentes se conservan: los textos pasan a las nuevas listas.

ALTER TABLE producto ADD COLUMN clase TEXT NOT NULL DEFAULT 'producto' CHECK (clase IN ('producto','material','miscelaneo'));
ALTER TABLE producto ADD COLUMN categoria_id INTEGER REFERENCES categoria(id) ON DELETE SET NULL;
ALTER TABLE producto ADD COLUMN marca_id INTEGER REFERENCES marca(id) ON DELETE SET NULL;
ALTER TABLE producto ADD COLUMN modelo_id INTEGER REFERENCES modelo(id) ON DELETE SET NULL;

UPDATE producto SET clase = 'miscelaneo' WHERE tipo = 'servicio';

INSERT OR IGNORE INTO categoria (nombre) SELECT DISTINCT TRIM(categoria) FROM producto WHERE categoria IS NOT NULL AND TRIM(categoria) <> '';

UPDATE producto SET categoria_id = (SELECT c.id FROM categoria c WHERE c.nombre = TRIM(producto.categoria)) WHERE categoria IS NOT NULL AND TRIM(categoria) <> '';

INSERT OR IGNORE INTO marca (nombre) SELECT DISTINCT TRIM(marca) FROM producto WHERE marca IS NOT NULL AND TRIM(marca) <> '';

UPDATE producto SET marca_id = (SELECT m.id FROM marca m WHERE m.nombre = TRIM(producto.marca)) WHERE marca IS NOT NULL AND TRIM(marca) <> '';

INSERT OR IGNORE INTO marca (nombre) SELECT 'Sin marca' WHERE EXISTS (SELECT 1 FROM producto WHERE marca_id IS NULL AND modelo IS NOT NULL AND TRIM(modelo) <> '');

UPDATE producto SET marca_id = (SELECT id FROM marca WHERE nombre = 'Sin marca') WHERE marca_id IS NULL AND modelo IS NOT NULL AND TRIM(modelo) <> '';

INSERT OR IGNORE INTO modelo (marca_id, nombre) SELECT DISTINCT marca_id, TRIM(modelo) FROM producto WHERE marca_id IS NOT NULL AND modelo IS NOT NULL AND TRIM(modelo) <> '';

UPDATE producto SET modelo_id = (SELECT mo.id FROM modelo mo WHERE mo.marca_id = producto.marca_id AND mo.nombre = TRIM(producto.modelo)) WHERE marca_id IS NOT NULL AND modelo IS NOT NULL AND TRIM(modelo) <> '';
