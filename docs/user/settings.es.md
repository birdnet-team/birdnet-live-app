# Ajustes

BirdNET Live reutiliza una misma pantalla de Ajustes en varios flujos de trabajo. El botón :material-tune: abre las secciones relevantes para la pantalla desde la que llegas.

## Cómo funciona el alcance de los Ajustes

- Al abrir los Ajustes desde Inicio se muestra la pantalla completa.
- Al abrir los Ajustes desde Live, Survey, Point Count o Análisis de archivos, la pantalla se filtra a las secciones relevantes.

## General

### Tema

Elige **Oscuro**, **Claro** o **Sistema**.

Si **Color dinámico** está activado, BirdNET Live también intenta adaptarse a la paleta del sistema de tu dispositivo Android. Esto solo tiene efecto en dispositivos Android compatibles; en iPhone y iPad la app sigue usando el tema estándar de BirdNET Live, por lo que activar el interruptor ahí no cambia nada.

### Idioma de la aplicación

Establece el idioma de la interfaz.

### Nombres de especies

Controla el idioma usado para los nombres de las especies. **Sistema** usa el idioma preferido del teléfono cuando ese nombre está disponible, aunque la interfaz vuelva al inglés. **Seguir app** usa en cambio el idioma de la interfaz.

### Mostrar nombres científicos

Muestra los nombres científicos debajo de los nombres comunes en toda la app.

### Superposición de reproducción en revisión

Cuando está activada (que es lo predeterminado), revisar un clip de audio en un Resumen de la Session de solo clips (donde no hay grabación de audio ni espectrograma completos) abre un reproductor modal superpuesto con controles de transporte y una vista previa del espectrograma, en lugar de reproducir el clip en segundo plano. Si una Session tiene audio completo, este ajuste se omite y la superposición de reproducción nunca se muestra.

### Nombre del observador

La configuración de Survey, Point Count y ARU recuerda el último nombre de observador no vacío introducido en cualquiera de esos modos y lo rellena de antemano la próxima vez que prepares una Session de campo. Así el uso repetido es rápido en un teléfono de campo personal, sin dejar de permitirte editar o borrar el observador antes de iniciar una Session.

### ID de ARU / estación

La configuración de ARU recuerda el último ID de ARU/estación no vacío y lo rellena de antemano para el siguiente despliegue. Cuando está presente, el ID se incluye en el nombre de la ARU Session y en los nombres de archivo de exportación, de modo que los despliegues repetidos en un sitio fijo siguen siendo identificables fuera de la app.

### Visualización de marca temporal

Controla cómo aparecen los tiempos de cada detección en el Resumen de la Session.

- **Relativa** muestra el desfase desde el inicio de la grabación, p. ej. `00:12:34`. Ideal para revisar una sola Session y coincidir con el cursor del espectrograma.
- **Absoluta** muestra la hora local del reloj en que se capturó la detección, p. ej. `08:42:17`. Ideal para cruzar datos con notas de campo, registros meteorológicos o grabaciones simultáneas.

Si una detección cae en un día de calendario distinto al del inicio de la Session (p. ej. un Survey nocturno), la hora absoluta recibe el sufijo `+1d` para que al revisar no se confunda el amanecer de mañana con el de hoy.

Cuando se selecciona **Absoluta**, aparece además un interruptor **Mostrar segundos en marcas de tiempo**. Desactívalo si prefieres el formato más compacto `08:42` en lugar de `08:42:17`, útil al revisar listas largas de detecciones. Los desfases relativos siempre muestran segundos porque la alineación con el espectrograma requiere precisión inferior al minuto.

El almacenamiento y las exportaciones siempre usan instantes UTC independientemente de este ajuste, por lo que la elección nunca afecta a los datos, solo a cómo se presentan.

## Audio

Estos controles aparecen en los flujos de trabajo en vivo basados en audio.

### Ganancia

Amplificador lineal aplicado al audio entrante antes de que llegue al espectrograma y al clasificador. Déjalo en **1.0×** salvo que tu entrada sea sistemáticamente demasiado baja, por ejemplo un micrófono de solapa de alta impedancia en un teléfono o una interfaz USB con el preamplificador demasiado bajo. Subir la ganancia por encima de 1.0 no revela por arte de magia cantos que el micrófono nunca captó; solo reescala lo que el micrófono entregó, por lo que los sonidos fuertes y cercanos pueden saturar. Por debajo de 1.0 resulta útil en el caso poco frecuente en que una entrada demasiado fuerte satura el espectrograma.

### Filtro de paso alto (Hz)

Elimina el contenido de baja frecuencia antes de la inferencia mediante un filtro Butterworth de 24 dB/octava: el valor del control deslizante es el corte de −3 dB. **0 Hz lo desactiva.** Un corte de 100–200 Hz elimina viento, ruido sordo del tráfico y ruido de manipulación sin afectar a la mayoría de las especies; acercarse a 500–1000 Hz empieza a eliminar reclamos graves, búhos, urogallos y los bramidos del avetoro, así que sube tanto solo si ignoras deliberadamente esas especies a cambio de un espectrograma mucho más limpio en un entorno urbano ruidoso. El corte que elijas debería verse como una línea horizontal nítida en el espectrograma en vivo.

### Fuente de audio

Una sola hoja con dos controles independientes: **Micrófono** —qué entrada graba— y **Procesamiento** —cuánto puede alterar el móvil la señal de entrada—. Se combinan libremente, así que grabar con un micrófono USB *sin procesar* es una configuración perfectamente válida. Tu selección se recuerda entre inicios de la app, y el mismo selector aparece en las pantallas de configuración de Survey, Point Count y ARU. Los cambios surten efecto de inmediato: incluso a mitad de una grabación, la app sustituye el micrófono en la sesión en curso en vez de esperar a la siguiente.

**Micrófono** lista por su nombre todas las entradas que expone el móvil: micrófonos USB, con cable y Bluetooth, y en muchos móviles también los micrófonos integrados por separado (por ejemplo *inferior* y *trasero*). Los kits de micrófono inalámbrico como el Rode Wireless GO o el DJI Mic se conectan por un receptor USB-C, así que aquí aparecen como dispositivos de audio USB normales, con toda su calidad.

**Procesamiento** es la parte que más importa, y solo existe **en Android**. Los móviles aplican por defecto al audio del micrófono un procesado pensado para la voz —reducción de ruido, modelado espectral y ganancia automática— porque el micrófono se usa sobre todo para llamadas. Ese procesado trata el canto de las aves como ruido que hay que suprimir, y ningún ajuste normal lo desactiva. La única salida es pedirle a Android una *fuente de audio* distinta:

| Opción | Qué hace |
|---|---|
| **Predet. del móvil** | Lo que hace tu móvil habitualmente, procesamiento de voz incluido. El comportamiento original y todavía la opción por defecto, para que nada cambie a los usuarios existentes. |
| **Sin procesar** | La señal en bruto del micrófono: sin reducción de ruido ni ganancia automática. Suele ser la mejor opción para las aves. |
| **Reconocimiento de voz** | También desactiva la reducción de ruido y la ganancia automática, y funciona en casi cualquier móvil. |

**Pruébalas y compara.** Cuál gana depende realmente del modelo. *Sin procesar* es lo ideal, pero Android solo la respeta en móviles cuyo fabricante declara compatibilidad; en el resto recurre en silencio a una alternativa y suena igual que *Predeterminado del sistema*. Para eso está *Reconocimiento de voz*: las reglas de compatibilidad de Android **exigen** que la ganancia automática y la supresión de ruido estén desactivadas para esta fuente, así que entrega audio sin procesar incluso en móviles que ignoran *Sin procesar*. Si cambiar a *Sin procesar* no cambia nada, cambia a *Reconocimiento de voz*.

Espera que las opciones sin procesar suenen **más flojas**: es la ausencia de ganancia automática, no un fallo. Sube la **Ganancia** para compensar si el medidor de nivel se ve bajo.

**En iOS** el control de Procesamiento se oculta y la hoja es simplemente una lista de micrófonos. iOS ya entrega a la app audio prácticamente sin procesar, así que no hay nada equivalente que elegir.

## Inferencia

### Duración de ventana

Controla la longitud de la ventana de análisis.

### Umbral de confianza

Establece cuán exigentes deben ser las detecciones. El valor predeterminado es del **35 %**, que mantiene la lista en vivo centrada en coincidencias más fuertes sin dejar de dar margen a cantos lejanos o parcialmente enmascarados. Bájalo si estudias especies raras o silenciosas y piensas revisar más candidatos después; súbelo cuando el ruido de fondo o los falsos positivos habituales saturen la Session.

### Sensibilidad

Un desplazamiento en el eje x aplicado a las puntuaciones de probabilidad brutas del modelo antes del Score Pooling, el filtrado geográfico y el umbral de confianza. El modelo de audio de BirdNET ya incluye una activación sigmoide, así que BirdNET Live convierte primero cada probabilidad de vuelta al espacio logit, suma el sesgo de sensibilidad y luego la convierte de nuevo en probabilidad. Los valores más altos hacen el detector más permisivo: cantos más débiles o ambiguos superan el umbral, a costa de más falsos positivos. Los valores más bajos son más estrictos y solo dejan pasar detecciones seguras. El valor predeterminado de **1.0** no aplica desplazamiento y coincide con la referencia de BirdNET. Prueba **1.25** si sospechas que el modelo se pierde cantos lejanos; baja a **0.75** si te inundan detecciones de baja calidad de especies comunes. La sensibilidad se aplica en caliente: cambiarla a mitad de una Session surte efecto en la siguiente ventana de inferencia.

### Tasa de inferencia

Controla con qué frecuencia BirdNET ejecuta la inferencia.

### Score Pooling

Combina las puntuaciones de las ventanas de inferencia recientes para que una sola ventana ruidosa no domine el resultado. **Desactivado** usa la probabilidad de cada ventana: el modo más reactivo y más ruidoso. **Promedio** calcula la media aritmética de las ventanas recientes para obtener la salida más suave. **Max** conserva el pico más alto por especie, el modo de suavizado más reactivo y bueno para cantos breves y nítidos. **LME** (log-mean-exp, el predeterminado) es el máximo suave de referencia de BirdNET: se comporta como *max* cuando una ventana domina y como *promedio* cuando varias coinciden. En el modo LME, una especie nueva necesita además el respaldo repetido de varias ventanas individuales antes de aparecer por primera vez, mientras que las detecciones respaldadas conservan la mayor parte de su puntuación reciente más fuerte de una sola ventana y las especies ya visibles continúan hasta que su puntuación combinada cae por debajo del umbral de confianza. Cambiar de modo a mitad de una Session vacía el búfer móvil para que las puntuaciones antiguas no se filtren al nuevo modo.

### Número de ventanas de pooling

Controla cuántas ventanas de inferencia consecutivas participan en el Score Pooling. Un valor mayor suaviza la puntuación de cada especie en un horizonte temporal más largo, lo que suprime detecciones espurias aisladas: útil para cantos constantes y lejanos en los que prefieres esperar a unas cuantas ventanas que lo corroboren antes de elevar una detección. Un valor menor reacciona más rápido a vocalizaciones breves pero deja pasar más ruido. El valor predeterminado de **5** coincide con el valor históricamente fijado en el modelo y es un buen punto de partida para el uso en vivo.

## Espectrograma

### Tamaño FFT

Controla la resolución de frecuencia del espectrograma.

### Paleta de colores

Elige **Viridis**, **Magma** o **Escala de grises**.

### Duración (velocidad de desplazamiento)

Controla cuánto tiempo es visible en la ventana del espectrograma.

### Rango de frecuencias

Establece la frecuencia superior que se muestra.

### Amplitud logarítmica

Aplica una escala logarítmica al espectrograma para facilitar la lectura visual.

### Calidad

Controla con qué suavidad se escala la imagen del espectrograma. **Media** es el equilibrio predeterminado. Elige **Baja** en teléfonos antiguos si el desplazamiento se entrecorta o el dispositivo se calienta; elige **Alta** si prefieres una imagen más suave y tu dispositivo tiene suficiente margen de GPU. La idea: esto solo cambia el coste de renderizado, no el análisis del audio ni los resultados de detección.

## Anuncios

Esta sección controla si BirdNET Live **dice las detecciones en voz alta por los auriculares o el altavoz del teléfono** mientras una Session está grabando. Toda la función está **desactivada por defecto** porque cambia el entorno acústico alrededor del micrófono: activarla es una decisión deliberada. No hay asistente de configuración: los selectores de detalle × frecuencia de abajo *son* toda la configuración, así que puedes tocar un preajuste distinto en cualquier momento y oír la diferencia al instante. La idea: en Surveys largos no puedes estar mirando la pantalla; una voz discreta al oído te permite mantener la vista en el hábitat y aun así saber qué se acaba de oír.

### Decir detecciones en voz alta (interruptor principal)

Desactivado por defecto. Cuando está activo, la app dice cada detección aceptada usando el motor de texto a voz integrado del dispositivo. **Se recomiendan encarecidamente los auriculares**: con el altavoz del teléfono se corre el riesgo de que el micrófono capte el anuncio y lo vuelva a detectar, por eso la app silencia brevemente el grabador alrededor de cada locución para evitar ese bucle (consulta *Silenciar micro mientras habla* más abajo).

### Detalle

Cuánto dice la app sobre cada detección. **Mínimo** dice solo el nombre de la especie (ideal para Surveys muy largos en los que solo quieres el aviso). **Equilibrado** es el predeterminado: frases cortas y variadas como *"Petirrojo"*, *"Se oyó un petirrojo"*, *"Petirrojo otra vez"*. **Hablador** añade algo más de contexto y se acerca a tener a alguien narrando a tu lado. **Personalizado** aparece automáticamente si ajustas a mano los valores avanzados. La idea: los mismos ajustes de limitación pueden resultar demasiado callados o demasiado ruidosos según la redacción; el detalle te deja mantener el ritmo y solo regular la verbosidad.

### Frecuencia

Con qué frecuencia puede hablar la app. Cinco niveles, del más callado al más hablador. **Mínima** y **Escasa** esperan mucho entre anuncios y limitan el ritmo, muy adecuadas para Surveys de varias horas en los que quieres una sensación de actividad sin un comentario continuo. **Normal** es la cadencia conversacional predeterminada. **Frecuente** acorta las pausas y eleva el límite; apropiada para Live Sessions cortas o cuando quieres una respuesta más cercana al tiempo real. **Constante** elimina por completo el retardo inicial y deja hablar a la app casi en cada ciclo de detección, útil para demostraciones, accesibilidad o cuando la pausa antes del primer anuncio en *Frecuente* se hace demasiado larga. **Personalizado** aparece cuando cambias los campos de tiempo en Avanzado. La idea: este es el control que decide si la app se queda en segundo plano o se convierte en una presencia; toca un preajuste distinto y oirás la nueva cadencia en el siguiente ciclo de detección, sin botón de guardar.

### Voz (velocidad y tono)

Dos controles deslizantes que ajustan la voz TTS de la plataforma. La **Velocidad** va de 0.5× a 1.5×; el valor predeterminado 1.0× es el ritmo "normal" de la plataforma. El **Tono** va de 0.7× a 1.3×. La idea: una pequeña reducción del tono y una leve ralentización pueden hacer los anuncios mucho más fáciles de entender al aire libre con viento o agua de fondo; el botón *Probar un ejemplo* de abajo reproduce tres nombres comunes de aves con los ajustes actuales para que puedas iterar sin salir de la pantalla.

### Avanzado

Una sección desplegable que muestra unos cuantos interruptores de enrutamiento de audio más el selector de modo de activación. Por lo general no necesitas abrirla: los preajustes de detalle y frecuencia de arriba son los únicos controles que importan en el día a día. Los valores de limitación de frecuencia (margen al iniciar, intervalo mínimo, máx. por minuto, pausa de racha, reinicio de reciente) están integrados en el control de **Frecuencia**, de modo que hay un único lugar evidente para subir o bajar la cadencia.

- **Permitir altavoz del teléfono** — Cuando está desactivado, los anuncios se omiten en silencio si no hay auriculares ni altavoz externo conectados. Cuando está activo, el altavoz del teléfono se usa como respaldo. Actívalo para escuchar de forma informal en casa; déjalo desactivado en el trabajo de campo para garantizar que no haya realimentación acústica hacia el micrófono.
- **Silenciar micro mientras habla** — Sustituye el audio entrante por silencio mientras la app habla, para que el micrófono no pueda captar y volver a detectar la salida del altavoz. Muy recomendado (y predeterminado). Desactívalo solo si tu micrófono está aislado acústicamente del altavoz del teléfono, por ejemplo un micrófono de solapa con otro cable o unos auriculares Bluetooth.
- **Bajar otros sonidos** — Reduce brevemente el volumen de música o podcasts de otras apps durante el anuncio y lo restaura después. Activado por defecto. Desactivado, suena a volumen completo en paralelo.
- **Tono previo al anuncio** — Reproduce un tono breve y suave antes de cada locución para que tu oído tenga un momento de pasar de la escucha pasiva a atender a la voz. Activado por defecto. Especialmente útil cuando los anuncios son poco frecuentes o cuando tienes música de fondo.
- **Qué anunciar** — Elige qué detecciones pueden generar un anuncio. *Cada detección* (predeterminado) deja que decida la limitación. *Primera vez por Session* anuncia una especie solo la primera vez que aparece en la Session actual. *Solo lista de seguimiento* limita los anuncios a las especies de tu lista de seguimiento (útil para Surveys dirigidos en los que quieres oír solo tus taxones prioritarios y nada más).

## Grabación

### Modo

- **Completo** — guarda toda la grabación
- **Solo detecciones** — guarda clips alrededor de las detecciones
- **Desactivado** — sin grabación de audio

### Contexto del clip

Cuando **Solo detecciones** está activo, la app muestra un único control deslizante **Contexto del clip** (0–5 s) que establece cuánto audio se conserva a **ambos lados** de cada detección. Cada clip dura `ventana de análisis + 2 × contexto del clip`, así que con una ventana de análisis de 3 s y el contexto predeterminado de 1 s el clip guardado es de 5 s. Fijar el contexto en 2 s produce un clip de 7 s (2 s antes + 3 s de audio analizado + 2 s después). Los valores más altos te dan más margen para la inspección visual o para herramientas de revisión externas a costa de espacio en disco; 0 guarda solo la ventana analizada.

### Formato

Elige **WAV** o **FLAC**. WAV es más grande pero ampliamente compatible y rápido de inspeccionar. FLAC mantiene la misma calidad de audio sin pérdidas usando menos almacenamiento, lo que suele ser mejor para Sessions largas.

Este ajuste se aplica al audio grabado por BirdNET Live. El **Análisis de archivos** conserva una copia gestionada por la app del archivo importado en su formato original, de modo que los archivos MP3, AAC, WAV y FLAC siguen siendo revisables sin un paso de conversión adicional.

### Iniciar grabación automáticamente (solo Modo Live)

Cuando está activado, el Modo Live empieza a grabar en cuanto se abre la pantalla y el modelo termina de cargarse, sin necesidad de tocar el botón del micrófono. Útil para instalaciones tipo quiosco, uso con manos libres (p. ej. montando el dispositivo en el campo) o cualquier flujo en el que ya sepas que abrir Live significa siempre "empezar ahora". Desactivado por defecto para que un toque accidental en la tarjeta de Live desde la pantalla de inicio no inicie una Session en silencio. El inicio automático se dispara una sola vez por visita a la pantalla, así que detener una Session y tocar de nuevo el micrófono sigue funcionando como reinicio manual.

Este ajuste se aplica al abrir el Modo Live desde dentro de la app. El [widget «Escucha rápida»](live-mode.md) empieza a escuchar al tocarlo, sea cual sea el valor de este ajuste, y no lo modifica. Si ya se está ejecutando o iniciando una Session de Point Count, Survey, File Analysis o Modo ARU, conserva esa Session y te pide que la detengas primero.

## Ubicación

### Usar GPS

Usa el GPS del dispositivo en lugar de coordenadas manuales.

### Latitud / Longitud

Coordenadas manuales usadas cuando el GPS está desactivado.

### Actualizar GPS ahora

Fuerza una nueva fijación de ubicación en lugar de reutilizar el último valor que la app guardó en caché. La idea: las consultas de GPS se almacenan en caché por pantalla para que una pantalla de configuración no se bloquee esperando una fijación de satélite cada vez que se abre, pero esa caché puede quedar a kilómetros de distancia si te has desplazado a un sitio nuevo desde la última Session. Tócalo cuando te hayas movido y quieras que el filtro geográfico use *aquí*, no donde empezaste la mañana. Las coordenadas en caché actuales se muestran en el subtítulo para que verifiques qué cree la app que es tu ubicación. Si el GPS no consigue una fijación en unos 10 segundos, la app recurre a la última ubicación conocida del sistema operativo y te avisa con un SnackBar para que sepas que el valor está desactualizado.

### Descargar mapas sin conexión

La descarga de mapas sin conexión está oculta de momento mientras BirdNET Live usa el servicio público de mosaicos de OpenStreetMap. OpenStreetMap admite la navegación interactiva normal del mapa con atribución, un agente de usuario claro y almacenamiento en caché local, pero no permite la precarga masiva ni funciones de descarga de mapas sin conexión desde `tile.openstreetmap.org`. La implementación del descargador se conserva para una futura fuente de mosaicos que permita explícitamente los paquetes sin conexión.

### Filtro de especies

- **Desactivado** — sin filtrado geográfico
- **Filtro geográfico** — excluye las especies que quedan por debajo del umbral geográfico
- **Ponderación geográfica** — usa el geomodelo como señal de ponderación adicional

### Umbral del filtro geográfico

Aparece cuando hay activo un modo de filtro basado en la ubicación.

## Exportación y sincronización

### Formatos

Marca cualquier combinación de formatos de exportación: cada acción de guardar / compartir agrupa todos los formatos seleccionados en un único ZIP. Si eliges un solo formato sin clips de audio y sin informe HTML, obtendrás un archivo en bruto (p. ej. `session.csv`) en lugar de un ZIP, por compatibilidad:

- Raven Selection Table — para usar en Cornell Raven Pro.
- CSV — se abre en cualquier hoja de cálculo.
- JSON — lo más sencillo para el procesamiento programático; lleva los metadatos completos de la Session.
- GPX — recorrido y waypoints para usar en herramientas de mapas (solo tiene sentido cuando el GPS estaba activado).

La idea: muchos flujos de trabajo necesitan más de un formato a la vez: un CSV para la hoja de cálculo, una tabla Raven para el revisor de escritorio y un JSON para el script de análisis. Antes había que exportar la misma Session tres veces; ahora marcas los tres una vez y viajan juntos en el ZIP.

### Incluir archivos de audio

Incluye el audio guardado junto con las tablas o los metadatos exportados cuando el flujo de exportación lo admita.

### Incluir informe HTML

Cuando está activado, cada ZIP de exportación contiene también un archivo `report.html` junto a la tabla, los clips de audio y el GPX. Ábrelo en cualquier navegador y obtendrás un resumen listo para imprimir de la Session: tarjeta de encabezado con fecha, ubicación, observador y totales; un mapa interactivo del recorrido GPS y los marcadores de detección; una tarjeta por detección con la miniatura de la taxonomía de Cornell, los nombres, la insignia de puntuación, tu confirmación, cualquier nota que hayas escrito y el clip de audio original integrado como reproductor; y los ajustes de análisis utilizados. La idea: un CSV es estupendo para los pipelines de análisis, pero inútil para compartir con un colaborador no técnico o imprimir un resumen rápido de campo; el informe HTML cubre ese hueco con un solo toque. Las miniaturas de especies y los mosaicos del mapa necesitan conexión la primera vez que se abre el archivo (se obtienen en directo de la API de taxonomía de BirdNET y de OpenStreetMap), pero todo lo demás —texto, diseño, reproducción de audio, enlaces— funciona totalmente sin conexión. Desactívalo si solo necesitas los datos en bruto y quieres mantener el ZIP unos KB más pequeño.

## Privacidad

Esta sección controla **qué servicios de terceros puede contactar BirdNET Live en tu nombre**. La inferencia en sí se ejecuta íntegramente en tu dispositivo: estos interruptores solo gobiernan funciones de red opcionales que enriquecen la experiencia. Los tres interruptores están **desactivados por defecto** en una instalación nueva; nada sale de tu dispositivo hasta que lo permitas. La idea: cada interruptor se limita a un servicio concreto y a un beneficio concreto, para que actives exactamente lo que es útil para tu flujo de trabajo y nada más.

### Permitir mosaicos del mapa

Necesario para cualquier mapa interactivo de la app (el selector de ubicación, el mapa en vivo del Survey y el mapa de la Session). Cuando está activado, los widgets de mapa solicitan mosaicos ráster a los servidores públicos de **OpenStreetMap**; las solicitudes de coordenadas de mosaico revelan qué zona del mundo estás viendo. Los mosaicos se almacenan en caché localmente hasta seis meses, con un límite de 6000 mosaicos para que las vistas repetidas del mapa sean eficientes sin crecer de forma indefinida. Activar esto también habilita **Permitir búsqueda de nombre del lugar**, porque la mayoría de quienes cargan mapas esperan que las Sessions muestren también nombres de lugar legibles. Puedes volver a desactivar la búsqueda de nombre del lugar por separado. Cuando los mosaicos del mapa están desactivados, todas las pantallas de mapa recurren a una tarjeta de marcador de posición para que el resto de la app siga funcionando sin fugas de red.

### Permitir búsqueda de nombre del lugar

Cuando está activado, la app envía tus coordenadas grabadas al servicio **Nominatim** de OpenStreetMap para resolver un nombre de lugar breve (p. ej. *"Madrid, España"*) que se muestra junto a la Session en la Biblioteca de sesiones y en el Resumen de la Session. La idea: las coordenadas numéricas son precisas pero difíciles de leer al recorrer una lista larga de Sessions; un nombre de lugar convierte la lista en algo que se lee de un vistazo. Cuando está desactivado, las Sessions muestran solo la lat/lon en bruto y nunca se contacta a Nominatim.

### Permitir consulta del clima

Cuando está activado, cada Session guardada captura una instantánea única de las condiciones locales (temperatura, precipitación, viento, nubosidad) en las coordenadas y la hora de finalización de la grabación a través de **Open-Meteo**. La instantánea aparece en el Resumen de la Session bajo la fila de ubicación y se refleja en la exportación JSON, en el bloque de metadatos por Session y en el informe HTML. La idea: el clima es uno de los predictores más fuertes de la actividad de las aves, y capturarlo automáticamente —sin que tengas que acordarte de consultar otra app— convierte cada Session en un registro más completo. Open-Meteo es un servicio gratuito que no requiere cuenta ni clave de API. Cuando está desactivado, no se obtienen ni almacenan datos del clima. La configuración de Point Count y Survey también muestra una tarjeta de clima compacta junto a sus controles de ubicación: pide este consentimiento solo cuando es necesario, muestra el resultado como icono + temperatura + viento una vez activada y reutiliza la misma instantánea en caché al guardar la Session.

## Acerca de

La fila **Acerca de** abre la pantalla Acerca de dentro de la app.

## Zona de peligro

### Restablecer introducción

Vuelve a mostrar la secuencia de introducción la próxima vez que se inicie la app.

### Restablecer todos los ajustes

Restaura cada preferencia de esta pantalla a su valor predeterminado. Las Sessions, las grabaciones, las notas de voz, las exportaciones y los mosaicos de mapa en caché quedan intactos: solo se borran las preferencias guardadas (controles deslizantes, interruptores, opciones de los selectores). La app se cierra tras la confirmación para que los nuevos valores predeterminados se apliquen en el próximo inicio.

Útil cuando no estás seguro de qué control moviste que estropeó algo, o cuando entregas el dispositivo a otra persona y quieres una configuración limpia sin perder los datos que recopilaste.

### Eliminar todos los datos

Elimina de forma permanente las Sessions, las detecciones, las grabaciones, las notas de voz, las listas de especies personalizadas, las preferencias guardadas y los datos en caché de mapas, nombres de lugar, clima, reproducción, revisión y uso compartido. El cuadro de confirmación exige escribir `DELETE` y luego cierra la app para que el próximo inicio parta de un estado local limpio.

Úsalo antes de entregar un dispositivo a otra persona observadora, retirar un teléfono de campo o eliminar de la app el historial vinculado a ubicaciones. Exporta primero todo lo que necesites; esta acción no se puede deshacer.

## Parámetros específicos del flujo de trabajo fuera de los Ajustes

Algunos parámetros se configuran dentro de sus propias pantallas de configuración en lugar de en la pantalla de Ajustes compartida.

- [Modo Point Count](point-count-mode.md) tiene su propia configuración de duración y ubicación.
- [Modo Survey](survey-mode.md) tiene su propia pantalla de parámetros de Survey.
- [Análisis de archivos](file-analysis.md) tiene su propio paso de parámetros de análisis.
