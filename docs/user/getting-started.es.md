# Primeros pasos

## Instalación

BirdNET Live está disponible para Android, iOS y Windows.

### Requisitos

- **Android**: 8.0 (API 26) o posterior
- **iOS**: 15.0 o posterior
- **Windows**: 10 o posterior (experimental)
- ~300 MB de almacenamiento para la app y los modelos

### Descarga

- **Android**: [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), o instala manualmente el APK firmado desde la [página de versiones de GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS**: [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows**: compila desde el código fuente; consulta la [Guía para desarrolladores](../developer/building.md).

## Primer uso de la app

La primera vez que abres BirdNET Live, la app te guía por una breve introducción y la configuración de permisos.

1. Lee las pantallas de introducción.
2. Revisa la Política de uso aceptable y la Política de Privacidad.
3. Concede el permiso de micrófono para que BirdNET Live pueda procesar el audio.
4. Opcionalmente, concede el permiso de ubicación para el geoetiquetado, Explorar, Point Count y Survey.
5. Opcionalmente, permite las notificaciones para los Surveys de larga duración.

## Primer inicio

1. **Introducción** — Presentación rápida de las funciones y los permisos
2. **Uso aceptable y privacidad** — revisa la Política de uso aceptable y la Política de Privacidad
3. **Permisos** — Concede el acceso al micrófono (obligatorio para todos los modos)
4. **Listo** — ¡Empieza a identificar aves!

## La pantalla de inicio

La pantalla de inicio es el centro principal.

### Tarjetas de los modos principales

- :material-microphone: **Modo Live**
- :material-map-marker: **Modo Point Count**
- :material-routes: **Modo Survey**
- :material-file-music: **Análisis de archivos**

### Botones del pie

- :material-tune: **Ajustes**
- :material-magnify: **Explorar**
- :material-music-box-multiple-outline: **Biblioteca de sesiones**
- :material-help-circle-outline: **Ayuda**
- :material-information-outline: **Acerca de**

## Qué se guarda

BirdNET Live guarda automáticamente cada Session completada y la abre en el Resumen de la Session cuando se detiene el procesamiento.

- Las Live Sessions guardan las detecciones y, según tus ajustes, las grabaciones o los clips.
- Las Sessions de Point Count se guardan como Sessions de Point Count cronometradas.
- Las Sessions de Survey guardan el recorrido, las detecciones y los metadatos relacionados.
- Los resultados del Análisis de archivos se convierten en una Session que puedes revisar.

## Páginas recomendadas a continuación

- Lee [Iconos y controles](icons-and-controls.md) si quieres una explicación rápida de los símbolos recurrentes de la interfaz.
- Lee [Ajustes](settings.md) antes de cambiar umbrales, filtros, el comportamiento de la grabación o la visualización del espectrograma.
- Abre la guía del flujo de trabajo que más utilices: [Modo Live](live-mode.md), [Modo Point Count](point-count-mode.md), [Modo Survey](survey-mode.md) o [Análisis de archivos](file-analysis.md).

## Permisos

| Permiso | Necesario para | ¿Opcional? |
|------------|-------------|-----------|
| Micrófono | Todos los modos de grabación | Obligatorio |
| Ubicación | Geoetiquetado, Survey/Point Count | Opcional en Live |
| Almacenamiento | Guardar grabaciones y exportaciones | Obligatorio para grabar |
| Notificaciones | Alertas de Survey en segundo plano | Opcional |
