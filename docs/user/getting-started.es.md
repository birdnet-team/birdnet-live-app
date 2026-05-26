# Empezando

## Instalación

BirdNET Live está disponible para Android, iOS y Windows.

### Requisitos

- **Android**: 8.0 (API 26) o posterior
- **iOS**: 15.0 o posterior
- **Windows**: 10 o posterior (experimental)
- ~300 MB de almacenamiento para aplicaciones y modelos

### Descargar

*Los enlaces de distribución se agregarán cuando estén disponibles.*

## Flujo de aplicación por primera vez

Cuando abre BirdNET Live por primera vez, la aplicación recorre un breve flujo de incorporación y configuración de permisos.

1. Lea las pantallas de incorporación.
2. Acepte los Términos de uso y la Política de privacidad.
3. Otorgue permiso al micrófono para que BirdNET Live pueda procesar el audio.
4. Opcionalmente, permita el permiso de ubicación para geoetiquetado, Explorar, Conteo de puntos y Encuesta.
5. Opcionalmente, permita notificaciones para encuestas de larga duración.

## Primer lanzamiento

1. **Incorporación**: introducción rápida a funciones y permisos
2. **Términos y privacidad**: acepte los términos de uso y la política de privacidad
3. **Permisos**: otorgar acceso al micrófono (obligatorio para todos los modos)
4. **Listo** — ¡Empiece a identificar aves!

## Descripción general de la pantalla de inicio

La pantalla de inicio es el centro principal.

### Tarjetas de modo principal

- :material-micrófono: **Modo En Vivo**
- :material-map-marker: **Modo de recuento de puntos**
- :material-routes: **Modo Encuesta**
- :material-file-music: **Análisis de archivos**

### Widgets de Android

En Android, puede añadir el widget **BirdNET Live shortcut** a la pantalla de inicio. Algunos dispositivos y hosts de widgets también permiten colocar el mismo widget en la pantalla de bloqueo.

- Al tocar el widget, la app se abre directamente en **Live Mode** y comienza a grabar automáticamente en cuanto el modelo está listo.
- Si la app todavía necesita onboarding o aceptar los Terms, BirdNET Live completa primero ese flujo y luego abre Live Mode. La grabación comienza automáticamente en cuanto el modelo está listo.
- La disponibilidad en la pantalla de bloqueo depende de la versión de Android, del fabricante del dispositivo y del host de widgets; muchos teléfonos siguen ofreciendo solo la colocación en la pantalla de inicio.
- El widget es solo para Android; iOS y Windows no comparten el mismo sistema de widgets.

### Botones de pie de página

- :material-tune: **Configuración**
- :material-magnify: **Explorar**
- :material-music-box-multiple-outline: **Biblioteca de sesiones**
- :material-help-circle-outline: **Ayuda**
- :material-information-outline: **Acerca de**

## Lo que se guarda

BirdNET Live guarda automáticamente las sesiones completadas y las abre en Revisión de sesión después de que se detiene el procesamiento.

- Las sesiones en vivo guardan detecciones y, según su configuración, grabaciones o clips.
- Las sesiones de conteo de puntos se guardan como sesiones de conteo de puntos cronometradas.
- Las sesiones de encuesta guardan la ruta, las detecciones y los metadatos relacionados.
- Los resultados del análisis de archivos se convierten en una sesión revisable.

## Páginas siguientes recomendadas

- Lea [Iconos y controles](icons-and-controls.md) si desea una explicación rápida de los símbolos recurrentes de la interfaz de usuario.
- Lea [Configuración] (settings.md) antes de cambiar umbrales, filtros, comportamiento de grabación o visualización del espectrograma.
- Abra la guía para el flujo de trabajo que utiliza con más frecuencia: [Modo en vivo](live-mode.md), [Modo de recuento de puntos](point-count-mode.md), [Modo de encuesta](survey-mode.md) o [Análisis de archivos](file-analysis.md).

## Permisos

| Permiso | Requerido para | ¿Opcional? |
|------------|-------------|-----------|
| Micrófono | Todos los modos de grabación | Requerido |
| Ubicación | Etiquetado GPS, levantamiento/recuento de puntos | Opcional para vivir |
| Almacenamiento | Guardar grabaciones, exportaciones | Requerido para grabar |
| Notificaciones | Alertas de encuestas de antecedentes | Opcional |
