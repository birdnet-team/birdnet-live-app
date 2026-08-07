# Análisis de archivos

El Análisis de archivos procesa una grabación existente a través del mismo pipeline de BirdNET que impulsa los flujos de trabajo en directo.

## Cómo abrirlo

Desde Inicio, toca la tarjeta **Análisis de archivos** con el icono :material-file-music:.

## Barra de aplicaciones

- :material-tune: — abre los Ajustes de Análisis de archivos
- :material-close: — cancela un análisis en curso

## Entradas admitidas

El selector de archivos actual acepta:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Asistente de cuatro pasos

### 1. Archivo

Elige un archivo y revisa su tarjeta de metadatos:

- nombre del archivo
- formato
- duración
- tamaño del archivo
- frecuencia de muestreo

### 2. Ubicación y fecha

Puedes:

- usar el GPS actual
- introducir coordenadas manualmente
- omitir la ubicación
- elegir un punto en el mapa
- establecer una fecha de grabación opcional

### 3. Parámetros

El asistente muestra:

- duración de la ventana
- superposición de ventanas
- sensibilidad
- umbral de confianza
- modo de filtro de especies

El solapamiento controla cuánto avanza cada ventana de análisis y es
específico del análisis de archivos: el archivo completo siempre se examina, y
más solapamiento simplemente lo examina con mayor detalle. Los modos en
directo usan en su lugar una frecuencia de inferencia, porque deben decidir
con qué frecuencia ejecutarse sobre el audio entrante y no con qué detalle
cubrir una grabación fija.

Sea cual sea la forma en que el análisis de archivos llega a sus ventanas, las
convierte en detecciones con las mismas reglas que el modo Live, Point Count y
Survey: una detección comienza en su ventana de apoyo más temprana, lleva la
puntuación respaldada más alta y termina al final de la última ventana de
apoyo.

### 4. Análisis

La pantalla de progreso muestra:

- ventanas procesadas
- detecciones encontradas
- especies encontradas
- botón de cancelar

## Resultado

Cuando finaliza el análisis, BirdNET Live convierte el resultado en una Session guardada y abre el [Resumen de la Session](session-review.md).
