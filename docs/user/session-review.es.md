# Resumen de la Session

El Resumen de la Session es donde BirdNET Live convierte las detecciones en un registro editable.

## Cómo llegar aquí

BirdNET Live abre el Resumen de la Session automáticamente al terminar:

- una Live Session
- un Point Count
- un Survey
- un análisis de Análisis de archivos

También puedes reabrir cualquier Session guardada desde la [Biblioteca de sesiones](session-library.md).

## Áreas principales

### Resumen y reproducción

El Resumen de la Session combina la reproducción, la navegación por el espectrograma y una lista de especies. En las Sessions de Survey también puede mostrar el contexto cartográfico.

El encabezado de resumen en la parte superior de la pantalla incluye la fecha, el chip de ubicación (lat/lon más un nombre de lugar opcional cuando **Ajustes → Privacidad → Permitir búsqueda de nombre del lugar** está activado) y —cuando **Ajustes → Privacidad → Permitir consulta del clima** estaba activado en el momento de la grabación— una **fila de clima** debajo de la ubicación que muestra las condiciones registradas al final de la Session: una línea como *"20,1 °C · Llovizna · 3,2 m/s SO"* precedida por un icono del tiempo. Toca la fila para desplegar una pequeña hoja con la temperatura, el viento, la precipitación y la nubosidad, junto con la atribución a Open-Meteo. La misma instantánea se refleja en la exportación JSON, en el bloque de metadatos por Session y en el informe HTML.

La franja del espectrograma sobre el reproductor es interactiva: toca para saltar a un punto, arrastra con un dedo para recorrer la línea de tiempo y **pellizca con dos dedos para ampliar** una ventana de tiempo estrecha, útil cuando quieres examinar el momento de cantos superpuestos o separar un trino rápido. Separa los dedos de nuevo para volver a la vista general predeterminada de 10 segundos. El botón de reproducción en el encabezado de una especie elige siempre el primer grupo que realmente tiene un clip grabado, de modo que el botón está disponible siempre que alguna de las detecciones de esa especie se pueda reproducir.

### Lista de especies

Las especies se agrupan en filas expandibles. Puedes examinar las detecciones por especie y recorrer la grabación mientras las revisas. Las filas de grupo bajo una especie expandida aparecen sangradas para que la tarjeta de la especie principal se distinga visualmente de sus elementos.

Un campo de búsqueda sobre la lista filtra las especies por nombre común o científico, de modo que encontrar un ave concreta en una Session de 100 especies son unas pocas pulsaciones en lugar de un largo desplazamiento. El botón :material-sort: que hay al lado cambia el orden de las especies:

- **Mayor confianza** (predeterminado) — primero las especies con la confianza más alta en una sola detección. Útil para priorizar las identificaciones más seguras. Al expandir una especie en este modo, las detecciones con clips de audio reproducibles aparecen antes que las que no tienen clip, y luego por confianza.
- **Más detecciones** — primero las especies con mayor número de detecciones. Útil para identificar a las que más cantan.
- **A → Z** — orden alfabético por nombre común. Predecible, sensible al idioma y fácil de revisar cuando una Session tiene muchas especies.
- **Detectadas primero** — orden cronológico por hora de la primera detección. El predeterminado histórico; útil al revisar junto a la línea de tiempo del espectrograma.

El orden elegido se mantiene entre Sessions.

### Agregar una especie a mano

El botón :material-plus-circle-outline: de la barra de herramientas abre el buscador de especies para aves que BirdNET no detectó. Tocar un resultado no la inserta de inmediato: primero aparece una hoja de confirmación con la especie elegida y dos casillas:

- :material-ear-hearing: **Oída** — escuchaste el ave.
- :material-eye: **Vista** — viste el ave.

Marca una, ambas o ninguna y luego toca **Agregar**. **Cancelar** —o deslizar hacia abajo— te devuelve a la búsqueda, así que un toque equivocado no cuesta nada. **Oída** viene marcada y tu elección se mantiene para la siguiente especie, de modo que registrar una serie de aves que solo viste requiere marcar **Vista** una sola vez. Si dejas ambas sin marcar, la entrada se guarda sin tipo de observación, no como "ninguna de las dos".

La elección se guarda en la detección y aparece como un pequeño icono de oído u ojo junto a la insignia de entrada manual en todos los lugares donde se muestra esa detección: encabezados de especie, filas de grupo, el reproductor de clips y la lista del survey en vivo. También llega a las exportaciones: una columna `Evidence` en CSV y en las tablas de Raven, un campo `evidence` en JSON y una etiqueta en el informe HTML. La misma hoja aparece al usar **Reemplazar especie**, precargada con lo que ya tenía ese registro.

### Acciones por detección

En todos los lugares donde aparece una detección —la lista de especies, la hoja del reproductor de clips, la lista del Survey en vivo y los marcadores del mapa del Survey— se usa el mismo conjunto de acciones:

- :material-check: **Confirmar** — una marca de verificación de un toque que señala una detección como verificada visual o acústicamente. Los grupos confirmados y los marcadores del mapa muestran una pequeña marca verde para que destaquen de un vistazo, y la marca se conserva en todos los formatos de exportación.
- :material-dots-vertical: **Más** — abre un menú adicional con:
    - :material-share-variant: **Compartir detección** — consulta *Compartir* más abajo.
    - :material-swap-horizontal: **Reemplazar especie** — elige otra especie para esta detección.
    - :material-delete-outline: **Eliminar detección** — quita la fila de inmediato. Aparece un SnackBar para deshacer durante unos segundos, de modo que los errores son reversibles. Sin cuadro de confirmación.
    - :material-delete-sweep-outline: **Eliminar especie** — quita de la Session todas las detecciones de esa especie de una sola vez, con el mismo SnackBar para deshacer. Útil para barrer una fuente de ruido mal identificada sin tener que expandir la especie y eliminar los grupos uno a uno.

#### Atajos de deslizamiento en las filas de revisión

En la lista de especies también puedes actuar sobre una detección deslizando la fila en horizontal:

- desliza a la **derecha** → eliminar (con opción de deshacer)
- desliza a la **izquierda** → abrir el panel de reemplazo de especie

Los dos fondos están codificados por color (rojo de error frente a azul principal) para que el efecto del gesto sea evidente antes de confirmarlo.

Al deslizar una fila de **encabezado de especie** (a izquierda o derecha) se eliminan de una vez todas las detecciones de esa especie, con el mismo SnackBar para deshacer. Útil al depurar una Session llena de ruido mal identificado.

### Compartir una sola detección

La opción :material-share-variant: **Compartir detección** usa las mismas opciones que **Ajustes → Exportar y sincronizar**. Exporta solo esta detección en los artefactos Raven, CSV, JSON, GPX, HTML y metadatos de la app seleccionados. Cuando **Incluir archivos de audio** está activado, el paquete también contiene el audio de la detección; se respeta **Compartir siempre el audio como WAV**. Si se desactivan todos los formatos complementarios, HTML y los metadatos de la app, la hoja de compartir del sistema recibe el clip de audio sin ZIP.

El audio adjunto se resuelve en este orden:

1. **En Sessions que graban un único archivo continuo**: se extrae de la grabación el audio desde la marca de inicio hasta la de fin de la detección. Se admiten grabaciones continuas WAV y FLAC; las fuentes comprimidas de File Analysis se decodifican como WAV.
2. De lo contrario, se usa el clip propio guardado de la detección cuando está disponible en disco.
3. Si no hay ninguna fuente de audio y no se seleccionó ningún artefacto de exportación, se comparte un texto breve con la especie, la confianza, la marca de tiempo UTC y la ubicación.

### Notas de voz

Puedes adjuntar breves comentarios de voz a registros de detección individuales:

- **Grabar**: toca el botón :material-dots-vertical: en un grupo de detección y selecciona **Grabar nota de voz** para abrir el diálogo de nota de voz. Toca el botón grande del micrófono para empezar a grabar. Una forma de onda en vivo refleja tu voz en tiempo real. Toca el botón de detener cuando termines.
- **Revisar**: una vez grabada, puedes escuchar la nota con el reproductor integrado. Para reemplazar la nota, toca el botón **Volver a grabar**. Para guardarla, toca el botón **Guardar**.
- **Eliminar**: si una detección ya tiene una nota de voz adjunta, puedes eliminarla desde el menú adicional o desde el diálogo de nota de voz.
- **Formatos según la plataforma**: en Android y otras plataformas, las notas de voz se graban en formato AAC (`.m4a`) muy comprimido a 16 kHz. En iOS usan automáticamente el formato WAV/PCM16 (`.wav`) para evitar problemas de compatibilidad de CoreAudio con las sesiones de audio activas de la app. Ambos formatos son totalmente compatibles con el empaquetado ZIP de la exportación.
- **Exportar**: al exportar la Session como ZIP, las notas de voz se incluyen en el directorio `memos/` y sus rutas relativas se registran en los metadatos JSON y CSV.

### Mapa del recorrido del Survey

Las Sessions de Survey muestran un pequeño mapa integrado del recorrido GPS y los marcadores de detección. Toca un marcador del mapa integrado para enfocar una detección: el mapa integrado se centra en ella. Toca el botón :material-fullscreen: **expandir** (arriba a la derecha del mapa integrado) para abrir el **mapa a pantalla completa**; si había una detección enfocada, el mapa a pantalla completa se abre centrado y ampliado sobre esa detección para que no pierdas tu posición.

#### Codificación de los marcadores

- **La confianza está codificada por color** con una rampa segura para daltonismo: de menor a mayor confianza va del azul violáceo, pasando por el turquesa/amarillo, hasta el rojo. La luminosidad de la rampa cambia de forma monótona, de modo que sigue siendo legible en monocromo y para personas con deficiencia de visión del color rojo-verde.
- **Las detecciones con audio** muestran un anillo de color alrededor de la foto de la especie más una insignia de reproducción en la esquina; tócalas para abrir la misma hoja del reproductor de clips que se usa en otros lugares, con confirmar, compartir, reemplazar y eliminar disponibles.
- **Las detecciones silenciosas** (sin clip en disco) se representan más pequeñas, atenuadas y con un anillo gris neutro, de modo que las detecciones con audio se leen siempre como el contenido principal.
- **Los marcadores superpuestos en el mismo punto** se ordenan por importancia: resaltado > con audio > mayor confianza, de modo que un marcador silencioso de baja confianza nunca puede tapar una detección de audio sólida.
- **Por debajo del zoom 14,5** las siluetas se reducen a puntos de color dimensionados según la confianza, y los grupos densos se contraen en una burbuja con un número (la agrupación se desactiva con el zoom 15).

#### Filtrado

El mapa a pantalla completa tiene un **chip de filtro** fijo anclado arriba a la derecha del mapa. Tócalo para abrir la hoja de filtros; la etiqueta del chip muestra siempre lo que está en efecto (*"Todas las especies"*, *"Con audio"*, *"≥ 80 %"* o el nombre de una sola especie). Filtros disponibles:

- **Todas las detecciones** (predeterminado).
- **Con clip de audio** — solo las detecciones cuyo clip sigue en disco y se puede reproducir.
- **Añadidas manualmente** — solo las detecciones que añadiste en el Resumen de la Session (excluye las detectadas automáticamente).

También puedes restringir las detecciones por nivel de confianza. El control deslizante fija el mínimo de confianza (empieza en el 10 %).

Debajo del control de confianza hay un selector **Limitar a una especie** que permite reducir el mapa a una sola especie, útil para preguntarse "¿en qué punto exacto del recorrido oí el zorzal?". Una entrada *Todas las especies* elimina la restricción de especie. Los filtros se combinan: p. ej., *Con clip de audio* + *Zorzal* + *> 80 %* muestra solo los marcadores reproducibles de zorzal que superaron el 80 %.

Cuando hay un filtro activo, el título de la barra superior añade un subtítulo con el número de coincidencias (p. ej., *"7 detecciones"*). *Restablecer* en la hoja vuelve al valor predeterminado.

## Iconos de la barra de herramientas

La barra de herramientas usa los mismos significados de iconos descritos en [Iconos y controles](icons-and-controls.md):

- :material-plus-circle-outline: — añadir contenido
- :material-undo-variant: / :material-redo-variant: — avanzar o retroceder por las ediciones
- :material-content-cut: — modo de recorte
- :material-content-save: — guardar las ediciones
- :material-share-variant: — exportar o compartir
- :material-delete-outline: — descartar la Session
- :material-play: — continuar un Survey cuando esa acción está disponible
- :material-help-circle-outline: — abrir la hoja de ayuda del Resumen de la Session
- :material-tune: — abrir los Ajustes

## Tareas habituales de revisión

- contrastar las detecciones con la reproducción y el contexto del espectrograma
- añadir una especie o una anotación
- recortar la grabación al intervalo útil
- exportar el conjunto de resultados revisado

## Exportación

El comportamiento de la exportación depende de las opciones seleccionadas en [Ajustes](settings.md). La app puede empaquetar las detecciones y, opcionalmente, el audio en el formato de exportación elegido. Cada exportación incluye metadatos de procedencia —la versión de la app, el nombre y la versión del modelo, el idioma de las especies, la marca de tiempo de exportación, los ajustes conservados con la Session y las opciones de exportación pertinentes— escritos en un archivo adjunto `<prefix>.metadata.json` (ZIP) o en un bloque `meta` de nivel superior (JSON), de modo que las exportaciones se describen a sí mismas y son reproducibles.

El bloque `settings` de la exportación JSON registra los valores que se *aplicaron realmente a esta Session* —sensibilidad, modo de Score Pooling y número de ventanas, ganancia del micrófono y el corte del filtro de paso alto—, no los que estén configurados ahora en Ajustes. Esto significa que puedes reproducir un resultado meses después, o comparar dos Surveys, sin tener que recordar dónde estaba cada control cuando los ejecutaste.

Todas las marcas de tiempo en los nombres de archivo exportados (`BirdNET_Live_<date>_<time>_…`) y dentro de los datos CSV / JSON se formatean en la hora local *actual* de tu teléfono. Los registros subyacentes se almacenan en UTC y se convierten al exportar.
