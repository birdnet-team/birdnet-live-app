# Iconos y controles

Esta página explica los controles y símbolos recurrentes que se usan en todo BirdNET Live. Las etiquetas de abajo coinciden exactamente con los controles tal como aparecen en la app.

## Iconos de los modos

Estas son las mismas formas de iconos que usa la aplicación. Aquí heredan el color del texto; los colores de la aplicación varían con el tema, color dinámico y alto contraste.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **Modo ARU**
- :app-audioFileRounded: **Análisis de archivos**
- :app-sdStorage: **Análisis por lotes** (Próximamente)

## Controles de navegación compartidos

| Control | Dónde aparece | Qué hace |
|---|---|---|
| :app-tuneRounded: **Ajustes** | Pie de la pantalla de inicio, Live, Point Count, Survey, Análisis de archivos, Resumen de la Session | Abre los Ajustes. En las pantallas de modo, abre los ajustes más relevantes para ese flujo de trabajo. |
| :app-searchRounded: **Explorar** | Pie de la pantalla de inicio | Abre Explorar. |
| :app-libraryMusic: **Biblioteca** | Pie de la pantalla de inicio | Abre la Biblioteca de sesiones. |
| :app-helpOutlineRounded: **Ayuda** | Pie de la pantalla de inicio, encabezado de Explorar, panel del Survey, barra de herramientas del Resumen de la Session | Abre la Ayuda o una hoja de ayuda específica de la pantalla. |
| :app-infoOutline: **Información / Acerca de** | Pie de la pantalla de inicio, barras de información, hojas de ayuda | Muestra información general o contexto resumido. |
| :app-arrowBackRounded: **Atrás** | Modo Live | Vuelve a la pantalla anterior. |
| :app-openInNew: **Abrir externo** | Pantalla Acerca de, enlaces de documentación | Abre una página externa, como la Guía de Usuario en línea. |
| :app-arrowUpwardRounded: **Volver arriba** | Pantalla de ayuda | Vuelve a la introducción y los accesos a secciones. Aparece al desplazarse hacia abajo. |
| :app-volunteerActivism: **Donar** | Pantalla Acerca de | Abre la página de donaciones de BirdNET. |

## Símbolos meteorológicos

| Símbolo | Significado |
|---|---|
| :app-wbSunny: **Despejado** | Cielo despejado. |
| :app-partlyCloudyDay: **Parcialmente nublado** | Sol y nube para tiempo mayormente despejado o parcialmente nublado. |
| :app-cloudy: **Cubierto** | Cobertura nubosa total. |
| :app-foggy: **Niebla** | Niebla o niebla con escarcha. |
| :app-rainyLight: **Llovizna** | Precipitación ligera. |
| :app-rainy: **Lluvia** | Lluvia o chubascos. |
| :app-weatherSnowy: **Nieve** | Nieve o chubascos de nieve. |
| :app-thunderstorm: **Tormenta** | Condiciones de tormenta. |

## Controles de inicio, parada y Session

| Control | Significado |
|---|---|
| :app-micRounded: **Micrófono** | Inicia la escucha en vivo. |
| :app-stopRounded: **Detener** | Detiene una grabación, un Point Count o un Survey en curso. |
| :app-playArrowRounded: **Reproducir** | Inicia un flujo de configuración ya preparado o reanuda desde un estado en pausa y listo. |
| :app-close: **Cerrar** / :app-stop: **Cancelar** | Cancela un Análisis de archivos en curso desde la cabecera o la pantalla de progreso. |
| :app-timerOutlined: **Temporizador** | Duración o tiempo restante. |
| :app-errorOutline: **Error** | Error del modelo o del procesamiento. |

## Controles de ubicación y fecha

| Control | Significado |
|---|---|
| :app-myLocation: **Ubicación actual** | Usa la posición GPS actual del dispositivo. |
| :app-editLocationAlt: **Coordenadas manuales** | Introduce las coordenadas manualmente. |
| :app-locationOff: **Sin ubicación** | Omite la ubicación o indica que la ubicación no está disponible. |
| :app-locationOn: **Con ubicación** | Confirma una ubicación, muestra coordenadas o etiqueta una Session situada en el mapa. |
| :app-refresh: **Actualizar** | Vuelve a leer la ubicación actual o recarga una lista de predicciones. |
| :app-mapSheet: **Selector de mapa** | Elige coordenadas en el selector de mapa. |
| :app-calendarToday: **Fecha** | Establece o muestra una fecha. |
| :app-clear: **Borrar** | Quita la fecha seleccionada. |

## Símbolos de Explorar y especies

| Control | Significado |
|---|---|
| Miniatura de la especie | Imagen incluida para la especie cuando está disponible. |
| Insignia de porcentaje de confianza o del geomodelo | Un resumen numérico rápido del resultado del modelo. Los números más altos indican un mayor respaldo dentro del contexto de esa pantalla. |
| Etiquetas de meses (`Ene`, `Abr`, `Jul`, `Oct`, `Dic`) | Puntos de referencia en el gráfico semanal de frecuencia esperada del panel de especie. |

## Acciones por detección

Estos controles aparecen en cada fila de detección de toda la app: la lista de especies del Resumen de la Session, la hoja del reproductor de clips, la lista de detecciones del Survey en vivo y los marcadores del mapa del Survey. Consulta [Resumen de la Session → Acciones por detección](session-review.md#acciones-por-detección) para conocer todo su comportamiento.

| Control | Significado |
|---|---|
| :app-checkCircleOutline: **Confirmar** | Marca de verificación de un toque que señala una detección como verificada visual o acústicamente. Las detecciones confirmadas muestran una pequeña marca verde en las filas de grupo y en los marcadores del mapa. |
| :app-moreVert: **Más** | Abre el menú adicional de la detección con **Compartir detección**, **Reemplazar especie**, **Eliminar detección** y **Eliminar especie**. |
| :app-share: **Compartir detección** | Comparte una detección mediante la hoja de compartir del sistema, adjuntando el clip de audio siempre que haya uno disponible, incluido un fragmento de la grabación en curso durante un Survey en vivo. |
| :app-swapHoriz: **Reemplazar especie** | Elige otra especie para esta detección. También se abre deslizando una fila de revisión hacia la izquierda. |
| :app-deleteOutline: **Eliminar detección** | Quita la fila de inmediato. Aparece un SnackBar para deshacer durante unos segundos. También se activa deslizando una fila de revisión hacia la derecha. |
| :app-deleteSweep: **Eliminar especie** | Quita de la Session todas las detecciones de esa especie de una sola vez, con el mismo SnackBar para deshacer. |
| :app-hearing: **Oída** | En una detección agregada a mano: escuchaste el ave. Se define con la casilla de la hoja de confirmación que aparece tras elegir la especie. |
| :app-visibility: **Vista** | En una detección agregada a mano: viste el ave. Ambos iconos juntos significan oída *y* vista. |

## Barra de herramientas del Resumen de la Session

Estos controles se usan en la pantalla del Resumen de la Session.

| Control | Significado |
|---|---|
| :app-addCircleOutline: **Agregar** | Añade contenido, como una especie o una anotación. |
| :app-undo: **Deshacer** / :app-redo: **Rehacer** | Retrocede o avanza un paso por las ediciones de la revisión. |
| :app-contentCut: **Recortar** | Entra en el modo de recorte o indica que el modo de recorte está activo. |
| :app-save: **Guardar** | Guarda los cambios de la revisión. |
| :app-share: **Compartir** | Exporta o comparte la Session. |
| :app-deleteOutline: **Eliminar** | Descarta la Session. |
| :app-playArrowRounded: **Continuar** | Continúa un Survey sin terminar desde el Resumen de la Session cuando esa acción está disponible. |

## Barras de estado específicas de cada pantalla

### Modo Live

La barra de información de Live usa :app-infoOutline: seguido de etiquetas compactas como:

- `now` — detecciones visibles actualmente en la lista en vivo
- `spp` — número de especies únicas
- `det` — detecciones totales
- duración y tamaño estimado de la grabación cuando la grabación está activa

### Point Count

La barra del temporizador del Point Count combina :app-stopRounded: **Detener**, :app-timerOutlined: **Temporizador** y una barra de progreso para mostrar el tiempo restante de la Session cronometrada.

### Survey

El panel del Survey usa:

- :app-map: **Mapa** — pestaña del mapa en vivo
- :app-graphicEq: **Espectrograma** — pestaña del espectrograma
- :app-summaryChart: **Resumen** — pestaña de resumen
- :app-summaryChart: etiquetas de estadísticas en la vista de resumen del Survey

## En caso de duda

Si no tienes claro qué hace un control, abre la hoja de ayuda más cercana en la app o consulta la página del flujo de trabajo de esa pantalla en esta guía del usuario.
