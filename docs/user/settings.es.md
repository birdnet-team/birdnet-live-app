# Ajustes

BirdNET Live reutiliza una misma pantalla de Ajustes en varios flujos de trabajo. El botón :material-tune: abre las secciones relevantes para la pantalla desde la que llegas.

## Cómo funciona el alcance de los ajustes

- Abrir Ajustes desde Inicio muestra la pantalla completa.
- Abrir Ajustes desde Live, Survey, Point Count o Análisis de archivos filtra la pantalla a las secciones relevantes.

## General

### Tema

Elige **Oscuro**, **Claro** o **Sistema**.

Si **Color dinámico** está activado, BirdNET Live también intenta adoptar la paleta del sistema de tu dispositivo Android. Esto solo tiene efecto en dispositivos Android compatibles; en iPhone y iPad la aplicación sigue usando el tema estándar de BirdNET Live, así que activar el interruptor allí no cambia nada.

Activa **Tema de alto contraste** para usar una paleta de interfaz en blanco y negro, clara u oscura, con texto más grueso y superficies con borde en lugar de tarjetas tintadas. Sigue la elección **Oscuro**, **Claro** o **Sistema**, tiene prioridad sobre el color dinámico mientras está activo y conserva los colores de peligro, advertencia, validación, modo, puntuación y espectrograma.

### Idioma de la aplicación

Establece el idioma de la interfaz.

### Nombres de especies

Controla el idioma usado para los nombres de especies. **Sistema** usa el idioma preferido del teléfono cuando ese nombre está disponible, incluso si la interfaz recurre al inglés. **Seguir la aplicación** usa en su lugar el idioma de la interfaz.

### Mostrar nombres científicos

Muestra los nombres científicos bajo los nombres comunes en toda la aplicación.

### Mostrar todas las especies detectadas

Solo en modo Live y Point Count. Desactivado de forma predeterminada, por lo que estas pantallas siguen mostrando únicamente las especies detectadas en el último ciclo de inferencia: en la práctica, las que están vocalizando ahora mismo. Actívalo para que cada especie detectada durante la sesión en curso permanezca visible en la lista, incluso después de dejar de vocalizar o de caer por debajo del umbral de confianza.

Cuando está activado, aparece **Orden de la lista de especies**. **Más recientes primero** muestra arriba las especies que están vocalizando, ordenadas por su confianza actual, y después las especies retenidas por su detección más reciente. **Confianza** ordena por la confianza más alta alcanzada por cada especie durante la sesión, **Alfabéticamente** por el nombre común localizado y **Apariciones** por el número de detecciones. En cualquier modo de orden, el porcentaje y la barra de confianza solo aparecen mientras esa especie está vocalizando (las filas retenidas de especies que han callado se atenúan), y las detecciones repetidas muestran un contador al final de la fila del nombre común.

### Nombre del observador

La configuración de Survey, Point Count y ARU recuerda el último nombre de observador no vacío introducido en cualquiera de esos modos y lo rellena la próxima vez que prepares una sesión de campo. Así el uso repetido en un teléfono de campo personal sigue siendo rápido, y aun así puedes editar o borrar el observador antes de iniciar una sesión.

### ID de ARU/estación

La configuración de ARU recuerda el último ID de ARU/estación no vacío y lo rellena para el siguiente despliegue. Cuando está presente, el ID se incluye en el nombre de la sesión ARU y en los nombres de archivo de exportación, de modo que los despliegues repetidos en puntos fijos siguen siendo identificables fuera de la aplicación.

### Visualización de marcas de tiempo

Controla cómo aparecen los tiempos de cada detección en la revisión de la sesión.

- **Relativo** muestra el desplazamiento desde el inicio de la grabación, por ejemplo `00:12:34`. Ideal para revisar una sola sesión y cuadrar con el cursor de reproducción del espectrograma.
- **Absoluto** muestra la hora local en que se capturó la detección, por ejemplo `08:42:17`. Ideal para cotejar con notas de campo, registros meteorológicos o grabaciones simultáneas.

Si una detección cae en un día natural distinto al del inicio de la sesión (por ejemplo, en un muestreo nocturno), la hora absoluta recibe el sufijo `+1d`, para que nadie confunda el coro del amanecer de mañana con el de hoy.

Cuando se selecciona **Absoluto**, aparece un interruptor adicional: **Mostrar segundos en las marcas de tiempo**. Desactívalo si prefieres el más compacto `08:42` frente a `08:42:17`; resulta útil al recorrer listas largas de detecciones. Los desplazamientos relativos siempre muestran segundos, porque al revisar hace falta precisión inferior al minuto para alinearse con el cursor del espectrograma.

El almacenamiento y las exportaciones usan siempre instantes en UTC, independientemente de este ajuste, así que la elección nunca afecta a los datos, solo a cómo se muestran.

## Audio

Estos controles aparecen en los flujos de trabajo en directo basados en audio.

### Fuente de audio

Un panel con dos controles independientes: **Micrófono** —desde qué entrada grabar— y **Procesamiento** —cuánto puede alterar el teléfono la señal de entrada—. Se combinan libremente, así que un micrófono USB grabado *sin procesar* es una configuración perfectamente válida. Tu selección se mantiene entre reinicios de la aplicación, y el mismo selector aparece en las pantallas de configuración de Survey, Point Count y ARU. Los cambios surten efecto de inmediato: incluso a mitad de grabación, la aplicación cambia el micrófono bajo la sesión en curso en lugar de esperar a la siguiente.

**Micrófono** enumera por nombre cada entrada que expone el teléfono: micrófonos USB, con cable y Bluetooth y, en muchos teléfonos, también los micrófonos integrados por separado (por ejemplo, *inferior* y *trasero*). Los kits de micrófono inalámbrico como el Rode Wireless GO o el DJI Mic se conectan mediante un receptor USB-C, así que aparecen aquí como dispositivos de audio USB normales y con calidad completa.

**Procesamiento** es la parte que más importa, y es **solo para Android**. Los teléfonos aplican por defecto al audio del micrófono un DSP ajustado a la voz —reducción de ruido, modelado espectral y ganancia automática— porque el micrófono se usa sobre todo para llamadas. Ese procesamiento trata el canto de las aves como ruido que hay que suprimir, y ningún ajuste corriente lo desactiva. La única salida es pedirle a Android una *fuente de audio* distinta:

| Opción | Qué hace |
|---|---|
| **Predeterminado del teléfono** | Lo que tu teléfono hace normalmente, procesamiento de voz incluido. El comportamiento original y todavía el predeterminado, para que nada cambie para los usuarios existentes. |
| **Sin procesar** | La señal cruda del micrófono: sin reducción de ruido ni ganancia automática. Suele ser la mejor opción para aves. |
| **Reconocimiento de voz** | También desactiva la reducción de ruido y la ganancia automática, y funciona en casi cualquier teléfono. |

**Pruébalas y compara.** Cuál gana depende realmente del terminal. *Sin procesar* es lo ideal, pero Android solo lo respeta en teléfonos cuyo fabricante declara compatibilidad; en el resto recurre silenciosamente al comportamiento por defecto y suena igual que *Predeterminado del sistema*. Para eso está *Reconocimiento de voz*: las reglas de compatibilidad de Android **exigen** que con él la ganancia automática y la supresión de ruido estén desactivadas, así que entrega audio sin procesar de forma fiable incluso en teléfonos que ignoran *Sin procesar*. Si cambiar a *Sin procesar* no cambia nada, cambia a *Reconocimiento de voz*.

Espera que las opciones sin procesar suenen **más bajas**: es la ausencia de ganancia automática, no un fallo. Sube la **Ganancia** para compensarlo si el medidor de nivel se ve bajo.

**En iOS** el control de Procesamiento está oculto y el panel es simplemente una lista de micrófonos. iOS ya entrega a la aplicación audio esencialmente sin procesar, así que no hay nada equivalente que elegir.

### Ganancia

Amplificador lineal aplicado al audio entrante antes de que llegue al espectrograma y al clasificador. Déjalo en **1,0×** salvo que tu entrada sea sistemáticamente demasiado baja: por ejemplo, un micrófono de solapa de alta impedancia conectado a un teléfono, o una interfaz USB con el preamplificador demasiado bajo. Subir la ganancia por encima de 1,0 no hará aparecer por arte de magia cantos que el micrófono nunca captó; solo reescala lo que el micrófono entregó, así que los sonidos fuertes cercanos pueden saturar. Por debajo de 1,0 resulta útil en el caso poco frecuente de que una entrada demasiado fuerte sature el espectrograma.

### Filtro paso alto (Hz)

Recorta el contenido de baja frecuencia antes de la inferencia mediante un filtro Butterworth de 24 dB/octava; el valor del control deslizante es la frecuencia de corte de −3 dB. **0 Hz lo desactiva.** Un corte de 100–200 Hz elimina viento, retumbe del tráfico y ruido de manipulación sin afectar a la mayoría de las especies; al acercarse a 500–1000 Hz empiezan a desaparecer los reclamos graves, los búhos, las aves galliformes y el bramido del avetoro, así que sube tanto solo si estás ignorando deliberadamente esas especies a cambio de un espectrograma mucho más limpio en un entorno urbano ruidoso. El corte que elijas debería verse como una línea horizontal nítida en el espectrograma en directo.

## Inferencia

### Duración de la ventana

Controla la longitud de la ventana de análisis. Los valores disponibles son **1**, **3**, **5**, **7**, **10** y **15** segundos.

### Umbral de confianza

Determina cómo de conservadoras deben ser las detecciones. El valor predeterminado es **35 %**, que mantiene la lista en directo centrada en coincidencias más sólidas y deja margen para reclamos lejanos o parcialmente enmascarados. Bájalo si estás muestreando especies raras o discretas y piensas revisar más candidatos después; súbelo cuando el ruido de fondo o los falsos positivos frecuentes saturen la sesión.

### Sensibilidad

Un desplazamiento en el eje x aplicado a las puntuaciones de probabilidad brutas del modelo antes de la agrupación de puntuaciones, el filtrado geográfico y el umbral de confianza. El modelo de audio de BirdNET ya incluye una activación sigmoide, así que BirdNET Live primero convierte cada probabilidad de vuelta al espacio de logits, suma el sesgo de sensibilidad y luego la convierte de nuevo en probabilidad. Los valores más altos hacen el detector más permisivo: reclamos más débiles o ambiguos superan el umbral, a costa de más falsos positivos. Los valores más bajos son más estrictos y solo dejan pasar detecciones seguras. El valor predeterminado de **1,0** no aplica desplazamiento y coincide con la referencia de BirdNET. Prueba **1,25** si sospechas que el modelo se pierde reclamos lejanos; baja a **0,75** si te inundan detecciones de baja calidad de especies comunes. La sensibilidad se aplica en caliente: cambiarla a mitad de sesión surte efecto en la siguiente ventana de inferencia.

### Frecuencia de inferencia

Controla con qué frecuencia BirdNET ejecuta la inferencia. El control
deslizante usa los mismos pasos de **0,10–1,00 Hz** que la configuración de
Survey y ARU. Las ventanas se anclan a las muestras de audio capturadas y no
a la finalización de un temporizador, de modo que guardar un fragmento o una
llamada al modelo temporalmente lenta no desplaza las ventanas posteriores.
Con los mismos ajustes de inferencia, el modo Live, Point Count y Survey
analizan las mismas ventanas y notifican las mismas detecciones. Las
frecuencias más bajas reducen el trabajo del modelo y el consumo de batería,
pero dejan huecos más amplios entre ventanas, por lo que es más fácil perder
vocalizaciones muy breves. Los nuevos ajustes de Survey usan **0,70 Hz** de
forma predeterminada como término medio; **0,30 Hz** sigue siendo la opción
explícita de máxima autonomía. El análisis de archivos no tiene frecuencia de
inferencia: usa un ajuste de [solapamiento](file-analysis.md) en su lugar.

BirdNET Live suaviza internamente las puntuaciones a lo largo de las ventanas
de inferencia recientes para reducir falsos positivos puntuales. Esta
agrupación no se expone como ajuste de usuario; de forma predeterminada usa
agrupación adaptativa Log-Mean-Exp con cinco ventanas recientes y un límite de
antigüedad de 10 segundos en tiempo real. Las detecciones aceptadas muestran la
mayor confianza reciente respaldada por el modelo, de modo que las
vocalizaciones evidentes pueden seguir mostrando confianza alta en lugar de
quedar aplanadas por el suavizado. Todos los modos convierten ahora ese
resultado de agrupación en detecciones de la misma manera: una detección
comienza en su ventana de apoyo más temprana, lleva la puntuación respaldada
más alta y termina al final de la última ventana de apoyo.

## Espectrograma

### Tamaño de FFT

Controla la resolución en frecuencia del espectrograma.

### Mapa de color

Elige **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Escala de grises** o **BirdNET**. **Turbo** es la opción arcoíris moderna, similar a Jet.

### Duración (velocidad de desplazamiento)

Controla cuánto tiempo se ve en la ventana del espectrograma.

### Rango de frecuencias

Establece la frecuencia superior mostrada.

### Amplitud logarítmica

Aplica escalado logarítmico al espectrograma para leerlo con más facilidad.

### Calidad

Controla con qué suavidad se escala la imagen del espectrograma. **Media** es el equilibrio predeterminado. Elige **Baja** en teléfonos antiguos cuando el desplazamiento se entrecorta o el dispositivo se calienta; elige **Alta** cuando prefieras una imagen más suave y tu dispositivo tenga margen de GPU. La intuición: esto solo cambia el coste de renderizado, no el análisis de audio ni los resultados de detección.

## Anuncios

Esta sección controla si BirdNET Live **lee las detecciones en voz alta por los auriculares o el altavoz del teléfono** mientras una sesión está grabando. Toda la función está **desactivada de forma predeterminada** porque cambia el entorno acústico alrededor del micrófono: activarla es una decisión consciente. No hay asistente de configuración: los selectores de nivel de detalle × frecuencia que aparecen abajo *son* toda la configuración, así que puedes tocar otro preajuste en cualquier momento y oír la diferencia al instante. La intuición: en muestreos largos no puedes estar mirando la pantalla; una voz discreta al oído te permite mantener la vista en el hábitat y aun así saber qué se acaba de oír.

### Leer detecciones en voz alta (interruptor principal)

Desactivado de forma predeterminada. Al activarlo, la aplicación pronuncia cada detección aceptada mediante la síntesis de voz integrada de tu dispositivo. **Se recomiendan encarecidamente los auriculares**: usar el altavoz del teléfono arriesga a que el anuncio sea captado por el micrófono y detectado de nuevo, por lo que la aplicación silencia brevemente la grabación alrededor de cada locución para evitar ese bucle (consulta *Silenciar el micrófono al hablar* más abajo).

### Preajuste de nivel de detalle

Cuánto dice la aplicación sobre cada detección. **Mínimo** pronuncia solo el nombre de la especie (lo mejor para muestreos muy largos en los que solo quieres la señal). **Equilibrado** es el valor predeterminado: frases breves y variadas como *«Petirrojo»*, *«Se oye un petirrojo»*, *«Otra vez petirrojo»*. **Conversador** añade algo más de contexto y se acerca a tener a alguien comentando a tu lado. **Personalizado** aparece automáticamente si ajustas a mano los valores numéricos de Avanzado. La intuición: los mismos ajustes de limitación pueden resultar demasiado silenciosos o demasiado parlanchines según cómo estén redactados; el nivel de detalle te permite mantener el ritmo y regular solo la cantidad de palabras.

### Preajuste de frecuencia

Con qué frecuencia se permite que la aplicación hable. Cinco pasos, del más silencioso al más hablador. **Raro** y **Escaso** esperan mucho entre anuncios y limitan el ritmo: van bien para muestreos de varias horas en los que quieres percibir la actividad sin un comentario continuo. **Normal** es la cadencia conversacional predeterminada. **Frecuente** acorta los intervalos y sube el tope; adecuado para sesiones cortas de Live o cuando quieres una respuesta más cercana al tiempo real. **Constante** elimina por completo el retraso inicial y deja que la aplicación hable en casi cada ciclo de detección: útil para demostraciones, accesibilidad, o cuando el hueco antes del primer anuncio con *Frecuente* se te hace largo. **Personalizado** aparece cuando cambias los campos de temporización en Avanzado. La intuición: este es el único mando que decide si la aplicación se queda en segundo plano o pasa a ser una presencia; toca otro preajuste y oirás la nueva cadencia en el siguiente ciclo de detección, sin botón de guardar.

### Voz

Toca la fila de voz para elegir entre las voces de síntesis instaladas para el idioma de los anuncios, o deja seleccionada **Voz predeterminada** para que decida el dispositivo. La disponibilidad y la calidad de las voces dependen del sistema operativo y de los paquetes de voz instalados; puedes instalar voces adicionales desde los ajustes de síntesis de voz del dispositivo.

**Velocidad** abarca de 0,5× a 1,5×; el valor predeterminado 1,0× es el ritmo «normal» de la plataforma. **Tono** abarca de 0,7× a 1,3×. Bajar un poco el tono y ralentizar ligeramente puede facilitar entender los anuncios al aire libre con viento o agua corriendo de fondo. *Reproducir una muestra* permite escuchar la voz seleccionada, el estilo actual de redacción, la velocidad y el tono sin salir de Ajustes. Los cambios se aplican al siguiente anuncio.

### Avanzado

Una sección desplegable que expone unos cuantos interruptores de enrutado de audio más el selector de modo de activación. Por lo general no necesitas abrirla: los preajustes de nivel de detalle y frecuencia de arriba son los únicos mandos que importan en el día a día. Los valores numéricos de limitación (margen inicial, intervalo mínimo, máximo por minuto, silencio en rachas, restablecimiento de recencia) están agrupados en el control **Frecuencia**, de modo que hay un único lugar evidente para subir o bajar la cadencia.

- **Permitir el altavoz del teléfono** — Cuando está desactivado, los anuncios se omiten en silencio si no hay auriculares ni altavoz externo conectados. Cuando está activado, se usa el altavoz del teléfono como alternativa. Actívalo para escuchar de forma informal en casa; déjalo desactivado en el trabajo de campo para garantizar que no haya realimentación acústica hacia el micrófono.
- **Silenciar el micrófono al hablar** — Sustituye el audio entrante por silencio mientras la aplicación habla, de modo que la salida del altavoz no pueda ser captada por el micrófono y detectada de nuevo. Muy recomendable (y el valor predeterminado). Desactívalo solo si tu micrófono está aislado acústicamente del altavoz del teléfono, por ejemplo un micrófono de solapa en otro cable o unos auriculares Bluetooth.
- **Bajar otro audio** — Reduce brevemente el volumen de la música o los pódcast de otras aplicaciones durante el anuncio y lo restaura después. Activado de forma predeterminada. Desactivado, se reproduce a volumen completo.
- **Tono de aviso antes de hablar** — Reproduce un tono breve y suave antes de cada locución para que tu oído tenga un momento para pasar de la escucha pasiva a atender a la voz. Activado de forma predeterminada. Especialmente útil cuando los anuncios son poco frecuentes o cuando tienes música de fondo.
- **Qué anunciar** — Elige qué detecciones son siquiera candidatas a un anuncio. *Cada detección* (predeterminado) deja que decida la limitación. *Primera vez por sesión* anuncia una especie solo la primera vez que aparece en la sesión actual. *Solo lista de seguimiento* limita los anuncios a las especies de tu lista de seguimiento (útil en trabajos de muestreo dirigidos, en los que quieres oír solo tus taxones prioritarios y nada más).

## Grabación

### Modo

- **Completa** — guardar toda la grabación
- **Solo detecciones** — guardar fragmentos alrededor de las detecciones
- **Desactivado** — sin grabación de audio

### Contexto del fragmento

Cuando **Solo detecciones** está activo, la aplicación muestra un único control **Contexto del fragmento** (0–5 s) que fija cuánto audio se conserva a **ambos lados** de cada detección. Cada fragmento dura `ventana de análisis + 2 × contexto del fragmento`, así que con una ventana de análisis de 3 s y el contexto predeterminado de 1 s el fragmento guardado es de 5 s. Con un contexto de 2 s se obtiene un fragmento de 7 s (2 s previos + 3 s de audio analizado + 2 s posteriores). Los valores mayores te dan más margen para la inspección visual o para herramientas de revisión externas a costa de espacio en disco; 0 guarda solo la ventana analizada.

### Formato

Elige **WAV** o **FLAC**. WAV ocupa más, pero es ampliamente compatible y rápido de inspeccionar. FLAC mantiene la misma calidad de audio sin pérdidas usando menos almacenamiento, lo que suele ser mejor para sesiones largas.

Este ajuste se aplica al audio grabado por BirdNET Live. **Análisis de archivos** conserva una copia gestionada por la aplicación del archivo importado en su formato original, de modo que los archivos MP3, AAC, WAV y FLAC siguen siendo revisables sin un paso de conversión adicional.

### Iniciar la grabación automáticamente (solo modo Live)

Al activarlo, el modo Live empieza a grabar en cuanto se abre la pantalla y el modelo termina de cargarse, sin tener que tocar el botón del micrófono. Útil para instalaciones tipo quiosco, uso con las manos libres (por ejemplo, el dispositivo montado en el campo) o cualquier flujo en el que abrir Live ya signifique «empezar ahora». Desactivado de forma predeterminada para que un toque accidental en el mosaico de Live desde la pantalla de inicio no comience una sesión en silencio. El inicio automático se produce solo una vez por visita a la pantalla, así que detener una sesión y volver a tocar el micrófono sigue funcionando como reinicio manual.

Este ajuste rige la apertura del modo Live desde dentro de la aplicación. El [widget Quick Listen](live-mode.md) empieza a escuchar al tocarlo, sea cual sea este ajuste, y no lo modifica. Si ya hay una sesión de Point Count, Survey, Análisis de archivos o modo ARU en marcha o iniciándose, se conserva esa sesión y se te pide que la detengas primero.

### Guardar sesiones automáticamente (Live y Point Count)

Al activarlo (el valor predeterminado), una sesión de Live o Point Count completada se añade a tu biblioteca automáticamente en el momento en que termina. Al desactivarlo, una sesión finalizada se abre en la revisión marcada como **sin guardar**: el icono de guardar aparece resaltado y debes tocarlo para conservar la sesión. Salir de la revisión sin guardar descarta la sesión y sus grabaciones. Esto encaja con escuchas rápidas en las que solo quieres conservar algún resultado destacable en lugar de acumular cada grabación corta. Los despliegues de Survey y ARU siempre se guardan automáticamente —una ejecución larga sin supervisión es demasiado valiosa como para perderla por olvidar tocar Guardar—, así que este interruptor no se aplica allí.

## Reproducción

### Superposición de reproducción en la revisión

Al activarlo (el valor predeterminado), escuchar un fragmento de audio en una revisión de sesión compuesta solo por fragmentos (donde no hay grabación completa ni espectrograma disponibles) abre una superposición modal de reproducción propia, con controles de transporte y vista previa del espectrograma, en lugar de reproducir el fragmento en segundo plano. Si una sesión tiene audio completo, este ajuste se omite y la superposición de reproducción nunca se muestra.

### Reproducir automáticamente las notas de voz

Desactivado de forma predeterminada. Al activarlo, una nota de voz adjunta a una anotación con marca de tiempo se reproduce automáticamente durante la Revisión de la sesión en el momento en que el cursor de reproducción cruza su posición registrada. La nota se mezcla sobre la grabación en lugar de pausarla, así que oyes tu comentario en contexto junto al audio original. Déjalo desactivado si prefieres lanzar las notas manualmente tocando su etiqueta de anotación.

### Atenuación con notas de voz

Solo se muestra cuando **Reproducir automáticamente las notas de voz** está activado. Controla cuánto se baja la grabación principal mientras suena una nota de voz automática. Los valores más altos hacen las notas habladas más fáciles de oír; los más bajos dejan oír más de la grabación original por debajo de la nota.

## Ubicación

### Usar GPS

Usar el GPS del dispositivo en lugar de coordenadas manuales. En Android, las
posiciones proceden del proveedor de ubicación de la plataforma y no de los
servicios de Google Play, así que la aplicación no dispara el diálogo de
precisión de ubicación de Google. Con esto desactivado, la aplicación nunca lee
el GPS ni pide permiso de ubicación por su cuenta: los asistentes de
configuración de Survey, Point Count y ARU se abren en entrada manual con tus
coordenadas guardadas, el seguimiento GPS del muestreo no se ejecuta y la
preparación de mapas sin conexión también se centra en esas coordenadas.

### Coordenadas manuales

Las coordenadas usadas cuando **Usar GPS** está desactivado. Tanto la latitud como la longitud son campos de texto editables, así que puedes **escribir** un valor exacto o **pegar** uno copiado de otra aplicación: mucho más preciso que arrastrar un control deslizante en una pantalla táctil. Introduce grados decimales (por ejemplo, `52.5200` y `13.4050`). También puedes pegar una cadena combinada `latitud, longitud` (separada por coma, punto y coma o espacio) en *cualquiera* de los campos y ambos se rellenan a la vez, que es lo que la mayoría de mapas y sitios web colocan en el portapapeles. Los valores fuera de rango o no numéricos se señalan al momento y no se guardan; los valores válidos se conservan mientras escribes. La intuición: el motivo más habitual para fijar una ubicación manual es identificar un sonido grabado en un sitio distinto de donde estás ahora, y esa ubicación suele llegar como texto desde otro lugar; escribir y pegar lo convierten en un único paso preciso. Si prefieres señalar un punto a escribir números, **Elegir en el mapa** abre el mismo selector de mapa a pantalla completa que usan las pantallas de configuración, partiendo de las coordenadas actuales, y rellena ambos campos con la ubicación que toques.

### Actualizar GPS ahora

Fuerza una nueva localización en lugar de reutilizar el último valor almacenado en caché por la aplicación. La intuición: las consultas de GPS se guardan en caché por pantalla para que una pantalla de configuración no se bloquee esperando una señal de satélite cada vez que se abre, pero esa caché puede estar desactualizada en kilómetros si has conducido a un sitio nuevo desde la última sesión. Tócalo cuando te hayas desplazado y quieras que el filtro geográfico use *aquí*, y no el punto donde empezó tu mañana. Las coordenadas actuales en caché se muestran en el subtítulo, para que puedas comprobar dónde cree la aplicación que estás. Si el GPS no consigue posición en unos 10 segundos, la aplicación recurre a la última ubicación conocida que proporciona el sistema operativo y te avisa con un SnackBar para que sepas que el valor está desactualizado.

### Descargas de mapas sin conexión

Las descargas de mapas sin conexión están ocultas por ahora mientras BirdNET Live usa el servicio público de teselas de OpenStreetMap. OpenStreetMap admite la navegación interactiva normal por el mapa con atribución, un agente de usuario claro y caché local, pero no permite la precarga masiva ni funciones de descarga de mapas sin conexión desde `tile.openstreetmap.org`. La implementación del descargador se mantiene para una futura fuente de teselas que permita explícitamente paquetes sin conexión.

### Filtro de especies

- **Desactivado** — sin filtrado geográfico
- **Filtro por ubicación** — excluir especies por debajo del umbral geográfico
- **Filtro adaptativo por ubicación** — exigir más confianza cuanto menos común sea la especie aquí
- **Ponderación por ubicación** — usar el geomodelo como señal de ponderación adicional

### Umbral del filtro geográfico

Aparece cuando está activo **Filtro por ubicación** o **Ponderación por ubicación**. El filtro adaptativo deduce su propio listón a partir de la mezcla local de especies, así que no tiene control deslizante.

### Cómo decide el filtro adaptativo

Gradúa la exigencia según lo común que sea una especie en tu ubicación, con los mismos niveles de abundancia que ves en la pantalla **Explorar**. Las especies del nivel *Abundante* no se filtran nunca; por debajo, la puntuación de detección necesaria sube de forma continua, y las especies que ni siquiera están en la lista local necesitan alrededor de 0,92 o más. Todo lo que puntúe 0,99 o más se conserva, diga lo que diga el modelo de ubicación.

| Nivel en tu ubicación | Puntuación de detección necesaria |
|---|---|
| Abundante | cualquiera |
| Común | ~0,55–0,70 |
| Frecuente | ~0,70–0,82 |
| Infrecuente | ~0,78–0,89 |
| Escasa / Rara | ~0,83–0,92 |
| Fuera de la lista local | ~0,92–0,97 |

Como los niveles se basan en el orden, esto funciona igual en un bosque tropical muy diverso que en el Ártico. Las detecciones que sobreviven conservan su puntuación original: el modelo de ubicación solo decide si se muestran. El objetivo es reducir falsos positivos de especies infrecuentes sin perder una grabación realmente clara de una de ellas.

## Exportación y sincronización

### Formatos

Marca cualquier combinación de formatos de exportación: cada guardado o compartición empaquetará todos los formatos seleccionados juntos en un único ZIP. Si eliges un solo formato sin fragmentos de audio ni informe HTML, obtendrás un archivo suelto (por ejemplo, `session.csv`) en lugar de un ZIP, por compatibilidad con versiones anteriores:

- Raven Selection Table — para usar en Cornell Raven Pro.
- CSV — se abre en cualquier hoja de cálculo.
- JSON — el más cómodo para el procesamiento programático; contiene todos los metadatos de la sesión.
- GPX — traza y waypoints para usar en herramientas cartográficas (solo tiene sentido si el GPS estaba activado).

La intuición: muchos flujos de trabajo necesitan más de un formato a la vez —un CSV para la hoja de cálculo, una tabla de Raven para quien revisa en el ordenador y un JSON para el script de análisis—. Desenredar eso con un interruptor de formato único significaba antes exportar la misma sesión tres veces. Ahora marcas los tres de una vez y viajan juntos en el ZIP.

### Incluir archivos de audio

Incluir el audio guardado junto a las tablas o metadatos exportados cuando el flujo de exportación lo admita. Compartir una sola detección también sigue este ajuste: una grabación completa de la Session se recorta a las marcas de inicio y fin exactas de esa detección, mientras que una Session solo de detecciones usa su clip conservado.

### Compartir siempre el audio como WAV

Solo se muestra cuando **Incluir archivos de audio** está activado. Al activarlo, las grabaciones FLAC se convierten a WAV antes de compartirlas o exportarlas. WAV es universalmente compatible, pero bastante más grande que FLAC, así que déjalo desactivado salvo que la herramienta de destino no pueda leer FLAC: algún software de análisis de escritorio antiguo y unos pocos formularios de subida todavía no pueden.

### Incluir metadatos de la aplicación

Al activarlo, el ZIP de exportación incorpora un archivo adjunto `*.metadata.json` que describe cómo se produjo la sesión: versión de BirdNET Live, identidad del modelo, la instantánea meteorológica capturada al inicio de la sesión y cualquier advertencia de integridad de audio detectada durante la grabación. La intuición: esa procedencia es lo que te permite (o permite a quien revisa) reproducir o auditar una sesión meses después. Desactívalo cuando quieras compartir de forma limpia solo el audio y los formatos que hayas elegido; por ejemplo, subir un único WAV a iNaturalist o eBird sin archivos específicos de la aplicación de por medio.

### Incluir informe HTML

Al activarlo, cada ZIP de exportación contiene además un archivo `<session>_report.html` junto a la tabla, los fragmentos de audio y el GPX. Ábrelo en cualquier navegador y obtendrás un resumen de la sesión listo para imprimir: tarjeta de encabezado con fecha, ubicación, observador y totales; un mapa interactivo de la traza GPS y los marcadores de detección; una tarjeta por detección con la miniatura de la taxonomía de Cornell, los nombres, la etiqueta de puntuación, tu confirmación, cualquier nota que hayas escrito y el fragmento de audio original como reproductor integrado; y los ajustes de análisis utilizados. La intuición: un CSV es estupendo para procesos de análisis pero inútil para compartir con un colaborador no técnico o imprimir un resumen de campo rápido; el informe HTML cubre ese hueco con un toque. Las miniaturas de especies y las teselas de mapa necesitan conexión la primera vez que se abre el archivo (se obtienen en directo de la API de taxonomía de BirdNET y de OpenStreetMap), pero todo lo demás —texto, maquetación, reproducción de audio, enlaces— funciona totalmente sin conexión. Desactívalo si solo necesitas los datos en bruto y quieres un ZIP unos pocos KB más pequeño.

### Compartir solo el audio

Desmarca todos los formatos **y** el informe HTML **y** la casilla de metadatos de la aplicación, dejando solo **Incluir archivos de audio**, y Compartir entregará al panel del sistema la grabación en bruto (por ejemplo, `BirdNET_Live_…flac`) en lugar de un ZIP. Esa es la vía más directa para enviar una sesión a iNaturalist, eBird o cualquier otra aplicación que espere un archivo de audio sin empaquetar. Las Sessions con varios fragmentos de detección siguen produciendo un ZIP; al compartir una sola detección se entrega ese único clip en bruto.

## Privacidad

Esta sección controla **a qué servicios de terceros puede contactar BirdNET Live en tu nombre**. La inferencia en sí se ejecuta íntegramente en tu dispositivo: estos interruptores solo rigen funciones de red opcionales que enriquecen la experiencia. Los tres interruptores están **desactivados de forma predeterminada** en una instalación nueva; no sale nada hacia fuera hasta que tú lo autorizas. La intuición: cada interruptor se limita a un servicio concreto y a un beneficio concreto, así que puedes habilitar exactamente lo que te resulte útil en tu trabajo y nada más.

### Permitir teselas de mapa

Necesario para cualquier mapa interactivo de la aplicación (el selector de ubicación, el mapa en directo de Survey y el mapa de la sesión). Al activarlo, los componentes de mapa obtienen teselas ráster de los servidores públicos de **OpenStreetMap**; las peticiones de coordenadas de teselas revelan qué zona del mundo estás viendo. Las teselas se almacenan localmente en caché hasta seis meses, con un tope de 6000 teselas para que las consultas repetidas de mapa sigan siendo eficientes sin crecer sin límite. Activarlo habilita también **Permitir búsqueda de nombres de lugar**, porque la mayoría de quienes cargan mapas esperan que las sesiones muestren además nombres de lugar legibles. Después puedes desactivar por separado la búsqueda de nombres de lugar. Cuando las teselas de mapa están desactivadas, cada pantalla de mapa recurre a una tarjeta de marcador de posición, de modo que el resto de la aplicación sigue funcionando sin fugas a la red.

### Permitir búsqueda de nombres de lugar

Al activarlo, la aplicación envía tus coordenadas registradas al servicio **Nominatim de OpenStreetMap** para resolver un nombre de lugar corto (por ejemplo, *«Berlín, Alemania»*) que se muestra junto a la sesión en la Biblioteca de sesiones y en la Revisión de la sesión. La intuición: las coordenadas numéricas son precisas pero difíciles de leer de un vistazo al recorrer una lista larga de sesiones; un nombre de lugar convierte la lista en algo legible al instante. Al desactivarlo, las sesiones muestran solo la latitud y longitud en bruto, y nunca se contacta con Nominatim.

### Permitir consulta meteorológica

Al activarlo, cada sesión guardada captura mediante **Open-Meteo** una instantánea puntual de las condiciones locales (temperatura, precipitación, viento, nubosidad) en las coordenadas de grabación y la hora de finalización. La instantánea aparece en la Revisión de la sesión bajo la fila de ubicación y se refleja en la exportación JSON, el bloque de metadatos de la sesión y el informe HTML. La intuición: el tiempo es uno de los predictores más fuertes de la actividad de las aves, y capturarlo automáticamente —sin que tengas que acordarte de consultar otra aplicación— convierte cada sesión en un registro más completo. Open-Meteo es un servicio gratuito y no requiere cuenta ni clave de API. Al desactivarlo, no se obtienen ni se guardan datos meteorológicos. La configuración de Point Count y Survey también muestra una tarjeta meteorológica compacta cerca de los controles de ubicación: pide este consentimiento solo cuando hace falta, muestra el resultado como icono + temperatura + viento una vez habilitado, y reutiliza la misma instantánea en caché al guardar la sesión.

## Acerca de

La fila **Acerca de** abre la pantalla de información dentro de la aplicación.

## Zona de peligro

### Restablecer la introducción

Vuelve a mostrar la secuencia de introducción la próxima vez que se inicie la aplicación.

### Restablecer todos los ajustes

Devuelve cada preferencia de esta pantalla a su valor predeterminado. Las sesiones, grabaciones, notas de voz, exportaciones y teselas de mapa en caché se mantienen intactas: solo se borran las preferencias guardadas (controles deslizantes, interruptores, opciones de selección). La aplicación se cierra tras la confirmación para que los nuevos valores predeterminados surtan efecto en el siguiente inicio.

Útil cuando no estás seguro de qué control moviste y algo dejó de funcionar, o cuando entregas el dispositivo a otra persona y quieres una configuración limpia sin perder los datos que has recogido.

### Borrar todos los datos

Elimina de forma permanente sesiones, detecciones, grabaciones, notas de voz, listas de especies personalizadas, preferencias guardadas y los datos en caché de mapas, nombres de lugar, meteorología, reproducción, revisión y compartición. El diálogo de confirmación exige escribir `DELETE` y después cierra la aplicación, de modo que el siguiente inicio parta de un estado local limpio.

Úsalo antes de entregar un dispositivo a otro observador, retirar un teléfono de campo o eliminar de la aplicación el historial vinculado a ubicaciones. Exporta antes todo lo que necesites; esta acción no se puede deshacer.

## Parámetros específicos de cada flujo fuera de Ajustes

Algunos parámetros se configuran en sus propias pantallas de configuración en lugar de en la pantalla de Ajustes compartida.

- [Modo Point Count](point-count-mode.md) tiene su propia configuración de duración y ubicación.
- [Modo Survey](survey-mode.md) tiene su propia pantalla de parámetros de muestreo.
- [Análisis de archivos](file-analysis.md) tiene su propio paso de parámetros de análisis.
