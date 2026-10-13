# Explorar

Explorar muestra las especies previstas para la ubicación y la temporada actuales usando el geomodelo de BirdNET.

## Cómo abrirlo

Abre **Explorar** desde el pie de página de Inicio con el botón :app-searchRounded:.

## Barra de la aplicación y encabezado

### Barra de la aplicación

- :app-refresh: — actualiza la ubicación y reconstruye la lista de especies previstas

### Encabezado de ubicación

El encabezado muestra:

- el nombre del lugar actual mediante geocodificación inversa cuando está disponible
- las coordenadas debajo del nombre del lugar
- :app-helpOutlineRounded: — abre la hoja de ayuda de Explorar

## Lista de especies

Cada ficha de especie puede incluir:

- imagen de la especie incluida
- nombre común
- nombre científico opcional
- indicador de nivel de abundancia

Toca una ficha para abrir el panel de detalles de la especie.

### Niveles de abundancia

En lugar de un porcentaje bruto, cada ficha muestra un **nivel de abundancia** para el lugar y la temporada actuales. El indicador de nivel combina dos señales:

- un **círculo** que se llena de ⅙ a completo a medida que la especie es más probable
- la **primera letra** del nombre del nivel (el nombre completo lo leen los lectores de pantalla y se muestra en los detalles de la especie)

El color del indicador sigue la escala de puntuación compartida de la app, pasando del rojo (menos probable) al verde (más probable) a medida que sube el nivel.

Hay seis niveles, de más a menos probable:

| Nivel | Significado |
| --- | --- |
| **Abundante** | Entre las predicciones más fuertes aquí |
| **Común** | Muy probable |
| **Frecuente** | Probable |
| **Infrecuente** | Posible |
| **Escasa** | Improbable |
| **Rara** | Entre las predicciones más débiles aquí |

Los niveles son **relativos a la ubicación actual**. Se adaptan a la fuerza con que el geomodelo predice especies en esta zona, por lo que los límites se desplazan con la distribución local de puntuaciones: en un lugar con muchas predicciones seguras, una especie necesita una puntuación muy alta para ser *Abundante*, mientras que en una zona con predicciones más débiles se alcanza el mismo nivel con una puntuación menor. Así, la misma puntuación puede caer en niveles distintos en lugares distintos, lo que mantiene útil la clasificación en todas partes.

## Panel de detalles de la especie

El panel puede mostrar:

- imagen más grande
- crédito de la imagen
- nombres común y científico
- texto de descripción incluido cuando está disponible
- gráfico semanal de frecuencia esperada
- enlaces externos como eBird, iNaturalist o Wikipedia cuando están disponibles para esa especie

## Para qué sirve Explorar

Explorar es una vista de referencia, sensible a la ubicación, dentro de la app. Te ayuda a comparar el contexto de ubicación actual de la app con las especies que cabría esperar encontrar.

**No** modifica por sí solo los datos guardados de las Sessions. El filtrado de detecciones se controla por separado en [Ajustes](settings.md).
