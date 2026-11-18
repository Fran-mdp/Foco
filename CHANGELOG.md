# Cambios

## 0.6.1

- Tiempo por día antes de tareas y logros; logros debajo de la actividad.
- Gráfico semanal completo de lunes a domingo, con etiquetas para los siete días, incluso sin actividad.
- Barras más delgadas y promedios que siguen excluyendo los días futuros.
- Cambios implementados directamente por Codex a pedido del usuario; Windows queda para una etapa posterior.

## 0.6.0

- Logros históricos: primera tarea a tiempo, día completo y semana completa; estrellas y trofeos simbólicos.
- Avance de hoy provisorio y confirmación al cerrar cada período; días sin tareas neutros.
- Fecha original anclada y evidencia mínima sin nombre para tareas borradas, evitando inflar logros al mover o borrar.
- Compatibilidad con datos previos y 19 escenarios de pruebas de logros, incluidos zonas horarias, deshacer y límite de registros.
- Implementado por Gemini 3.8 Flash High y revisado mediante git diff y pruebas locales.

## 0.5.2

- Borrar tarea desde su menú, con Deshacer durante 8 segundos y cierre del aviso con ✕.
- El borrado conserva el tiempo de foco como Sin tarea; deshacer recupera tarea, porcentajes y vínculos existentes.
- Protección de la tarea de un bloque activo y prevención de vínculos a tareas borradas al restaurar sesiones.

## 0.5.1

- Pantalla de foco más compacta, selector de tarea con etiqueta separada y botón principal de alto contraste.
- Acciones principales y secundarias con estilos distintos; textos secundarios más legibles en claro/oscuro.
- Filas de tareas compactas, anchura de lectura limitada y estadísticas diarias sin una tarjeta extra.
- Dashboard con tarjetas alineadas y explicaciones, comparación y meta diaria desplegables.
- El temporizador conserva la duración elegida al reabrirlo; validación visible de nombres demasiado largos al editar.

## 0.5.0

- Lista de tareas por día con edición, pendientes anteriores, completado y archivo reversible.
- Sesiones vinculadas a una tarea y tiempo acumulado a partir de intervalos efectivos, con pausas excluidas.
- Avance manual por día de 0 a 100%, registro explícito sin avance y visibilidad de días sin actividad.
- Panel de tareas dentro del dashboard con los filtros existentes y tiempo sin asignar.
- Compatibilidad con el historial previo y nombres/identificadores de tareas excluidos de los mensajes a Chrome.

## 0.4.1

- El aviso de sesión eliminada se cierra con ✕ o desaparece automáticamente a los 8 segundos. Cerrar el aviso conserva la eliminación.

## 0.4.0

- Pausar y reanudar desde la sesión, la barra de menús o ⌘⇧P; el bloqueo se conserva en ambos modos.
- Cronómetro y temporizador basados en tiempo activo; las pausas sobreviven al reinicio y no suman al dashboard.
- Papelera por sesión, deshacer la última eliminación y acceso a todo el historial filtrado con Mostrar más.
- Compatibilidad con sesiones e historial anteriores y pruebas de pausas, vencimiento, medianoche, borrado y restauración.

## 0.3.0

- Editor de sitios y aplicaciones desde la app, con activación individual y eliminación.
- Bloqueo por dominio o ruta; selección fija durante la sesión.
- Permisos opcionales de Chrome por dominio, con retiro al eliminar el último sitio del dominio.
- Validación de paquetes y exclusión de aplicaciones esenciales y herramientas protegidas.
- Corrección de la confirmación del bloqueo ante fallos de permisos.
- Pruebas de reglas, editor, errores, sesión, métricas y protocolo nativo.
- Documentación de instalación desde código, configuración, privacidad, seguridad y límites de distribución.

## 0.2.0

- WhatsApp de escritorio y web opcionales.
- Dashboard con día, semana, mes, año, fechas y meta diaria opcional.

## 0.1.0

- Cronómetro y temporizadores flexibles o firmes.
- Interfaz nativa Liquid Glass y bloqueo inicial de Instagram/YouTube.
- Recordatorios motivacionales locales.
