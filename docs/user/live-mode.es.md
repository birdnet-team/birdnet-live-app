# Modo Live

El Modo Live es la forma más rápida de escuchar a través del micrófono del teléfono y revisar las detecciones a medida que aparecen en tiempo real.

## Cómo abrirlo

Desde la pantalla de Inicio, toca la tarjeta **Modo Live** con el icono :material-microphone:.

## Widget «Escucha rápida»

**Solo Android.** Un widget en la pantalla de inicio empieza a escuchar con un solo toque, sin tener que abrir la app y navegar hasta el modo — útil cuando oyes algo que quieres identificar antes de que deje de cantar.

Se añade como cualquier otro widget: mantén pulsado un hueco libre de la pantalla de inicio, toca **Widgets**, busca **BirdNET Live** y arrastra uno de los dos mosaicos.

- **Escucha rápida** (2×1) — icono con la etiqueta **Empezar a escuchar**
- **Escucha rápida (compacta)** (1×1) — solo el icono

Ambos hacen lo mismo. Al tocar cualquiera de ellos se abre el Modo Live y empieza a escuchar de inmediato, sea cual sea el valor del ajuste **Iniciar grabación automáticamente**. El widget no modifica ese ajuste.

Hay dos situaciones en las que un toque no hace nada a propósito:

- Hay un despliegue de [Modo ARU](aru-mode.md) en curso, así que el widget no puede interrumpir una grabación desatendida.
- El Modo Live ya está abierto con una Session en marcha o en pausa. La Session se deja tal cual en vez de reiniciarse.

## Barra superior

La barra superior contiene tres elementos:

- :material-arrow-left: — salir del Modo Live
- texto de estado central — `Inicializando…`, `Cargando modelo…`, `Listo`, `Identificando especies…`, `En pausa` o `Error`
- :material-tune: — abre la vista de Ajustes específica de Live

## Botón de acción principal

El gran botón circular de la parte inferior central cambia de estado:

- :material-microphone: — empezar a escuchar
- :material-stop: — detener la Session activa
- :material-play: — reanudar desde un estado en pausa y listo

## Lo que ves mientras escuchas

### Espectrograma

El espectrograma se desplaza continuamente mientras la captura está activa. Muestra el contenido de frecuencia a lo largo del tiempo, usando el mapa de colores, el tamaño de FFT, el rango de frecuencia y la duración configurados en Ajustes.

### Lista de detecciones

Las detecciones recientes aparecen debajo del espectrograma. Cada fila puede mostrar:

- imagen de la especie
- nombre común
- nombre científico opcional
- valor de confianza

Toca una fila de especie para abrir el panel de detalles de la especie.

### Barra de información de la Session

La línea de información compacta debajo del espectrograma resume la Session actual, por ejemplo:

- las detecciones que se muestran ahora
- recuento de especies únicas (`spp`)
- detecciones totales (`det`)
- duración transcurrida
- tamaño de grabación estimado cuando la grabación está habilitada

## Comportamiento de la grabación

La grabación se controla en [Ajustes](settings.md).

- **Completo** graba toda la Session.
- **Solo detecciones** graba clips alrededor de las detecciones.
- **Desactivado** desactiva la grabación.

Cuando detienes el Modo Live, BirdNET Live guarda la Session y abre el [Resumen de la Session](session-review.md).
