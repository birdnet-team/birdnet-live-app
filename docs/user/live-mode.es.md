# Modo Live

El Modo Live es la forma más rápida de escuchar a través del micrófono del teléfono y revisar las detecciones a medida que aparecen en tiempo real.

## Cómo abrirlo

Desde la pantalla de Inicio, toca la tarjeta **Modo Live** con el icono :app-micRounded:.

## Widget «Escucha rápida»

**Solo Android.** Un widget en la pantalla de inicio empieza a escuchar con un solo toque, sin tener que abrir la app y navegar hasta el modo — útil cuando oyes algo que quieres identificar antes de que deje de cantar.

Se añade como cualquier otro widget: mantén pulsado un hueco libre de la pantalla de inicio, toca **Widgets**, busca **BirdNET Live** y arrastra uno de los dos mosaicos.

- **Escucha rápida** (2×1) — icono con la etiqueta **Empezar a escuchar**
- **Escucha rápida (compacta)** (1×1) — solo el icono

Ambos hacen lo mismo. Al tocar cualquiera de ellos se abre el Modo Live y empieza a escuchar de inmediato, sea cual sea el valor del ajuste **Iniciar grabación automáticamente**. El widget no modifica ese ajuste.

Si el Modo Live ya está abierto, el widget vuelve a esa misma pantalla en vez de reconstruirla. Una Session en marcha o en pausa continúa sin cambios; si está detenida, la escucha comienza en la pantalla existente.

Escucha rápida nunca sustituye a otro modo en ejecución. Si se está ejecutando o iniciando una Session de Point Count, Survey, File Analysis o [Modo ARU](aru-mode.md), la app pasa a primer plano y te pide que detengas primero esa Session. Su pantalla y su trabajo siguen accesibles y no se interrumpen.

## Barra superior

La barra superior contiene tres elementos:

- :app-arrowBackRounded: — salir del Modo Live
- texto de estado central — `Inicializando…`, `Cargando modelo…`, `Listo`, `Identificando especies…`, `En pausa` o `Error`
- :app-tuneRounded: — abre la vista de Ajustes específica de Live

## Botón de acción principal

El gran botón circular de la parte inferior central cambia de estado:

- :app-mic: — empezar a escuchar
- :app-stopRounded: — detener la Session activa
- :app-playArrowRounded: — reanudar desde un estado en pausa y listo

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

Cuando el guardado automático de sesiones está activado, el Modo Live también guarda una Session parcial al inicio, cada 30 segundos y cuando la aplicación pasa a segundo plano. Tras un cierre inesperado o un corte de energía, la última copia guardada está disponible en la Biblioteca de sesiones. Pueden perderse los cambios posteriores a esa copia. Al desactivar el guardado automático también se desactivan estos guardados intermedios.

## Escuchar con la pantalla apagada

Live Mode normalmente se pausa al bloquear la pantalla o salir de la aplicación y reanuda la misma Session al volver. La primera vez, un diálogo ofrece escucha limitada en segundo plano. En los [ajustes de grabación](settings.md), activa **Continuar con la pantalla apagada** y elige un máximo de 15, 30, 60 o 120 minutos (30 de forma predeterminada). El límite se aplica a cada período fuera de la aplicación; alcanzarlo termina la Session. Android muestra una notificación persistente con Abrir y Detener. En Windows, Live Mode sigue escuchando con la ventana minimizada.
