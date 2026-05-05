# Revisión de la sesión

Session Review es donde BirdNET Live convierte las detecciones en un registro editable.

## Cómo alcanzarlo

BirdNET Live abre la Revisión de sesión automáticamente después de completar:

- una sesión en vivo
- un recuento de puntos
- una encuesta
- una ejecución de análisis de archivos

También puede volver a abrir cualquier sesión guardada desde la [Biblioteca de sesiones](session-library.md).

## Áreas principales

### Resumen y reproducción

Session Review combina reproducción, navegación por espectrograma y una lista de especies. Para sesiones de encuesta, también puede mostrar el contexto mapeado.

### Lista de especies

Las especies se agrupan en filas ampliables. Podrás inspeccionar las detecciones por especie y moverte por la grabación mientras las revisas.

### Mapa de seguimiento de la encuesta

Las sesiones de encuesta muestran un pequeño mapa en línea de la ruta GPS y los marcadores de detección. Tócalo para abrir un **mapa en pantalla completa** con los mismos datos.

La barra de aplicaciones del mapa en pantalla completa tiene un botón :material-filter-list-outlined: **filtro** que abre una hoja para restringir qué marcadores se muestran. Filtros disponibles:

- **Todas las detecciones** (predeterminado).
- **Con clip de audio**: solo detecciones cuyo clip todavía está en el disco y se puede reproducir.
- **Confianza alta**: solo detecciones con un 80 % de confianza o más.
- **Adiciones manuales**: solo las detecciones que agregó en la Revisión de sesión (excluye las detectadas automáticamente).

Debajo del selector de modo hay un selector **Limitar a especies** que le permite contraer el mapa a una sola especie, lo que resulta útil para preguntar "¿dónde exactamente a lo largo de la ruta escuché el zorzal?". Una entrada *Todas las especies* elimina la restricción de especies. Los dos filtros se combinan: p.e. *Con clip de audio* + *Wood Thrush* muestra solo los marcadores de Wood Thrush reproducibles.

Cuando un filtro está activo, el título de la barra de aplicaciones obtiene un subtítulo de recuento de coincidencias (por ejemplo, *"7 detecciones"*) y el botón de filtro muestra un pequeño punto. *Restablecer* en la hoja vuelve al valor predeterminado.

## Iconos de la barra de herramientas

La barra de herramientas utiliza los mismos significados de íconos descritos en [Iconos y controles](icons-and-controls.md):

- :material-plus-circle-outline: — agregar contenido
- :material-undo-variant: / :material-redo-variant: — paso a paso por las ediciones
- :material-content-cut: — modo de recorte
- :material-content-save: — guardar ediciones
- :material-share-variant: — exportar o compartir
- :material-delete-outline: — descartar sesión
- :material-play: — continuar una encuesta cuando esa acción esté disponible
- :material-help-circle-outline: — abre la hoja de ayuda de Revisión de la sesión
- :material-tune: — abre Configuración

## Tareas típicas de revisión

- comprobar las detecciones en comparación con la reproducción y el contexto del espectrograma
- agregar una especie o anotación
- recortar la grabación al intervalo útil
- exportar el conjunto de resultados revisado

## Exportar

El comportamiento de exportación depende de las opciones seleccionadas en [Configuración](settings.md). La aplicación puede empaquetar detecciones y, opcionalmente, audio en el formato de exportación elegido. Cada exportación ahora se envía con metadatos de procedencia completos (la versión de la aplicación, el nombre y la versión del modelo, la configuración regional de la especie, la marca de tiempo de exportación y una instantánea de todas las configuraciones en el momento de la exportación) escritos en un archivo lateral `"<prefix>.metadata.json"` (ZIP) o en un bloque `meta` de nivel superior (JSON) para que las exportaciones sean autodescriptivas y reproducibles.
