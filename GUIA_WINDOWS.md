# Mantix DEMO — Guía para compilar y correr en Windows

> ⚠️ **Lee primero esto.** Si escribiste `flutter build windows` en una PC con
> Windows y la computadora respondió *«no se reconoce como un comando interno
> o externo»*, es porque **Flutter no está instalado en esa máquina** (o no está
> registrado en el PATH). Flutter **no viene con Windows**: hay que instalarlo +
> su compilador. Esta guía explica todo, una sola vez, de arriba para abajo.

---

## Lo que hay que instalar (una sola vez, en la PC con Windows)

| # | Software | Para qué sirve | Espacio aprox. |
|---|----------|----------------|----------------|
| 1 | **Git for Windows** | Flutter lo usa internamente | ~300 MB |
| 2 | **Flutter SDK** | El motor de la app: compila el código a ejecutable | ~1 GB |
| 3 | **Visual Studio 2022 Community** con la carga **«Desarrollo para escritorio con C++»** | Es el compilador real que produce el `.exe` de Windows | ~7 GB |

Requisitos previos: Windows 10 (o superior) de 64 bits y unos **10 GB libres**
de disco. Internet decente, porque son descargas grandes.

---

## Paso 1 — Instalar Git for Windows

1. Descarga: <https://git-scm.com/downloads/win>
2. Ejecuta el instalador y dale **Next / Next / Finish** con todo por defecto.

---

## Paso 2 — Instalar el Flutter SDK y agregarlo al PATH

1. Descarga el ZIP de la versión estable:
   <https://docs.flutter.dev/get-started/install/windows>
2. Descomprime la carpeta en **`C:\dev\flutter`**
   (NO la pongas en `C:\Program Files`: por permisos y espacios no sirve bien).
3. Agregar `C:\dev\flutter\bin` al **PATH**:
   - Busca en el menú Inicio: **«variables de entorno»** y abre
     **«Editar las variables de entorno del sistema»**.
   - En la caja «Variables de usuario», selecciona la fila **`Path`** → **Editar** → **Nueva**.
   - Escribe: `C:\dev\flutter\bin` → **Aceptar** en todas las ventanas.
4. **Abre un CMD nuevo** (⌨️ esto es clave: las ventanas de terminal abiertas
   *antes* del cambio NO ven el PATH nuevo).

---

## Paso 3 — Instalar Visual Studio 2022 con C++

1. Descarga **Visual Studio 2022 Community** (el gratuito):  
   <https://visualstudio.microsoft.com/downloads/>
2. Al abrir el instalador te pide elegir «cargas de trabajo». Marca
   únicamente: ☑ **Desarrollo para escritorio con C++**
   (incluye el compilador MSVC, el SDK de Windows y las librerías ATL, que son
   exactamente las que Flutter exige para producir apps de Windows).
3. Dale **Instalar** (~7 GB, tarda un rato).

---

## Paso 4 — Comprobar que todo quedó instalado

Abre un **CMD nuevo** y escribe:

```
flutter doctor -v
```

Debe aparecer al final algo como:

```
[✓] Flutter ...
[✓] Windows development
[✓] Visual Studio - develop Windows apps
```

Si alguna línea sale con `[✗]` o `[!]`, el propio `flutter doctor` te dice
qué falta; casi siempre es repetir el paso 2.3 (PATH) o el paso 3 (carga de C++).

---

## Paso 5 — Compilar la demo

Con **todas** las instalaciones hechas, en el CMD:

```
cd "C:\ruta\donde\copiaste\Mantix Demo"
flutter pub get
```

- Para **probarla** directo desde la carpeta (se auto-abre una ventana con la app):
  ```
  flutter run -d windows
  ```
- Para **generar el ejecutable final**:
  ```
  flutter build windows --release
  ```

### ¿Dónde queda el `.exe`?

```
build\windows\x64\runner\Release\mantix_demo.exe
```

---

## Paso 6 — Entregar la demo a un cliente

1. Copia la carpeta **COMPLETA**:
   `build\windows\x64\runner\Release\`
   (los `.dll` y la carpeta `data` VAN JUNTOS con el `mantix_demo.exe`).
2. En el equipo del cliente, doble clic a `mantix_demo.exe`.
3. Los **60 minutos de la demo empiezan con SU primer arranque en SU equipo**
   (la fecha/hora de inicio queda guardada con una firma en la carpeta de datos
   de fondo de Windows; ni se nota).

---

## Problemas comunes

| Problema | Causa y solución |
|---|---|
| *«flutter no se reconoce como un comando interno o externo»* | El PATH no quedó bien o abriste un CMD viejo. Repite el paso 2.3, cierra y abre un CMD nuevo. Comprueba con `where flutter` — debe responder la ruta `C:\dev\flutter\bin\flutter.bat`. |
| `flutter doctor` marca `[✗]` en Visual Studio | No instalaste la carga «Desarrollo para escritorio con C++» (paso 3), o instalaste VS Build Tools solo. Ábrelo de nuevo con Visual Studio Installer → **Modificar** → activa esa carga. |
| *«Unable to find bundled Visual Studio»* al compilar | Falta el SDK de Windows o el compilador MSVC: mismo remedio del punto anterior. |
| El antivirus borra/atora el exe generado | Añade la carpeta `Release` a las exclusiones del antivirus. |
| `flutter pub get` falla sin internet | Necesita descargar paquetes la primera vez; verifica la conexión. |

---

## Opción B — Compilar SIN instalar nada: la nube con GitHub Actions (gratis)

Si no quieres meter ~7 GB de instalación en tu PC, se puede generar el
`.exe` de Windows usando máquinas de GitHub. El proyecto de la demo ya trae
el archivo preparado: `.github/workflows/build_windows.yml`.

### Cómo se hace, de arriba para abajo

1. Crea tu cuenta gratis en <https://github.com> (si no la tienes).
2. Crea un repositorio **privado** (botón verde **New** → nombre p.ej. `mantix-demo`
   → marca **Private** → Create).
3. Sube el contenido COMPLETO de la carpeta `Mantix Demo` al repositorio
   (la web de GitHub lo permite: botón **uploading an existing file**, o con git).
   No importa que falten `build/` o `.dart_tool/`: están ignorados a propósito.
4. En la página del repositorio, entra a la pestaña **Actions**
   (arriba, al lado de Code / Pull requests).
   - La primera vez te pregunta si habilitar actions: **enable**.
   - Selecciona en el menú de la izquierda: **«Compilar Mantix Demo (Windows)»**.
   - Botón **Run workflow** (menú desplegable del corredor) → **Run workflow**.
5. Espera **10–15 minutos** (verás la corrida girando en la lista).
6. Al terminar ( lista verde ✔), entra a esa corrida; abajo en
   **Artifacts** descarga **`mantix_demo_windows`**.
7. Descomprime el ZIP → dentro está `mantix_demo.exe` con sus `.dll` y la
   carpeta `data`. Doble clic y listo (o copia TODO el contenido de la carpeta
   al equipo del cliente como en el Paso 6).

### Notas de la Opción B

- **Gratis** mientras el repositorio sea público o privado de uso normal
  (GitHub da minutos de Actions suficientes para esto en cuentas gratuitas;
  privado también anda bien: tus 2.000 minutos/mes de sobra por corrida de
  ~15 min).
- Las corridas se guardan 14 días y los artefactos se pueden re-descargar.
- Si un día tocas el código y lo vuelves a subir, la compilación corre sola
  (además del botón manual).
- La versión de Flutter que use la nube es la última *estable*; aquí mismo desde
  Linux seguimos compilando con nuestra versión local para desarrollo.

> 💡 ¿Humor? Ya no necesitas una PC «poderosa» ni una hora de instalación:
> un archivo YAML hace de vos de compilador.
