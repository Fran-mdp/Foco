# Revisión de seguridad — Foco 0.5.2

Revisión local del código y sus límites de confianza, realizada el 14 de noviembre de 2026. Estado: **revisión con límites conocidos**, no certificación de seguridad.

## Alcance

SwiftUI, persistencia local, validación de sitios y paquetes `.app`, host Native Messaging, reglas Manifest V3, solicitud de permisos por dominio, scripts de build, pruebas y archivos preparados para publicación. No había un repositorio Git ni historial de commits que auditar. No se auditó el sistema operativo, los binarios de Chrome ni sus dependencias internas.

No hay dependencias descargadas por el proyecto, servidor, API de terceros, credenciales de nube, contenedores ni pipeline de despliegue. Por eso no se aplica un análisis de CVEs de dependencias npm/pip ni una auditoría de infraestructura remota.

## Resultado y cambios

No se identificaron vulnerabilidades confirmadas de alta confianza en la revisión inicial. Una verificación independiente de los límites de archivos y protocolo tampoco encontró elevación de privilegios ni ejecución remota. Se implementaron y probaron estas correcciones y protecciones:

| Área | Resultado |
|---|---|
| Publicación | Quitados nombres de las instrucciones e identificación visible; no se incluyen historial, rutas personales, manifiesto de conexión ni claves privadas. La clave de la extensión es pública. |
| Permisos | Sin acceso obligatorio a dominios. Cada origen HTTP/HTTPS se solicita por un gesto explícito en Chrome. |
| Reglas | Dominios y rutas validados en Swift y JavaScript. Sin regex ni comandos proporcionados por el usuario. Las rutas se escapan antes de generar reglas. |
| Confirmación | Un error de aplicación de reglas persiste durante los heartbeats. No se informa bloqueo confirmado ante un permiso denegado. |
| Aplicaciones | Paquetes seleccionados, identificador y ruta real validados; componentes esenciales y herramientas protegidas excluidos. Sin cierre forzado. |
| Sesiones | Selección copiada al iniciar, permisos comprobados y cambios de configuración rechazados durante una sesión. |
| Host nativo | Operaciones limitadas, origen esperado, UUID de perfil, tamaño de frame acotado, sin puerto de red ni ejecución de shell. |
| Datos | Directorio privado y archivos de estado/bloqueo con permisos de usuario; actualizaciones atómicas bajo lock. |
| Build | Sin descargas, temporales privados y rechazo explícito de symlinks o apps ajenas en el destino generado. |

## Validación

Pruebas locales de sesiones, métricas, compatibilidad de datos, reglas de dominio/ruta, sitios pendientes de permiso, bloqueo de edición durante sesiones, protección de apps, persistencia de errores y protocolo nativo entre procesos. Las comprobaciones de publicación buscan patrones de credenciales, correos y rutas personales sin enviar archivos a servicios externos.

## Comprobación en la Mac

Se verificó en pantalla el catálogo de aplicaciones con búsqueda, el agregado de Spotify, su desactivación, el guardado y su eliminación posterior. Se agregó y eliminó una ruta de YouTube. Con una sesión activa limitada a `/feed/subscriptions`, la portada de YouTube permaneció disponible y la ruta elegida mostró la pantalla de bloqueo con una frase motivacional. Se terminó la sesión y se restauró la selección original.

La actualización de permisos opcionales para dominios HTTP/HTTPS se instaló tras autorización explícita. Chrome conservó únicamente los cuatro dominios previamente autorizados; no se otorgó acceso global. Se verificó la firma local de la app instalada. La prueba visual del editor se realizó con una copia temporal del mismo ejecutable, por una inconsistencia del registro de aplicaciones del control remoto; esa copia no se distribuye.

## Riesgos residuales y límites

- Un usuario o proceso con los permisos del dueño de la Mac puede modificar sus archivos, desactivar el complemento o ejecutar manualmente el host. El argumento de origen no autentica por sí solo procesos locales. El host no concede privilegios superiores a los de ese usuario.
- Un permiso de dominio cubre también sus subdominios. La declaración opcional permite futuros dominios, pero no los autoriza automáticamente.
- Una aplicación puede rechazar el cierre normal; la interfaz debe informar ese estado. El modo firme no impide la manipulación del equipo ni es un sistema de administración parental.
- Los archivos locales no están cifrados por la app. La protección de la cuenta, del disco y del sistema sigue siendo necesaria.
- Los binarios tienen firma local ad hoc; no hay Developer ID, notarización ni proceso de releases públicas autenticadas. Para terceros, el método documentado es revisar y compilar el código.
- No se eligió licencia y no se creó ni publicó un repositorio remoto.

Esta revisión asistida por IA no garantiza ausencia de vulnerabilidades y no sustituye una auditoría profesional independiente.

## Cambio incremental 0.4.0

Se agregaron pausas persistidas y borrado individual con restauración en memoria de la última sesión eliminada. No se amplían permisos, operaciones del host ni acceso a dominios o aplicaciones. La pausa conserva las reglas de bloqueo y la selección de sesión; el modo firme sigue rechazando la finalización anticipada. Las métricas almacenan intervalos de concentración para excluir descansos incluso al cruzar la medianoche. El historial anterior se interpreta como intervalos continuos. El botón Deshacer está disponible durante 8 segundos y se puede cerrar con ✕; cerrar el aviso no restaura la sesión eliminada.

Se probaron la congelación y reanudación del cronómetro, el vencimiento por tiempo activo, la persistencia al reiniciar, las reglas y alarmas de Chrome durante la pausa, el cálculo diario y el borrado/restauración sin duplicados. Este cambio tuvo revisión local y pruebas; no una nueva auditoría independiente completa.

Comprobación visual de 0.4.0: se conservó la sesión existente al actualizar; se verificó Pausar con cronómetro congelado y bloqueo activo, Reanudar, borrar un registro individual y restaurarlo con Deshacer. Chrome mostró el complemento 0.4.0. El registro usado en la prueba fue restaurado y la sesión quedó activa.

Corrección 0.4.1: el aviso anterior no tenía cierre ni vencimiento. Se verificaron en la app instalada la ✕ y la desaparición automática sin restaurar los registros eliminados, usando únicamente dos registros QA de un segundo; ambos quedaron retirados. La sesión real se conservó. Las pruebas del modelo cubren cierre, vencimiento y restauración.

## Cambio incremental 0.5.0

Se agregan tareas y porcentajes diarios locales, con títulos de hasta 160 caracteres, sin caracteres de control y un límite de 5000 tareas. Archivar conserva los vínculos y el historial. Cada bloque solo puede elegir una tarea pendiente al comenzar; las transacciones y el lock existentes protegen también tareas y avances. Los porcentajes no se infieren del cronómetro. No hay nuevas dependencias ni permisos. El host excluye la referencia a la tarea de los mensajes a Chrome; no transmite títulos, porcentajes ni la lista de tareas. Las pruebas verifican esta exclusión, migración, suma entre bloques, pausas, filtros por fecha, registro sin avance y persistencia del historial. Esta ampliación tiene revisión local y pruebas; no una nueva auditoría independiente completa.

Verificación visual de 0.5.0: alta de tarea, registro manual de 25%, selección para foco, bloque real vinculado sin cierre de apps, finalización del bloque manteniendo la tarea pendiente, registro explícito sin avance, dashboard y completado al 100%. Se retiraron la tarea temporal y su bloque; el historial real y las selecciones de bloqueo se conservaron. La prueba de regresión también cubre que una tarea pendiente de ayer siga visible al completarse hoy.

Cambio 0.5.1: ajustes de presentación, contraste y jerarquía; sin nuevos permisos ni cambios en el formato de datos. Se conservaron las tres tareas existentes. Historial de sesiones, sesión activa y configuración coinciden con el estado previo; se conservó también la edición de avance realizada durante la revisión.

Cambio 0.5.2: borrado de tareas bajo la transacción local existente. Conserva los registros de foco desvinculados y permite restaurar los vínculos de registros aún existentes. Se protege la tarea de una sesión activa. Las pruebas de transacción, avisos y restauración pasaron; se verificó el menú, borrar y deshacer con una tarea temporal que se retiró al terminar. Sin nuevos permisos ni dependencias.

## Revisión 0.6.0 — logros

Cambios limitados a ocho archivos de cálculo, persistencia, vista, pruebas y compilación. Informe del implementador contrastado con Git; diff sin errores de formato. No hay nuevos permisos de Chrome, dependencias ni conexiones de red de la app. Metadatos de logros locales y sin títulos para tareas borradas, con límite de 5000 y fallo antes de borrar al agotarlo. Tipos opcionales para conservar compatibilidad. Pruebas de privacidad del host nativo, bloqueo, pausas y tareas existentes pasaron junto a los 19 escenarios nuevos. No equivale a una garantía de ausencia de vulnerabilidades.
