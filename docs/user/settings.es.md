# Ajustes

BirdNET Live reutiliza una pantalla de Configuración en múltiples flujos de trabajo. El botón :material-tune: abre las secciones que son relevantes para la pantalla de donde vienes.

## Cómo funciona el ámbito de configuración

- Al abrir Configuración desde Inicio se muestra la pantalla completa.
- Al abrir la Configuración desde En vivo, Encuesta, Conteo de puntos o Análisis de archivos, la pantalla se filtra a las secciones relevantes.

## General

### Tema

Elija **Oscuro**, **Claro** o **Sistema**.

### Idioma de la aplicación

Establece el idioma de la interfaz.

### Nombres de especies

Controla el idioma utilizado para los nombres de especies. **Seguir idioma de la aplicación** usa el mismo idioma que la interfaz cuando ese nombre está disponible.

### Mostrar nombres científicos

Muestra nombres científicos debajo de nombres comunes en toda la aplicación.

### Visualización de marcas de tiempo

Controla cómo aparecen las horas de cada detección en la revisión de la sesión.

- **Relativo** muestra el desfase desde el inicio de la grabación, p. ej. `00:12:34`. Es lo mejor para revisar una sola sesión y alinearse con el espectrograma.
- **Absoluto** muestra la hora local en que se capturó la detección, p. ej. `08:42:17`. Es lo mejor para cruzar datos con notas de campo, registros meteorológicos o grabaciones simultáneas.

Si una detección cae en un día calendario distinto al del inicio de la sesión (p. ej. un seguimiento nocturno), la hora absoluta recibe el sufijo `+1d` para que los revisores no confundan el amanecer de mañana con el de hoy.

Cuando está seleccionado **Absoluta**, aparece además un interruptor **Mostrar segundos en marcas de tiempo**. Desáctivalo si prefieres el formato más compacto `08:42` en lugar de `08:42:17` — útil al revisar listas largas de detecciones. Los desplazamientos relativos siempre muestran segundos porque la alineación con el espectrograma requiere precisión inferior al minuto.

Cuando está seleccionado **Absoluta**, aparece además un interruptor **Mostrar segundos en marcas de tiempo**. Desáctivalo si prefieres el formato más compacto `08:42` en lugar de `08:42:17` — útil al revisar listas largas de detecciones. Los desplazamientos relativos siempre muestran segundos porque la alineación con el espectrograma requiere precisión inferior al minuto.

El almacenamiento y las exportaciones siempre usan instantes UTC independientemente de este ajuste, por lo que la elección nunca afecta a los datos — solo a su presentación.

##Audio

Estos controles aparecen en flujos de trabajo en vivo basados ​​en audio.

### Ganar

Ajusta la ganancia de entrada que se muestra en la aplicación. Utilícelo sólo cuando necesite compensar grabaciones o entradas muy silenciosas.

### Filtro de paso alto (Hz)

Reduce el ruido de baja frecuencia antes de la inferencia.

### Micrófono

Le permite elegir un dispositivo de entrada específico o mantener el **sistema predeterminado**.

## Inferencia

### Duración de la ventana

Controla la longitud de la ventana de análisis.

### Umbral de confianza

Establece cuán conservadoras deben ser las detecciones.

### Sensibilidad

Los valores más altos hacen que el detector sea más permisivo, lo que puede recuperar llamadas más débiles a costa de más falsos positivos.

### Tasa de inferencia

Controla la frecuencia con la que BirdNET ejecuta la inferencia.

### Agrupación de puntuaciones

Controla cómo se combinan las ventanas de análisis superpuestas.

## Espectrograma

### Tamaño de FFT

Controla la resolución de frecuencia en el espectrograma.

### Mapa de colores

Elija **Viridis**, **Magma** o **Escala de grises**.

### Duración (velocidad de desplazamiento)

Controla cuánto tiempo es visible en la ventana del espectrograma.

### Rango de frecuencia

Establece la frecuencia de visualización superior.

### Amplitud del registro

Aplica una escala logarítmica al espectrograma para facilitar la lectura visual.

## Grabación

### Modo

- **Completo**: guarda toda la grabación
- **Solo detecciones**: guarda clips sobre las detecciones
- **Desactivado**: no hay grabación de audio

### Contexto del clip

Cuando **Solo detecciones** está activo, la aplicación muestra un único control deslizante **Contexto del clip** (0 a 5 s) que establece cuánto audio se conserva en **ambos lados** de cada detección. Cada clip tiene una longitud de `ventana de análisis + 2 × contexto de clip`, por lo que con una ventana de análisis de 3 s y el contexto predeterminado de 1 s, el clip guardado es de 5 s. Establecer el contexto en 2 s produce un clip de 7 s (2 s pre-roll + 3 s de audio analizado + 2 s post-roll). Los valores más altos le brindan más espacio para la inspección visual o herramientas de revisión externas a costa de espacio en disco; 0 guarda solo la ventana analizada.

### Formato

Elija **WAV** o **FLAC**.

## Ubicación

### Usar GPS

Utilice el GPS del dispositivo en lugar de las coordenadas manuales.

### Latitud / Longitud

Coordenadas manuales utilizadas cuando el GPS está desactivado.

### Filtro de especies

- **Desactivado**: sin filtrado geográfico
- **Filtro de ubicación**: excluye especies que se encuentran por debajo del umbral geográfico
- **Ponderación de ubicación**: utilice el modelo geográfico como señal de ponderación adicional

### Umbral de filtro geográfico

Aparece cuando está activo un modo de filtro basado en la ubicación.

## Exportar y sincronizar

### Formatos

Marque cualquier combinación de formatos de exportación: cada acción de guardar / compartir agrupa todos los formatos seleccionados juntos en un único ZIP. Si elige un solo formato sin clips de audio y sin informe HTML, obtendrá un archivo crudo (p. ej. `session.csv`) por compatibilidad:

- Tabla de selección Raven — para Cornell Raven Pro.
- CSV — se abre en cualquier hoja de cálculo.
- JSON — ideal para procesamiento programático; lleva los metadatos completos de la sesión.
- GPX — traza y waypoints para apps de mapas (únicamente útil cuando hubo GPS).

La intuición: muchos flujos necesitan varios formatos a la vez — un CSV para la hoja, una tabla Raven para el revisor de escritorio y un JSON para el script de análisis. Antes había que exportar la misma sesión tres veces; ahora marca los tres una vez y viajan juntos en el ZIP.

### Incluir archivos de audio

Incluya audio guardado junto con las tablas o metadatos exportados cuando lo admita el flujo de trabajo de exportación.

## Privacidad

Esta sección controla **qué servicios de terceros puede contactar BirdNET Live en su nombre**. La inferencia se ejecuta íntegramente en su dispositivo: estos interruptores solo gobiernan funciones de red opcionales. Los tres interruptores están **desactivados por defecto** en una instalación nueva; nada sale de su dispositivo hasta que usted lo permita. La intuición: cada interruptor cubre un servicio concreto y un beneficio concreto, para que active exactamente lo que necesita.

### Permitir mosaicos de mapa

Necesario para cualquier mapa interactivo (selector de ubicación, mapa en vivo de Survey, mapa de la sesión). Cuando está activo, los widgets de mapa solicitan mosaicos ráster a los servidores públicos de **OpenStreetMap**; las solicitudes de coordenadas de mosaico revelan qué zona del mundo está mirando. Cuando está desactivado, todas las pantallas de mapa muestran un panel de marcador de posición.

### Permitir búsqueda de nombre de lugar

Cuando está activo, la app envía sus coordenadas grabadas al servicio **Nominatim** de OpenStreetMap para resolver un nombre de lugar corto (p. ej. “Madrid, España”) que se muestra junto a la sesión en la Biblioteca de sesiones y en Revisión de sesión. La intuición: las coordenadas numéricas son precisas pero difíciles de leer en una lista larga; un nombre de lugar la vuelve legible de un vistazo. Cuando está desactivado, solo se muestran las coordenadas y nunca se contacta a Nominatim.

### Permitir consulta meteorológica

Cuando está activo, cada sesión guardada captura una instantánea única de las condiciones locales (temperatura, precipitación, viento, nubosidad) en las coordenadas y la hora de finalización a través de **Open-Meteo**. La instantánea aparece en Revisión de sesión bajo la fila de ubicación y se incluye en la exportación JSON, el bloque de metadatos y el informe HTML. La intuición: el clima es uno de los predictores más fuertes de la actividad de aves, y capturarlo automáticamente convierte cada sesión en un registro más completo. Open-Meteo es gratuito y no requiere cuenta ni clave API. Cuando está desactivado, no se obtienen ni almacenan datos meteorológicos.

## Acerca de

La fila **Acerca de** abre la pantalla Acerca de en la aplicación.

## Zona de peligro

### Restablecer incorporación

Muestra la secuencia de incorporación nuevamente la próxima vez que se inicie la aplicación.

### Borrar todos los datos

Elimina permanentemente sesiones, detecciones, grabaciones, notas de voz, listas de especies personalizadas, preferencias guardadas y datos en caché de mapas, nombres de lugar, clima, reproducción, revisión y uso compartido. El diálogo de confirmación exige escribir `DELETE` y luego cierra la app para que el próximo inicio parta de un estado local limpio.

Úselo antes de entregar un dispositivo a otra persona observadora, retirar un teléfono de campo o quitar del app historial vinculado a ubicaciones. Exporte primero todo lo que quiera conservar; esta acción no se puede deshacer.

## Parámetros específicos del flujo de trabajo fuera de la configuración

Algunos parámetros se configuran dentro de sus propias pantallas de configuración en lugar de en la pantalla de configuración compartida.

- [Modo de recuento de puntos] (point-count-mode.md) tiene su propia duración y configuración de ubicación.
- [Modo de encuesta] (survey-mode.md) tiene su propia pantalla de parámetros de encuesta.
- [Análisis de archivos](file-analysis.md) tiene su propio paso de parámetro de análisis.