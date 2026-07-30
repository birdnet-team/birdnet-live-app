# Modo Survey

El Modo Survey es el flujo de trabajo basado en rutas para surveys en movimiento de larga duración.

## Cómo abrirlo

Desde Inicio, toca la tarjeta **Modo Survey** con el icono :material-routes:.

## Flujo de configuración

La configuración del Survey es un asistente de cinco pasos.

### 1. Detalles

Puedes introducir:

- el Nombre del Survey
- el ID de transecto
- el Nombre del observador
- GPS, coordenadas manuales o sin ubicación inicial

Este paso también muestra el selector de mapa, actualiza el GPS cuando vuelves
de las pantallas de permisos del sistema y muestra el recordatorio de permiso
de GPS en segundo plano cuando es necesario. En la misma área de ubicación hay
una tarjeta de clima. Si el acceso al clima está desactivado, solicita tu
consentimiento con **Permitir consulta del clima**; una vez activado, ofrece
una vista previa del sitio solo con un icono del tiempo, la temperatura y el
viento. La misma instantánea en caché de Open-Meteo se reutiliza al guardar el
Survey.

### 2. Parámetros

Este paso contiene parámetros específicos del Survey, como:

- selección del Micrófono
- Tasa de inferencia
- umbral de confianza
- Intervalo GPS
- Duración máxima
- modo de Grabación
- Contexto del clip para la grabación de solo clips
- modo de Muestreo de detecciones
- límite de Top N por especie cuando el muestreo es limitado

#### Muestreo de detecciones

Un survey largo puede producir miles de detecciones, y guardar un clip de audio para cada una de ellas llena rápidamente el almacenamiento. El Muestreo de detecciones controla **qué clips se conservan en el disco**: *los registros de detección en sí siempre se conservan*, por lo que el registro completo de tu Session permanece intacto sea cual sea el modo. Los registros cuyo audio se descartó simplemente no tienen un clip reproducible en el Resumen de la Session.

Hay tres modos disponibles:

| Modo | Qué hace |
|---|---|
| **Todas** | Conserva todos los clips. El mayor uso de disco. Recomendado para surveys cortos o cuando quieres el audio de cada detección para analizarlo más tarde. |
| **Top N** | Conserva solo los **N clips de mayor confianza por especie**. Los demás clips se eliminan a medida que avanza el survey. El valor predeterminado de N es 10, configurable de 1 a 50. |
| **Smart** | El mismo límite de N por especie que Top N, **más** distribución espacial: si una nueva detección cae en el mismo "lugar" que un clip ya conservado (a menos de ~500 m y ~2 min de diferencia entre sí), solo el de mayor confianza conserva su clip. Esto evita que un único cantor estacionario monopolice todos los espacios de N y orienta los clips conservados hacia cubrir todo el transecto. |

El límite de N es **por especie, no global**: si grabas 10 petirrojos y 10 pinzones, conservas 20 clips. No hay un límite general sobre la cantidad de clips que puede producir un survey.

En el modo Smart, si falta el GPS en una detección, la comprobación de mismo lugar recurre a una ventana basada solo en el tiempo (~2 min). Con el GPS disponible, tanto la distancia como el tiempo deben solaparse para que dos detecciones cuenten como el mismo lugar.

### 3. Alertas de especies

Notificaciones de tipo push que se activan a mitad del survey cuando se detecta algo digno de mención. Elige una de:

- **Desactivada** — sin alertas (predeterminado).
- **Primera en la Session** — una alerta la primera vez que se escucha cada especie durante este survey.
- **Primera vez** — alerta solo cuando la aplicación encuentra una especie por primera vez en todas tus sesiones (una alerta de "lifer"). Respaldada por un historial de especies de por vida que se completa automáticamente a partir de tus sesiones existentes en el primer inicio.
- **Rara para este lugar** — alerta cuando la probabilidad del geomodelo para la ubicación actual está por debajo de un umbral configurable. Una lectura en vivo debajo del control deslizante explica exactamente qué activará el valor actual (por ejemplo, *"Alerta en especies con menos del 5 % de probabilidad en este lugar."*).
- **Lista de seguimiento** — alerta solo en las especies que hayas añadido a una lista personalizada guardada. El propio paso del asistente te permite crear nuevas listas de seguimiento, editar las existentes en un editor a pantalla completa dedicado con taxonomía con búsqueda e *Importar desde archivo* (cualquier `.txt`/`.csv` simple de nombres científicos), y eliminar las listas que ya no necesites.

Un control deslizante de *Confianza mínima* se encuentra debajo del selector de modo y se ajusta automáticamente como mínimo al umbral de confianza de tu Session (las alertas nunca son más sensibles que las propias detecciones). Una sección **Avanzada** expone controles de limitación: una ventana de gracia al inicio, un intervalo mínimo estricto entre dos alertas cualesquiera, y un límite deslizante por minuto con combinación opcional de las alertas que superen el límite en una única notificación de resumen, todo con selectores de chip de un solo toque. La primera vez que cambias a un modo distinto de Desactivada, el asistente solicita por ti el permiso de notificaciones de Android.

### 4. Consejos de campo

Una breve lista de verificación previa al inicio dentro del flujo de configuración.

### 5. Listo

La pantalla de listo resume la configuración del survey activo antes de empezar con :material-play:.

## Panel del Survey en vivo

La pantalla del Survey en vivo tiene tres pestañas principales más una lista de detecciones recientes.

### Barra superior

- :material-stop: — finalizar el survey
- :material-timer: — tiempo transcurrido
- :material-help-circle-outline: — abre la hoja de ayuda del Survey
- :material-tune: — abre los ajustes del Survey

### Pestañas

- :material-map-outline: — mapa de la ruta y detecciones cartografiadas
- :material-equalizer: — espectrograma
- icono de gráfico — estadísticas de resumen y desglose de especies

### Estadísticas y detecciones

Debajo del contenido de la pestaña, el panel del survey muestra una barra de estadísticas y una lista de detecciones recientes. Al tocar una detección se abre el panel de detalles de la especie.

Cada fila de detección también ofrece las mismas acciones por detección que se usan en el [Resumen de la Session](session-review.md): una marca de verificación :material-check: **Confirmar** de un toque y un menú adicional :material-dots-vertical: **Más** con **Compartir detección** y **Eliminar detección** (con deshacer en SnackBar), para que puedas validar, compartir o eliminar una detección ruidosa durante la captura en lugar de esperar al resumen posterior a la sesión.

Las mismas acciones están disponibles desde el **mapa de ruta en vivo**: toca el marcador de una detección para abrir la hoja del reproductor de clips con confirmar, compartir y eliminar. Compartir durante un survey funciona incluso cuando has optado por una única grabación WAV continua en lugar de clips por detección: la ventana de audio correspondiente se recorta sobre la marcha del archivo en curso. Consulta [Resumen de la Session → Compartir una sola detección](session-review.md#compartir-una-sola-deteccion) para más detalles.

### Registrar una observación

El botón :material-plus-circle-outline: del survey en vivo abre un pequeño menú con **Agregar especie** y **Agregar nota**. **Agregar especie** abre el mismo buscador que [Session Review](session-review.md#agregar-una-especie-a-mano), elige una especie, luego marca :material-ear-hearing: **Oída** o :material-eye: **Vista** en la hoja de confirmación y toca **Agregar**. La entrada recibe la marca de tiempo de ese momento y la posición GPS actual, y aparece de inmediato en la lista de detecciones y en el mapa de la ruta con la insignia manual y los iconos de oído / ojo correspondientes.

Las notas de voz no están disponibles aquí a propósito: el micrófono está ocupado con la grabación del propio survey. Agrégalas en Session Review cuando termine.

## Funcionamiento en segundo plano

El Modo Survey mantiene visible una notificación persistente en primer plano durante la grabación para que Android no suspenda el pipeline de audio. La notificación se expande para mostrar:

- el tiempo transcurrido, el recuento de detecciones, el recuento de especies y la distancia recorrida, y
- las **tres especies únicas más recientes** con su confianza y una marca de tiempo relativa (`justo ahora`, `hace 42 s`, `hace 5 min`, `hace 2 h`).

La notificación —título, detecciones recientes y pie de estadísticas— está completamente traducida al idioma seleccionado de la app y usa las mismas preferencias de idioma de especies y *Mostrar nombres científicos* que las tarjetas dentro de la app.

Las alertas de especies (cuando están habilitadas) aparecen en un canal de notificaciones de Android independiente, de modo que puedes silenciar las alertas de forma separada de la notificación silenciosa de grabación en curso. El icono de alerta coincide con el icono de la notificación en primer plano (un pájaro monocromo) y los cuerpos de las alertas muestran solo el *motivo* —*"Primera detección de este survey"*, *"En tu lista de seguimiento"*, *"Detectada en este lugar con menos del 4 % de probabilidad"*—, dejando el nombre de la especie en el título en negrita de la notificación, donde Android lo muestra más grande.

Cuando **reanudas** un survey sin terminar desde la Biblioteca de sesiones, el pipeline de alertas se vuelve a configurar a partir de tus preferencias de notificación *actuales*, no las que tenías configuradas el día que empezaste el survey. Desactiva las alertas (o cambia el modo, la lista de seguimiento o la limitación) antes de tocar Continuar Survey y el survey reanudado respetará la nueva configuración de inmediato.

## Revisar en el mapa

La vista del mapa del Survey a pantalla completa (el botón :material-fullscreen: en el Resumen de la Session) abre un reproductor de clips cuando tocas un marcador. La fila de transporte tiene botones de saltar al anterior y saltar al siguiente que flanquean el control de reproducción: recorren las detecciones en orden cronológico, pero **solo las que están visibles en el mapa en ese momento**, por lo que cualquier filtro activo de especie, confianza o chip de modo reduce la lista de reproducción en consecuencia. Los botones se atenúan en la primera y la última detección de la lista filtrada.

## Después de detener

BirdNET Live guarda el Survey terminado y abre el [Resumen de la Session](session-review.md).
