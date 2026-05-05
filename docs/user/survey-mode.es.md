# Transecto

El Transecto es el flujo de trabajo basado en rutas para recorridos móviles de larga duración.

## Cómo abrirlo

Desde Inicio, toque la tarjeta **Transecto** con el ícono :material-routes:.

## Flujo de configuración

La configuración del transecto es un asistente de cinco pasos.

### 1. Detalles

Puedes ingresar:

- nombre del transecto
- identificación del transecto
- nombre del observador
- GPS, coordenadas manuales o sin ubicación inicial

Este paso también expone el selector de mapas y el recordatorio de permisos de GPS en segundo plano cuando sea necesario.

### 2. Parámetros

Este paso contiene parámetros específicos del transecto, como:

- selección de micrófono
- tasa de inferencia
- umbral de confianza
- intervalo GPS
- duración máxima
- modo de grabación
- contexto de clip para grabación de solo detección
- modo de muestreo de detección
- límite superior de N por especie cuando el muestreo es limitado

#### Muestreo de detección

Un transecto largo puede producir miles de detecciones y guardar un clip de audio para cada una de ellas llena rápidamente el almacenamiento. El muestreo de detección controla **qué clips se guardan en el disco**: *los registros de detección siempre se guardan*, por lo que el registro completo de la sesión permanece intacto independientemente del modo. Los registros cuyo audio se eliminó simplemente no tienen ningún clip reproducible en Session Review.

Hay tres modos disponibles:

| Modo | Qué hace |
| --- | --- |
| **Todos** | Guarde cada clip. La mayor parte del uso del disco. Recomendado para transectos cortos o cuando desea conservar el audio de cada detección para su análisis posterior. |
| **N mejores** | Conserve solo los **N clips de mayor confianza por especie**. Otros clips se eliminan a medida que se ejecuta el transecto. El N predeterminado es 10, configurable de 1 a 50. |
| **Inteligente** | El mismo límite de N por especie que el N superior, **más** distribución espacial: si una nueva detección aterriza en el mismo "lugar" que un clip ya guardado (dentro de ~500 m y ~2 min de diferencia entre sí), solo el de mayor confianza mantiene su clip. Esto evita que un cantante estacionario monopolice todos los N espacios y desvía los clips conservados para cubrir todo el transecto. |

El límite de N es **por especie, no global**: si registra 10 petirrojos y 10 pinzones, conserva 20 clips. No hay un límite general en la cantidad de clips que un transecto puede producir.

En el modo Inteligente, si falta el GPS en una detección, la verificación en el mismo lugar vuelve a una ventana de solo tiempo (~2 min). Con el GPS disponible, tanto la distancia como el tiempo deben superponerse para que dos detecciones cuenten como el mismo lugar.

### 3. Alertas de especies

Notificaciones push que se activan durante el transecto cuando se detecta algo digno de mención. Elige un modo:

- **Desactivado**: sin alertas (predeterminado).
- **Primero en la sesión**: una alerta la primera vez que se escucha a cada especie durante este transecto.
- **Por primera vez**: alerta solo cuando la aplicación encuentra una especie por primera vez en todas sus sesiones (una alerta "de por vida"). Respaldado por un historial de especies de por vida que se completa automáticamente a partir de sus sesiones existentes en el primer lanzamiento.
- **Raro para esta ubicación**: alerta cuando la probabilidad del modelo geográfico para la ubicación actual está por debajo de un umbral configurable. Una lectura en vivo debajo del control deslizante explica exactamente en qué se activará el valor actual (por ejemplo, *"Alertas sobre especies con menos del 5 % de probabilidad en esta ubicación".*).
- **Lista de seguimiento**: alerta solo sobre las especies que haya agregado a una lista personalizada guardada. El paso del asistente en sí le permite crear nuevas listas de seguimiento, editar las existentes en un editor de pantalla completa dedicado con taxonomía con capacidad de búsqueda e *Importar desde archivo* (cualquier `.txt`/`.csv` simple de nombres científicos) y eliminar listas que ya no necesita.

Un control deslizante de *Confianza mínima* se encuentra debajo del selector de modo y se reduce automáticamente al umbral de confianza de su sesión (las alertas nunca son más sensibles que las detecciones mismas). Una sección **Avanzada** expone controles de limitación: una ventana de gracia de inicio, un intervalo mínimo estricto entre dos alertas y un límite deslizante por minuto con combinación opcional de alertas de exceso de límite en una única notificación de resumen, todo con selectores de chip de un solo toque. La primera vez que cambia a un modo no apagado, el asistente solicita permiso de notificación de Android por usted.

### 4. Consejos de campo

Una breve lista de verificación previa al inicio dentro del flujo de configuración.

### 5. Listo

La pantalla de resumen muestra la configuración activa del transecto antes de comenzar con :material-play:.

## Panel del transecto en vivo

La pantalla del transecto en vivo tiene tres pestañas principales más una lista de detecciones recientes.

### Barra superior

- :material-stop: — finalizar el transecto
- :material-timer: — tiempo transcurrido
- :material-help-circle-outline: — abre la hoja de ayuda del transecto
- :material-tune: — abre la configuración del transecto

### Pestañas

- :material-map-outline: — mapa de ruta y detecciones cartografiadas
- :material-ecualizador: — espectrograma
- ícono de gráfico: resumen de estadísticas y desglose de especies

### Estadísticas y detecciones

Debajo del contenido de la pestaña, el panel del transecto muestra una barra de estadísticas y una lista de detecciones recientes. Al tocar una detección se abre la superposición de detalles de la especie.

## Operación en segundo plano

El modo Transecto mantiene visible una notificación persistente en primer plano durante la grabación para que Android no suspenda la canalización de audio. La notificación se expande para mostrar:

- el tiempo transcurrido, el recuento de detecciones, el recuento de especies y la distancia recorrida, y
- las **tres especies únicas más recientes** con su confianza y una marca de tiempo relativa (`justo ahora`, `hace 42s`, `hace 5m`, `hace 2h`).

La notificación (título, detecciones recientes y pie de página de estadísticas) está completamente traducida al idioma seleccionado de la aplicación y utiliza las mismas preferencias de especie, configuración regional y *Mostrar nombres científicos* que las tarjetas de la aplicación.

Las alertas de especies, cuando están habilitadas, aparecen en un canal de notificación de Android separado para que pueda silenciarlas independientemente de la notificación silenciosa de grabación en curso. El ícono de alerta coincide con el ícono de notificación en primer plano, un pájaro monocromático, y el cuerpo de la alerta muestra solo el *motivo*: *"Primera detección de este transecto"*, *"En tu lista de vigilancia"*, *"Detectado en esta ubicación con menos del 4 % de probabilidad"*, dejando el nombre de la especie en el título de la notificación en negrita, donde Android lo muestra más grande.

## Después de parar

BirdNET Live guarda el transecto terminado y abre [Revisión de sesión](session-review.md).
