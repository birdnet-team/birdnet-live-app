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

## Audio

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

### Formato

Elija un destino de exportación:

- Tabla de selección de cuervos
-CSV
-JSON
- GPX (pista + puntos de referencia)

### Incluir archivos de audio

Incluya audio guardado junto con las tablas o metadatos exportados cuando lo admita el flujo de trabajo de exportación.

## Acerca de

La fila **Acerca de** abre la pantalla Acerca de en la aplicación.

## Zona de peligro

### Restablecer incorporación

Muestra la secuencia de incorporación nuevamente la próxima vez que se inicie la aplicación.

### Borrar todos los datos

Abre un flujo de confirmación para eliminar permanentemente los datos almacenados de la aplicación.

## Parámetros específicos del flujo de trabajo fuera de la configuración

Algunos parámetros se configuran dentro de sus propias pantallas de configuración en lugar de en la pantalla de configuración compartida.

- [Conteo por puntos](point-count-mode.md) tiene su propia duración y configuración de ubicación.
- [Transecto](survey-mode.md) tiene su propia pantalla de parámetros de encuesta.
- [Análisis de archivos](file-analysis.md) tiene su propio paso de parámetro de análisis.
