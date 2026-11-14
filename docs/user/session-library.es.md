# Biblioteca de Sessions

La Biblioteca de Sessions es el archivo de Sessions guardadas y archivos procesados.

## Cómo abrirla

Usa el botón :app-libraryMusic: en el pie de página de Inicio.

## Lo que muestra la biblioteca

Cada entrada de Session resume un conjunto de resultados guardado, incluido su tipo, fecha, duración, recuento de especies y recuento de detecciones.

Los tipos de Session usan los mismos iconos que la pantalla de Inicio:

- :app-micRounded: — Live Session
- :app-audioFileRounded: — Session de Análisis de archivos
- :app-locationOnRounded: — Session de Point Count
- :app-routeRounded: — Session de Survey

## Controles de la barra de aplicaciones

- :app-searchRounded: — busca por fecha, tipo de Session, nombre del lugar, coordenadas, nombre común o nombre científico
- menú de modo de vista — cambia entre **Detallado**, **Compacto** y **Por especie**
- :app-filterList: — cambia el criterio de ordenación

## Modos de visualización

### Detallado

Muestra tarjetas de Session completas con más metadatos.

### Compacto

Muestra filas más estrechas para una navegación más rápida. Cada fila tiene un botón :app-expandMore: a la derecha que la expande en su sitio para mostrar el cuerpo completo de la tarjeta de la vista Detallado: práctico cuando quieres echar un vistazo rápido a las estadísticas de una Session concreta sin perder tu posición de desplazamiento.

### Por especie

Agrupa las Sessions por especie y se expande para mostrar las Sessions que contienen esa especie.

## Ordenación

Ordena las Sessions por **fecha** (más recientes o más antiguas primero), **nombre** (A–Z o Z–A) o **duración** (más largas o más cortas primero). La ordenación por duración es útil cuando quieres encontrar tu Survey más largo de la semana, o la prueba más corta de 30 segundos que guardaste por accidente.

Cuando las Sessions se agrupan por día, cada fila de encabezado de día muestra primero el menú de tres puntos (:app-moreVert:) para las acciones de todo el día, con la flecha de expandir/contraer en el extremo final de la fila. La flecha es el *último* elemento interactivo —la misma convención que en cualquier otra lista expandible de la app—, de modo que un toque cerca del borde derecho siempre alterna el grupo.

## Hora local

Cada marca de tiempo que se muestra en la biblioteca de Sessions —filas de la lista, encabezados de grupo de día, distintivos de "iniciada" / "finalizada"— se representa en la zona horaria local *actual* de tu teléfono. Las marcas de tiempo subyacentes de la Session se almacenan en UTC, así que una Session que ejecutaste en Berlín y luego abriste en Nueva York simplemente se muestra cinco (o seis) horas antes: los datos en disco no cambian. Si viajas durante un Survey largo, el reloj mostrado sigue al dispositivo.

## Acciones de fila

Cada fila de Session tiene dos formas de actuar sobre ella:

- **Menú de tres puntos** (:app-moreVert:) a la derecha de cada tarjeta abre un pequeño menú con **Abrir**, **Compartir** y **Eliminar**. Compartir abre un diálogo cuyas casillas **Audio** y **Metadatos** parten de lo elegido en Ajustes → Exportación y sincronización y valen solo para ese envío, y después abre el menú de compartir de la plataforma, sin necesidad de abrir antes la revisión de la Session solo para enviar una Session a un colega.
- **Desliza** la fila hacia la izquierda o la derecha para eliminarla. Sigue apareciendo un cuadro de confirmación antes de que se elimine nada, de modo que un deslizamiento accidental es recuperable.

## Qué ocurre a continuación

Toca cualquier Session para abrir la [revisión de la Session](session-review.md).
