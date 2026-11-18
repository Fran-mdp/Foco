# Foco

Un espacio para estudiar sin distracciones: bloqueá sitios en Chrome y apps de tu Mac, organizá tareas y mirá tu tiempo de foco y tus logros. Tus datos quedan en tu computadora; no necesitás crear una cuenta.

**Compatible con Mac con chip Apple Silicon (M1 o posterior) y macOS 26 o posterior.** Por ahora no funciona en Mac Intel, Windows ni iPhone. Necesitás Google Chrome para bloquear sitios.

## Instalación rápida

La instalación actual compila Foco en tu propia Mac. No necesitás pagar una cuenta de desarrollador ni saber programar. La primera vez macOS puede pedirte instalar las herramientas gratuitas de Apple; la compilación puede tardar unos minutos.

### 1. Descargá el proyecto

[Descargá el proyecto en ZIP](https://github.com/Fran-mdp/Foco/archive/refs/heads/main.zip) y descomprimí el archivo. También podés usar **Code → Download ZIP** en GitHub. Abrí la carpeta que contiene este README y `Instalar.command`.

### 2. Instalá Foco

Abrí **Terminal** desde Spotlight (⌘ + espacio). Escribí `cd ` —con un espacio al final—, arrastrá la carpeta del proyecto a Terminal y presioná Enter. Después pegá:

```sh
bash Instalar.command
```

El instalador verifica la compatibilidad, compila la app y la guarda en **tu carpeta personal → Aplicaciones → Foco**. No pide contraseña de administrador, no borra tu historial y no descarga paquetes de terceros. Si faltan las herramientas de Apple, te muestra qué comando ejecutar y luego podés repetir la instalación.

Podés revisar primero el archivo `Instalar.command`. No uses comandos de terceros que te pidan desactivar las protecciones de macOS. Esta versión tiene firma local; no tiene firma Developer ID ni notarización de Apple.

### 3. Conectá Chrome una sola vez

1. Abrí **Foco** desde tu carpeta personal → Aplicaciones. Tocá **Conectar Chrome → Preparar conexión local → Copiar ruta**.
2. En el perfil de Chrome que usás, abrí `chrome://extensions`. Activá **Modo de desarrollador** y elegí **Cargar descomprimida / Cargar extensión sin empaquetar**. En el selector, presioná **⌘⇧G**, pegá la ruta y confirmá la carpeta.
3. Abrí el complemento **Foco** en Chrome y autorizá los sitios elegidos. Volvé a la app: debe decir **Chrome conectado**.

El complemento todavía no está en Chrome Web Store. Solo controla el perfil donde lo cargás; no otros navegadores ni perfiles. Los permisos de sitios se conceden por dominio.

## Tu primer bloque

En **Concentrarme → Editar bloqueos**, elegí sitios y aplicaciones. Guardá tu trabajo antes de empezar: las apps elegidas reciben una solicitud de cierre.

- **Flexible → Iniciar foco:** empieza al instante y podés terminar cuando quieras.
- **Configurar duración:** elegí los minutos. **Firme** mantiene el compromiso hasta que termina el tiempo.
- **Pausar:** detiene el cronómetro; los bloqueos siguen activos.
- **Mis tareas:** agregá una tarea y elegila para acumular varios bloques sobre ella. El porcentaje lo registrás vos.
- **Mi progreso:** revisá día, semana, mes, año o fechas, y encontrá tus logros debajo del gráfico y las tareas.

Foco ayuda a concentrarte; el modo firme se puede eludir desactivando el complemento o usando otro navegador. No es un control parental ni un bloqueo imposible de quitar.

## Ayuda

- **Faltan herramientas de Apple:** ejecutá `xcode-select --install`, terminá la instalación y repetí el paso 2. Si el instalador detecta un SDK viejo, actualizá las herramientas de Apple antes de continuar.
- **Chrome no conecta:** verificá que Foco esté abierta, que hayas preparado la conexión desde esa copia y que el complemento esté cargado en el perfil correcto.
- **Quiero actualizar:** salí de Foco y cerrá cualquier bloque en curso antes de repetir el instalador. Después abrí la copia actualizada y volvé a preparar la conexión. No se reemplaza la carpeta de tus datos.
- **Ya tengo Foco en Aplicaciones del sistema:** elegí una sola copia para usar; el instalador nuevo utiliza la carpeta Aplicaciones de tu usuario. Prepará la conexión desde esa copia para evitar confusiones.
- **Quiero desinstalar:** quitá el complemento de Chrome, salí de Foco y mové la app a la Papelera. La [guía completa](docs/GUIA.md#desinstalar) explica cómo quitar también los datos locales si lo deseás.

## Privacidad y desarrollo

Sin servidor, anuncios, telemetría ni servicios de IA dentro de la app. Los datos se guardan localmente en `~/Library/Application Support/Foco/`. No se envían nombres de tareas ni porcentajes a Chrome. Los archivos locales no están cifrados por Foco.

- [Guía completa](docs/GUIA.md): funciones, permisos, límites, copias y desinstalación.
- [Seguridad](SECURITY.md) y [alcance de la revisión](SECURITY_REVIEW.md).
- [Cambios de versión](CHANGELOG.md).

Para desarrollar: `bash codigo/Tests/test.sh` ejecuta las pruebas (requiere Node.js 20+, Python 3 y herramientas de Apple); `bash codigo/build.sh` compila. `bash Instalar.command --check` solo comprueba requisitos, sin compilar ni instalar.

**Licencia:** todavía no se eligió una licencia para el código. No se agrega una licencia abierta automáticamente.
