# Preguntas frecuentes

Preguntas frecuentes.

## General

**P: ¿BirdNET Live requiere una conexión a Internet?**
R: No. Toda la inferencia se ejecuta en el dispositivo utilizando el modelo ONNX. Las únicas funciones de red son opcionales y están desactivadas de forma predeterminada: los mosaicos del mapa y la búsqueda de nombres de lugar de OpenStreetMap, los datos del clima de Open-Meteo y la consulta de imágenes y descripciones de especies desde la API de taxonomía. Consulta [Ajustes → Privacidad](settings.md#privacidad).

**P: ¿Cuántas especies puede identificar?**
R: El modelo BirdNET+ V3.0 identifica 10 048 especies en todo el mundo: aves, anfibios, mamíferos e insectos (la intersección podada del clasificador de audio y el geomodelo). También reconoce 16 sonidos no animales, como motores, sirenas y música; están desactivados salvo que actives [Sonidos no animales](settings.md#sonidos-no-animales).

**P: Una especie de una Session antigua tiene un nombre nuevo o ya no se detecta. ¿He perdido algo?**
R: No. Una actualización del modelo puede renombrar especies para seguir la taxonomía actual y eliminar especies que el nuevo modelo no cubre. Las Sessions guardadas no se modifican: una detección antigua se muestra con el nombre actual de la especie, con su imagen, traducción y enlaces, y las especies que el modelo ya no detecta permanecen en tus Sessions y exportaciones tal como se registraron.

**P: ¿Qué plataformas son compatibles?**
R: Android (8.0+), iOS (15.0+) y Windows (experimental).

## Precisión

**P: ¿Por qué mi umbral de confianza muestra puntuaciones bajas?**
R: Baja el umbral de confianza en Ajustes para ver más detecciones. El ruido de fondo, el viento y la distancia afectan a la precisión.

**P: ¿Qué hace el filtro de especies?**
R: El geomodelo predice qué especies es probable encontrar en tu ubicación GPS y en esa época del año. Activa **Filtro geográfico** para ocultar especies poco probables, **Filtro geográfico adaptativo** para ocultar solo aquellas de las que el modelo de audio tampoco está seguro, o **Ponderación geográfica** para ponderar los resultados según la probabilidad geográfica.

**P: ¿Qué tan precisa es la identificación?**
R: La precisión depende de la calidad de la grabación, la distancia, el ruido de fondo y la especie. Las detecciones de alta confianza (>70 %) suelen ser fiables. Verifica siempre visualmente las especies raras.

## Grabación

**P: ¿Dónde se guardan las grabaciones?**
R: En el directorio de documentos de la aplicación, en `recordings/<session-id>/`, en formato WAV o FLAC según **Ajustes → Audio y grabación → Formato de grabación**.

**P: ¿Puedo analizar grabaciones existentes?**
R: Sí. Abre Análisis de archivos desde la pantalla de inicio, elige un archivo de audio, indica la ubicación y los parámetros y toca Iniciar análisis. Los formatos admitidos incluyen WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA y AMR.

## Point Count

**P: ¿Qué es el modo Point Count?**
R: Un modo cronometrado para censos formales de aves desde un punto fijo. Estableces una duración fija (de 3 a 30 minutos) y una ubicación; después la aplicación escucha de forma continua y se detiene automáticamente cuando el temporizador llega a cero.

**P: ¿Puedo pausar un Point Count?**
R: No. El protocolo exige una grabación ininterrumpida. Puedes finalizarlo antes de tiempo con el botón de detener.

**P: ¿Adónde van los resultados de un Point Count?**
R: Aparecen en la biblioteca de Sessions como "Point Count #1", "#2", etc. Puedes revisarlos, editarlos y exportarlos como cualquier otra Session.

## Rendimiento

**P: ¿Por qué el teléfono se calienta o la aplicación consume mucha batería?**
R: La inferencia del modelo ONNX requiere mucho cálculo. Además, la pantalla permanece encendida durante las Sessions en vivo. Es normal en el procesamiento de redes neuronales en tiempo real.

**P: El espectrograma parece congelado.**
R: Asegúrate de haber concedido el permiso de micrófono y de que la captura de audio esté activa. Comprueba que ninguna otra aplicación esté usando el micrófono.