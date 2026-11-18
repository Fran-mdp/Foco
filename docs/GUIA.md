# Foco

Aplicación personal de concentración para macOS, con interfaz nativa Liquid Glass, bloqueo de sitios en Chrome, cierre de aplicaciones elegidas y un dashboard local de progreso.

## Requisitos

- Mac con Apple Silicon y macOS 26 o posterior.
- Google Chrome de escritorio.
- Para compilar: herramientas de línea de comandos de Xcode con SDK de macOS 26 o posterior, Python 3 y Bash.
- Para ejecutar todas las pruebas: también Node.js 20 o posterior. No se instalan paquetes de npm ni dependencias de terceros.

## Compilar e instalar desde el código

Revisá el código que descargaste antes de ejecutarlo. Desde la raíz del proyecto:

```sh
./codigo/Tests/test.sh
./codigo/build.sh
```

El build produce `Foco-Mac.zip` y una copia de `Foco.app`. El paquete se firma localmente con firma ad hoc y se verifica antes de crear el ZIP. No tiene firma Developer ID ni notarización de Apple; una firma local no demuestra la identidad de quien te entregó un binario.

Para instalar, expandí `Foco-Mac.zip` en una carpeta local y mové **Foco.app** a **Aplicaciones**. Si es una actualización, terminá la sesión de Foco y salí de la aplicación antes de reemplazarla. No hace falta desactivar Gatekeeper, el firewall, la protección de integridad ni otros controles de macOS. Si macOS rechaza un binario descargado, usá una compilación propia de código que hayas revisado.

La copia del ZIP evita los metadatos adicionales que iCloud puede agregar a un `.app` visible. Los datos del usuario se guardan fuera del paquete y no se reemplazan al actualizar.

## Conectar Chrome

1. Abrí **Foco → Conectar Chrome → Preparar conexión local**.
2. En el perfil de Chrome que vas a usar, entrá a `chrome://extensions`.
3. Activá **Modo de desarrollador** y elegí **Cargar extensión sin empaquetar**.
4. Elegí la carpeta `Foco.app/Contents/Resources/Extension-Chrome` de la app instalada. En el selector de carpetas podés usar ⌘ + Shift + G para escribir esa ruta.
5. Abrí el complemento **Foco** desde el menú de extensiones de Chrome. Autorizá los dominios que quieras bloquear.
6. La app debe indicar **Chrome conectado** antes de iniciar una sesión.

El complemento es una versión local, sin publicar ni revisar por Chrome Web Store. La conexión se vincula al primer perfil de Chrome que la activa; otros perfiles e incógnito quedan fuera del alcance. Si movés Foco.app, volvé a preparar la conexión local desde la app.

## Elegir sitios y aplicaciones

En **Concentrarme → Editar sitios y aplicaciones**:

- Agregá un dominio, por ejemplo `instagram.com`, para incluir ese dominio y sus subdominios.
- Agregá una URL con ruta, por ejemplo `example.com/feed`, para incluir esa ruta y sus descendientes. No bloquea `example.com/feedback`. La ruta distingue mayúsculas y minúsculas.
- Los parámetros y fragmentos de una URL no se guardan ni se usan como filtro. No pegues contraseñas ni enlaces privados.
- Desmarcá un elemento para conservarlo sin bloquearlo. La papelera lo quita de la lista; al quitar la última entrada de un dominio, el complemento retira también su permiso opcional de Chrome.
- **Agregar app…** abre una lista con buscador de las aplicaciones instaladas en las carpetas habituales de la Mac. Se permite elegir varias. Se pide un cierre normal; no se usa cierre forzado.
- Guardá los cambios. Para un dominio nuevo, abrí el complemento y elegí **Autorizar** junto a ese dominio. Podés retirar ese permiso desde el mismo panel, fuera de una sesión.

La declaración de permisos *opcionales* permite pedir cualquier dominio HTTP/HTTPS, porque la lista la decide el usuario. Eso **no concede acceso a toda la web**: cada permiso se pide por dominio mediante un clic en Chrome. Los permisos incluyen los subdominios del dominio autorizado. No hay scripts de contenido ni permisos generales para leer historial, cookies o contraseñas. La extensión consulta únicamente las pestañas de dominios autorizados para redirigir las que coincidan con las reglas.

No se pueden agregar Foco, Chrome, componentes esenciales de macOS ni determinadas herramientas protegidas de acceso remoto al trabajo. Los objetivos se validan por identificador y ruta real del paquete. Si una app cambia de lugar o se desinstala, quitá esa entrada y agregala de nuevo.

Se admiten hasta 100 sitios y 50 aplicaciones. La lista no se edita durante una sesión activa: la sesión conserva una copia de la selección con la que empezó.

## Usar las sesiones

- **Flexible → Iniciar foco:** el cronómetro empieza inmediatamente. Podés terminar cuando quieras.
- **Configurar duración:** 25, 50, 90 minutos o un tiempo de 1 a 180 minutos.
- **Firme:** requiere duración y no ofrece terminar desde la app antes de tiempo. El bloqueo termina al vencer el plazo.

Una página bloqueada muestra un recordatorio motivacional local. Al terminar aparecen enlaces para volver a navegar; una pestaña ya redirigida no vuelve sola a la página anterior.

Guardá tu trabajo antes de iniciar: las apps seleccionadas reciben una solicitud de cierre normal. Algunas pueden rechazarla o mostrar una confirmación. Foco informa si una app no se pudo cerrar. Puede abrirse brevemente antes de que la vigilancia vuelva a pedir su cierre.

## Tareas y avance diario

En **Mis tareas**, elegí un día, escribí el nombre y tocá **Agregar**. Podés editar nombre/fecha, completar, volver a pendiente o archivar. Las tareas pendientes de días anteriores también aparecen en la lista de hoy. Archivar conserva el historial y permite restaurar la tarea desde **Ver archivadas**. Para quitar una tarea, abrí su menú **… → Borrar tarea**. Podés deshacer la última eliminación durante 8 segundos o cerrar el aviso con ✕. Sus bloques de foco se conservan como **Sin tarea**. No se puede borrar la tarea de un bloque activo: primero terminá ese bloque.

Tocá **Elegir para foco** o elegí una tarea en **Concentrarme** antes de iniciar. Podés empezar sin tarea: ese tiempo aparece como **Sin tarea**. Cada bloque queda vinculado a una única tarea; para cambiar de tarea, terminá el bloque e iniciá otro. El tiempo se acumula entre bloques, excluye pausas y se conserva aunque renombres o archives la tarea. Para completar una tarea en curso, primero terminá su bloque. Los bloques anteriores a esta versión permanecen sin asignar.

En **Registrar avance**, elegí el porcentaje **total** alcanzado al terminar ese día. Por ejemplo, si ayer estabas en 25% y hoy guardás 50%, el dashboard muestra +25 puntos de avance. **No avancé este día** guarda el porcentaje anterior y registra explícitamente que no hubo avance. Un porcentaje de 100% completa la tarea; trabajar un bloque no cambia automáticamente su porcentaje. No se registran avances futuros. Si corregís un día anterior, se conserva el estado de los días posteriores.

La lista de tareas muestra el tiempo acumulado de toda su vida. En **Mi progreso**, el panel de tareas usa el filtro de día, semana, mes, año o fechas: muestra tiempo dentro del filtro, porcentaje alcanzado al cierre y cambio declarado. **Sin actividad registrada** significa que no hay bloques ni avance guardado para esas fechas; no permite inferir si trabajaste fuera de Foco. Las tareas pendientes siguen apareciendo en días sin actividad. Las completadas se cuentan por la fecha registrada de finalización. Borrar un bloque descuenta su tiempo de la tarea; Deshacer lo restaura.

Los nombres y los porcentajes se guardan solo en el archivo local de Foco: no se envían al complemento ni a servicios externos.

### Descansos sin sumar tiempo

Tocá **Pausar** en la sesión, en el panel de la barra de menús o usá **⌘⇧P**. El cronómetro y el tiempo restante se congelan. Los sitios y las aplicaciones siguen bloqueados, incluso en modo firme. Tocá **Reanudar** al volver: la sesión continúa con el tiempo pendiente. La pausa se conserva al cerrar y volver a abrir Foco; se excluye del dashboard, incluso si cruza la medianoche.

### Quitar sesiones accidentales

En **Mi progreso → Sesiones del período**, tocá la papelera de la sesión que querés quitar. Los totales, los promedios y el gráfico se recalculan. **Deshacer** restaura la última eliminación durante 8 segundos. El aviso desaparece solo o podés cerrarlo con la ✕; en ambos casos la sesión sigue eliminada. Usá **Mostrar más sesiones** para acceder a los registros anteriores del filtro. La sesión en curso no se borra desde el historial.

## Progreso

**Mi progreso** tiene filtros Día, Semana (lunes a domingo), Mes, Año y Fechas. El gráfico admite seleccionar valores para ver su detalle.

- **Tiempo en sesiones:** suma dentro del filtro, incluida la sesión en curso. Reparte las sesiones que cruzan medianoche.
- **Promedio por día:** incluye días sin sesiones y solo los días transcurridos del filtro. Hoy es parcial.
- **Promedio por sesión:** duración completa de las sesiones terminadas cuya fecha de inicio está en el filtro.
- **Días con sesiones:** días con tiempo registrado.
- **Comparación:** días completos del filtro frente a igual cantidad de días inmediatamente anteriores; excluye hoy y no calcula un porcentaje sobre cero.
- **Meta diaria:** opcional y editable. No activa bloqueos ni horarios.

Estos datos miden tiempo de sesiones, no atención real ni calidad de estudio. Una sesión abierta mientras no estudiás o mientras la Mac duerme sigue contando tiempo si no la pausás. No se inventa historial anterior a la instalación.

## Privacidad y límites

No hay servidor, cuentas, telemetría, anuncios, analíticas ni llamadas a servicios de IA. La conexión Chrome–app usa el protocolo nativo local de Chrome; no abre un puerto de red.

- Datos: `~/Library/Application Support/Foco/`.
- Registro de conexión: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/local.foco.bridge.json`.
- Preferencias de apariencia y meta: preferencias locales de macOS.

Los archivos de estado tienen permisos de usuario. No están cifrados por la app; la seguridad del equipo y del disco sigue siendo necesaria. No compartas tu historial ni el archivo de conexión al publicar el proyecto.

Firme es una ayuda personal, **no una frontera de seguridad contra el dueño del equipo**. Podés eludirlo desactivando la extensión, modificando tus datos, usando otro navegador o perfil, o cambiando el reloj. Cerrar la ventana no termina la sesión. Para seguir vigilando apps debe permanecer Foco o el host nativo de Chrome ejecutándose; salir de Foco y cerrar Chrome detiene esa vigilancia. No controla el teléfono ni otros dispositivos.

## Estructura

```text
codigo/Sources/          SwiftUI, estado, validación, métricas y host nativo
codigo/Extension/        Manifest V3, reglas, permisos y página motivacional
codigo/Tests/            Pruebas de sesiones, filtros, reglas y protocolo
codigo/Resources/        Info.plist e ícono
codigo/build.sh         Build local sin descargas
SECURITY.md             Modelo de seguridad y reporte de problemas
SECURITY_REVIEW.md      Alcance y resultado de la revisión de esta versión
```

El identificador de la extensión y su clave **pública** están versionados para conservar su identidad local. No hay clave privada de firma en el repositorio. El antiguo identificador de la app solo se conserva en protecciones y migraciones cuando hace falta compatibilidad.

## Desinstalar

Terminá o esperá a que venza la sesión. Quitá el complemento en `chrome://extensions`, salí de Foco y mové la app a la Papelera. Para una limpieza completa podés quitar manualmente la carpeta de datos y el registro de conexión indicados arriba. No hay servicios de administrador, VPN, reglas de firewall ni modificaciones de DNS instaladas por Foco.

## Estado del proyecto

Versión personal en desarrollo. La revisión de código y las pruebas no garantizan ausencia de vulnerabilidades ni sustituyen una auditoría profesional. No subas binarios como releases oficiales hasta definir un proceso de firma, notarización y verificación de procedencia. Este proyecto no fue publicado automáticamente en GitHub.

## Licencia

Todavía no se eligió una licencia. Un repositorio visible públicamente no concede por sí solo permiso general para redistribuir o modificar el código. No se agregó una licencia por decisión del titular; la guía de instalación no cambia ese estado.

## Logros (0.6.0)

En **Mi progreso → Tus logros** se muestran tres hitos: primera tarea a tiempo, primer día con todas las tareas completas y primera semana completa. Los contadores históricos suman estrellas por días completos y trofeos por semanas completas; no cambian al filtrar el dashboard.

El porcentaje lo declarás vos. Para cumplir a tiempo, registrá el 100% durante el día planificado originalmente. Hoy es provisorio: el día y la semana se confirman al terminar. Los días sin tareas son neutros y una semana vacía no da premio. Mover una tarea no cambia su fecha original a efectos de estos logros.

Al borrar una tarea se eliminan su nombre y porcentajes; se conserva localmente un registro mínimo (identificador, fechas y cumplimiento a tiempo) para que el borrado no cree logros falsos ni quite uno ya cumplido. Deshacer restaura la tarea y retira ese registro mínimo. Las tareas borradas antes de instalar esta versión no se pueden reconstruir.

## Gráfico semanal (0.6.1)

Tiempo por día aparece encima de tareas y logros. La vista Semana muestra los siete días, de lunes a domingo, con barras más delgadas. Los días futuros aparecen sin actividad y no entran en el promedio diario. La versión actual sigue siendo para Mac; la versión Windows queda pendiente de una etapa posterior.
