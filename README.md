# Foco

Foco es una app para Mac que te ayuda a estudiar o trabajar con menos distracciones. Elegís qué sitios de Chrome y qué apps querés bloquear durante un bloque de concentración. Después podés ver cuánto tiempo le dedicaste a cada tarea u objetivo y registrar cómo te fue. Tus datos quedan en la Mac y no necesitás crear una cuenta.

[**Descargar Foco para Mac (ZIP)**](https://github.com/Fran-mdp/Foco/archive/refs/heads/main.zip)

Necesitás **una Mac con chip M1 o posterior, macOS 26 o posterior y Google Chrome**. El ZIP contiene el proyecto y un instalador que compila la app en tu Mac.

## Instalación rápida

1. **Descargá y descomprimí el ZIP.** Dentro de la carpeta `Foco-main` vas a encontrar `Instalar.command`.
2. **Ejecutá el instalador.** Abrí Terminal con **⌘ + Espacio** y buscá «Terminal». Escribí `bash` seguido de un espacio, arrastrá el archivo `Instalar.command` a esa ventana y presioná **Enter**. Si te faltan las herramientas de Apple, ejecutá `xcode-select --install`, esperá a que termine y repetí este paso.
3. **Abrí Foco.** En Finder, presioná **⌘⇧G**, pegá `~/Applications` y presioná **Enter**. Abrí **Foco** en esa carpeta.

El instalador puede tardar unos minutos. Deja Foco en la carpeta Aplicaciones de tu usuario y usa una firma local.

## Conectá Chrome una sola vez

1. En Foco, tocá **Conectar Chrome → Preparar conexión local → Copiar ruta**.
2. En tu perfil de Chrome, escribí `chrome://extensions` en la barra de direcciones. Activá **Modo de desarrollador** y hacé clic en **Cargar descomprimida** (también puede aparecer como **Cargar extensión sin empaquetar**). Presioná **⌘⇧G**, pegá la ruta que copiaste y elegí la carpeta.
3. Abrí **Foco** desde el menú de extensiones de Chrome y autorizá los sitios que querés bloquear. Volvé a la app y comprobá que diga **Chrome conectado**.

El complemento se carga localmente y los permisos se conceden por dominio en ese perfil de Chrome.

## Tu primer bloque

En **Foco → Editar bloqueos**, elegí sitios y aplicaciones. Guardá tu trabajo antes de empezar: las apps elegidas reciben una solicitud de cierre.

- **Flexible → Iniciar foco:** empieza al instante y podés terminar cuando quieras.
- **Configurar duración:** elegí los minutos. **Firme** mantiene el compromiso hasta que termina el tiempo.
- **Pausar:** detiene el cronómetro; los bloqueos siguen activos.
- **Mis tareas:** agregá una tarea y elegila para acumular varios bloques sobre ella. El porcentaje lo registrás vos.
- **Mi progreso:** revisá día, semana, mes, año o fechas, y encontrá tus logros debajo del gráfico y las tareas.

Foco ayuda a concentrarte; el modo firme se puede eludir desactivando el complemento o usando otro navegador. No es un control parental ni un bloqueo imposible de quitar.

## Objetivos y resultados

En **Objetivos → Nuevo**, creá algo que quieras conseguir, por ejemplo **Aprobar IPSC**, y fijá una meta opcional de horas. Podés escribir `1,5` para una hora y media.

- En **Tareas**, asociá varias tareas al objetivo. Al elegir una tarea para foco, se selecciona su objetivo.
- También podés elegir un objetivo en **Foco** y empezar un bloque sin tarea. Las pausas se excluyen en ambos casos.
- En **Progreso → Objetivo**, filtrá el gráfico, las estadísticas y los bloques. Se muestra el acumulado histórico frente a la meta y también el tiempo de las fechas elegidas.
- Al finalizar, elegí **Registrar resultado**: **Cumplido**, **Parcial** o **No cumplido**, con una nota opcional. Alcanzar las horas nunca elige el resultado automáticamente. Los objetivos cerrados quedan en **Con resultado** y ya no aceptan bloques nuevos; podés corregir su resultado.

Los bloques conservan el objetivo con el que empezaron. Mover una tarea no reasigna sus horas pasadas. En **Editar tarea**, la opción **Incluir bloques anteriores sin objetivo** permite incorporar tiempo histórico explícitamente, sin mover bloques que ya pertenecen a otro objetivo.

Podés borrar un objetivo desde su menú y deshacer durante 8 segundos. El borrado conserva sus tareas y todos los bloques como tiempo sin objetivo; al borrar solo una tarea, sus bloques siguen sumando al objetivo original. También podés asignar o corregir un bloque terminado desde el ícono de objetivo junto a su duración en **Progreso → Sesiones del período**, incluso si no tenía tarea o si el objetivo ya está cerrado. Eso no cambia sus minutos ni sus pausas. El tiempo anterior a esta versión queda sin objetivo hasta que lo asignes explícitamente.

## Calidad y dificultad

Al terminar un bloque, podés valorar tu concentración del 1 al 10 y elegir si el tema tuvo dificultad Baja, Media o Alta. Podés guardar los dos datos juntos, completar solo uno u omitir la pregunta. En **Progreso** aparece el promedio de las sesiones que valoraste según las fechas y el objetivo elegidos. En **Sesiones del período → …** podés agregar, editar o quitar cualquiera de los dos datos.

## Ayuda

- **Faltan herramientas de Apple:** ejecutá `xcode-select --install`, terminá la instalación y repetí el paso 2. Si el instalador detecta un SDK viejo, actualizá las herramientas de Apple antes de continuar.
- **Chrome no conecta:** verificá que Foco esté abierta, que hayas preparado la conexión desde esa copia y que el complemento esté cargado en el perfil correcto.
- **Quiero actualizar:** terminá el bloque en curso y salí de Foco antes de repetir el instalador. Después abrí la copia actualizada y volvé a preparar la conexión. No se reemplaza la carpeta de tus datos.
- **Ya tengo Foco en Aplicaciones del sistema:** elegí una sola copia para usar; el instalador nuevo utiliza la carpeta Aplicaciones de tu usuario. Prepará la conexión desde esa copia para evitar confusiones.
- **Quiero desinstalar:** quitá el complemento de Chrome, salí de Foco y mové la app a la Papelera. La [guía completa](docs/GUIA.md#desinstalar) explica cómo quitar también los datos locales si lo deseás.

## Privacidad y desarrollo

Sin servidor, anuncios, telemetría ni servicios de IA dentro de la app. Los datos se guardan localmente en `~/Library/Application Support/Foco/`. No se envían nombres de tareas, objetivos, resultados ni notas a Chrome. Los archivos locales no están cifrados por Foco.

- [Guía completa](docs/GUIA.md): funciones, permisos, límites, copias y desinstalación.
- [Seguridad](SECURITY.md) y [alcance de la revisión](SECURITY_REVIEW.md).
- [Cambios de versión](CHANGELOG.md).

Para desarrollar: `bash codigo/Tests/test.sh` ejecuta las pruebas (requiere Node.js 20+, Python 3 y herramientas de Apple); `bash codigo/build.sh` compila. `bash Instalar.command --check` solo comprueba requisitos, sin compilar ni instalar.

**Licencia:** todavía no se eligió una licencia para el código. No se agrega una licencia abierta automáticamente.
