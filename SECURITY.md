# Seguridad

## Modelo de confianza

Foco es una ayuda de autocontrol local. Se ejecuta con los permisos normales del usuario, sin administrador. No es un producto parental, un sistema antimanipulación, una VPN ni una protección frente a un usuario local malicioso.

La app guarda su estado y selección en archivos privados del usuario. El complemento recibe una copia de la sesión mediante Native Messaging y confirma las reglas aplicadas. Los permisos HTTP/HTTPS son opcionales y se solicitan por dominio, mediante una acción explícita en el complemento. Los datos de páginas web no se ejecutan como código.

El host solo acepta operaciones de saludo y confirmación, limita el tamaño de los mensajes y restringe el origen de extensión esperado. La lista `allowed_origins` de Chrome restringe los clientes normales. El argumento de origen no autentica a otro proceso local del mismo usuario que ejecute el host manualmente. El host no ofrece comandos del sistema, carga de programas ni un servidor de red.

Las aplicaciones se validan como paquetes `.app`; los objetivos se limitan al identificador y ruta real seleccionados. Se excluyen componentes esenciales y herramientas protegidas. El cierre es normal, nunca forzado.

## Fuera de alcance

El dueño de la Mac puede desactivar la extensión, editar sus archivos o ejecutar código con sus propios permisos. La firma ad hoc solo detecta modificaciones del paquete respecto de esa firma local; no acredita la identidad del distribuidor. El código se debe revisar y compilar desde una fuente de confianza. Para distribuir binarios a terceros hacen falta firma Developer ID y notarización con un proceso de publicación verificable.

No hay credenciales de servicios externos que rotar ni tráfico de analíticas. Los historiales y selecciones son datos personales locales y no deben adjuntarse a incidencias públicas.

## Reportar un problema

Si el proyecto se publica en GitHub y tiene avisos privados de seguridad habilitados, usá esa vía. En caso contrario contactá en privado a su mantenedor antes de revelar una vulnerabilidad. No incluyas contraseñas, tokens, mensajes, historial de navegación ni datos de sesiones en un issue público. Indicá versión, sistema, pasos reproducibles e impacto con datos ficticios.

La revisión asistida por IA no garantiza ausencia de vulnerabilidades y no sustituye una auditoría profesional.
