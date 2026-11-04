# Mantix DEMO

Versión de demostración de **Mantix** — sistema de gestión para negocios
(clientes, inventario, ventas/facturas, cobranzas, reportes y usuarios).

- Todas las funciones del sistema real.
- **Límite: 1 hora de uso** desde el primer arranque en cada equipo (queda
  registrado con una firma local; al vencerse la app queda bloqueada con la
  pantalla «Demo expirada»).
- El ejecutable se llama `mantix_demo.exe` (Windows) / `mantix_demo` (Linux)
  y usa una carpeta de datos propia (`com.mantix.demo`), separada del Mantix
  completo.

## ¿Cómo la compilo y la entrego?

➡️ **Lee [`GUIA_WINDOWS.md`](GUIA_WINDOWS.md)** — guía completa paso a paso con
DOS formas de generar `mantix_demo.exe`:

- **Opción A (instalar en tu PC):** Flutter SDK + Visual Studio C++ y
  `flutter build windows --release` (explicado clic por clic).
- **Opción B (sin instalar nada):** compilar **en la nube** con GitHub Actions —
  el proyecto ya trae el workflow `.github/workflows/build_windows.yml`;
  subes la carpeta a un repositorio privado de GitHub y en ~15 min descargas
  el ZIP con el ejecutable.

> La compilación para Windows **no se puede hacer desde Linux** (Flutter no
> compila de un sistema a otro). Con la Opción B la hace GitHub por vos.

## Desarrollo en Linux (equipo de origen)

```
flutter pub get
flutter run -d linux
flutter build linux --debug | --release
```

La demo vive en su copia **`Mantix Demo`** — cualquier cambio funcional hecho
al Mantix real debe copiarse aquí (o darles mantenimiento conjunto).
