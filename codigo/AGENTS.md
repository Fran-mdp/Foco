# Foco: coordinación e implementación

Preferencia actualizada del usuario (18 de noviembre de 2026): Codex implementa y revisa directamente. No delegar estos cambios a Gemini.

- Dividir el trabajo en encargos pequeños con archivos permitidos y comprobaciones concretas.
- Trabajar en una copia aislada del código; incorporar solo cambios revisados.
- Codex inspecciona cambios, ejecuta pruebas y devuelve correcciones al implementador cuando haga falta.
- No publicar, hacer push ni instalar la app como parte automática de un encargo de código.
- No acceder a datos reales de Foco, perfiles de Chrome, llavero ni archivos personales externos. Las pruebas usan directorios temporales.
- No tocar FortiClient ni Windows App.
- No usar --dangerously-skip-permissions. Mantener el sandbox y no ampliar acceso fuera del proyecto.
- No modificar pruebas para ocultar fallos ni afirmar verificaciones que no se ejecutaron.

Verificación del proyecto: bash Tests/test.sh
Compilación: bash build.sh (genera app y ZIP en el directorio padre; solo cuando el encargo lo permita).

Los logros ya están implementados; conservar las reglas que evitan inflarlos al borrar o mover tareas.
