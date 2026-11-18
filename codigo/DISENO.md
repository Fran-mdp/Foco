# Foco — decisiones de diseño

App de concentración personal, en macOS 26 o posterior. Su trabajo principal es iniciar una sesión sin obligar a completar un formulario.

## Lenguaje visual

- Material: Liquid Glass nativo de SwiftUI; no una captura ni una web disfrazada de app.
- Fondo claro niebla `#ECF2F1`; fondo oscuro tinta `#0E161B`; acento jade `#339C82`; reflejo lavanda `#858FDB`; texto con colores semánticos del sistema para adaptarse a contraste y apariencia.
- Tipografía SF Rounded para marca, títulos y tiempo; SF para instrucciones. Números monoespaciados para que el contador no salte.
- Gesto distintivo: una esfera de tiempo con un arco fino. El cronómetro cuenta hacia arriba; el tiempo restante se muestra aparte en sesiones con duración. El arco de sesiones abiertas representa la primera hora; el de temporizadores representa su duración.
- La información auxiliar no compite con el inicio: sitios protegidos, minutos de hoy y una indicación breve.

## Comportamiento

Ventana ancha: sesión a la izquierda y paneles auxiliares a la derecha. Por debajo de 820 puntos: una columna con desplazamiento, sin perder botones. Ventana mínima de 390 × 640 puntos. El selector de duración usa 25, 50, 90 minutos y entrada libre de 1 a 180 minutos.

Modo flexible inicial: Iniciar foco empieza al instante. Modo firme: requiere elegir duración antes de empezar. Una sesión firme abierta sin plazo no podría terminar automáticamente, por eso no se admite.

La app dice «bloqueados» solo después de que Chrome confirme las reglas. Si falta la conexión, explica el siguiente paso. Pausar congela el cronómetro y conserva los bloqueos; terminar está disponible en modo flexible. Cerrar una ventana no termina la sesión.

La apariencia sigue la Mac, los controles son nativos y accesibles por teclado. Sin animaciones ambientales continuas. El contador también tiene una etiqueta accesible.

## Objetivos

Navegación compacta Foco, Tareas, Objetivos, Progreso. Un objetivo reúne tareas y bloques directos; la meta de horas y la evaluación del resultado son datos distintos. Al cerrarlo, comparar tiempo realizado con planificado sin indicar que todavía faltan horas de trabajo. El dashboard distingue acumulado histórico y fechas elegidas. Los logros generales permanecen independientes del objetivo filtrado.
