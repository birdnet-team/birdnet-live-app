# Preguntas frecuentes

Preguntas frecuentes.

## General

**P: ¿BirdNET Live requiere una conexión a Internet?**
R: No. Toda la inferencia se ejecuta en el dispositivo utilizando el modelo ONNX. Las únicas características de la red son las búsquedas de imágenes/descripciones de especies desde la API de taxonomía, que son opcionales.

**P: ¿Cuántas especies puede identificar?**
R: El modelo BirdNET+ V3.0 identifica 5250 especies de aves en todo el mundo (la intersección podada del clasificador de audio y el modelo geográfico).

**P: ¿Qué plataformas son compatibles?**
R: Android (8.0+), iOS (15.0+) y Windows (experimental).

## Exactitud

**P: ¿Por qué mi umbral de confianza muestra puntuaciones bajas?**
R: Reduzca el umbral de confianza en Configuración para ver más detecciones. El ruido de fondo, el viento y la distancia afectan la precisión.

**P: ¿Qué hace el filtro de especies?**
R: El modelo geográfico predice qué especies probablemente se encuentren en su ubicación GPS y en la época del año. Habilite "Geo Exclude" para ocultar especies poco probables o "Geo Merge" para ponderar los resultados según la probabilidad geográfica.

**P: ¿Qué tan precisa es la identificación?**
R: La precisión depende de la calidad de la grabación, la distancia, el ruido de fondo y la especie. Las detecciones de alta confianza (>70%) son generalmente fiables. Siempre verifique visualmente las especies raras.

## Grabación

**P: ¿Dónde se guardan las grabaciones?**
R: En el directorio de documentos de la aplicación en `grabaciones/<id-de sesión>/`. Las grabaciones completas se guardan como archivos WAV.

**P: ¿Puedo analizar grabaciones existentes?**
R: Sí. Abra Análisis de archivos desde la pantalla de inicio, elija un archivo de audio, establezca la ubicación y los parámetros y toque Analizar. Los formatos admitidos incluyen WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA y AMR.

## Recuento de puntos

**P: ¿Qué es el modo de conteo de puntos?**
R: Un modo de conteo por puntos cronometrado para observaciones formales de aves. Usted establece una duración fija (de 3 a 20 minutos) y una ubicación, luego la aplicación se ejecuta continuamente y se detiene automáticamente cuando el temporizador llega a cero.

**P: ¿Puedo pausar un conteo de puntos?**
R: No. El cumplimiento del protocolo requiere una grabación ininterrumpida. Puede finalizar temprano mediante el botón de parada.

**P: ¿A dónde van los resultados del recuento de puntos?**
R: Aparecen en la biblioteca de sesiones como "Recuento de puntos n.° 1", "n.° 2", etc. Puede revisarlos, editarlos y exportarlos como cualquier otra sesión.

## Actuación

**P: ¿Por qué la aplicación está caliente o usando batería?**
R: La inferencia del modelo ONNX requiere mucha computación. La pantalla también permanece encendida durante las sesiones en vivo. Esto es normal para el procesamiento de redes neuronales en tiempo real.

**P: El espectrograma parece congelado.**
R: Asegúrese de que se otorgue el permiso del micrófono y que la captura de audio esté activa. Verifique que ninguna otra aplicación esté usando el micrófono.
