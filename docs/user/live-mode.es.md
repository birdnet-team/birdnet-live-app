# Modo en vivo

El modo en vivo es la forma más rápida de escuchar a través del micrófono del teléfono y revisar las detecciones a medida que aparecen.

## Cómo abrirlo

Desde la pantalla de inicio, toque la tarjeta **Modo en vivo** con el ícono :material-micrófono:.

## Barra superior

La barra superior contiene tres elementos:

- :material-arrow-left: — salir del modo en vivo
- texto de estado central: "Inicializando", "Cargando modelo", "Listo", "Identificando especies", "Pausado" o "Error".
- :material-tune: — abre la vista de Configuración específica de Live

## Botón de acción principal

El gran botón circular en la parte inferior central cambia de estado:

- :material-micrófono: — empieza a escuchar
- :material-stop: — detener la sesión activa
- :material-play: — reanudar desde un estado en pausa y listo

## Lo que ves mientras escuchas

### Espectrograma

El espectrograma se desplaza continuamente mientras la captura está activa. Muestra contenido de frecuencia a lo largo del tiempo y utiliza el mapa de colores, el tamaño de FFT, el rango de frecuencia y la duración de Configuración.

### Lista de detección

Las detecciones recientes aparecen debajo del espectrograma. Cada fila puede mostrar:

- imagen de especie
- nombre común
- nombre científico opcional
- valor de confianza

Toque una fila de especie para abrir la superposición de detalles de la especie.

### Barra de información de la sesión

La línea de información compacta debajo del espectrograma resume la sesión actual, por ejemplo:

- las detecciones actuales se muestran ahora
- recuento de especies únicas (`spp`)
- detecciones totales (`det`)
- duración transcurrida
- tamaño de grabación estimado cuando la grabación está habilitada

## Comportamiento de grabación

La grabación se controla en [Configuración](settings.md).

- **Completo** registra toda la sesión.
- **Solo detecciones** graba clips alrededor de las detecciones.
- **Apagado** desactiva la grabación.

Cuando detiene el modo en vivo, BirdNET Live guarda la sesión y abre [Revisión de sesión](session-review.md).
