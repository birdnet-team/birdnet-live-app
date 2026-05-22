# Política de Privacidad

**Última actualización:** Mayo 2026

BirdNET Live respeta su privacidad. Este documento explica cómo la aplicación maneja sus datos.

## Procesamiento en el dispositivo
Todo el análisis de audio ocurre **completamente en su dispositivo** mediante el **Clasificador BirdNET+** y el **Geomodelo**. Ningún audio se transmite a servidores.

## Recopilación de datos
BirdNET Live **no** recopila, transmite ni comparte datos personales o telemetría.
- Audio, metadatos, GPS y configuraciones se guardan **localmente** en archivos y preferencias de la app.
- Imágenes y datos taxonómicos de las especies están integrados de forma offline.
- Cuando **Permitir consulta meteorológica** está activo, cada sesión guarda localmente una instantánea de temperatura, precipitación, viento, nubosidad y código del tiempo en sus coordenadas.

## Recursos Externos

La app puede acceder a los siguientes servicios externos. Cada uno está controlado por un interruptor independiente bajo **Ajustes → Privacidad**, y **los tres están desactivados por defecto** en una instalación nueva. Nada sale de su dispositivo hasta que usted lo permita.

| Recurso | Propósito | Interruptor | Enviado en cada solicitud |
|---------|-----------|-------------|---------------------------|
| Mosaicos de mapa (OpenStreetMap) | Mapa base para selector de ubicación, mapa en vivo de Survey y mapa de la sesión | **Ajustes → Privacidad → Permitir mosaicos de mapa** | Coordenadas de mosaico `(z, x, y)` y user-agent de BirdNET Live — sin PII |
| Geocodificación inversa (OpenStreetMap Nominatim) | Resolver coordenadas GPS en un nombre de lugar (p. ej. “Madrid, España”) | **Ajustes → Privacidad → Permitir búsqueda de nombre de lugar** | Lat/lon de la sesión y user-agent de BirdNET Live |
| Instantánea meteorológica (Open-Meteo) | Captura puntual de las condiciones (temperatura, precipitación, viento, nubes, código WMO) en las coordenadas y la hora de fin | **Ajustes → Privacidad → Permitir consulta meteorológica** | Lat/lon de la sesión y marca temporal de fin, más user-agent de BirdNET Live |

Las solicitudes de mosaicos son HTTPS GET estándar a `tile.openstreetmap.org`; la geocodificación inversa va a `nominatim.openstreetmap.org` siguiendo la [Política de uso de Nominatim](https://operations.osmfoundation.org/policies/nominatim/); las consultas meteorológicas van a `api.open-meteo.com`. [Open-Meteo](https://open-meteo.com/) es un servicio gratuito y no requiere cuenta ni clave API.

**Retención:** ninguno de estos servicios externos almacena datos del usuario. Los valores devueltos (nombre del lugar, instantánea meteorológica) viven sólo en el registro local de la sesión y sólo viajan a los archivos de exportación que usted produzca explícitamente.

**Revocación:** puede desactivar cualquiera de los tres servicios en cualquier momento bajo **Ajustes → Privacidad**. Para borrar nombres de lugar e instantáneas meteorológicas históricos, elimine esas sesiones en Session Library o use **Ajustes → Zona de peligro → Borrar todos los datos**.

## GPS y Exportación de Datos
El GPS se usa para filtros y encuestas de especies. Bajo **Ajustes → Exportar → Formatos** puede marcar cualquier combinación de formatos (Raven Selection Table, CSV, JSON, GPX) y los exportados se agruparán en un único ZIP junto con los clips de audio y el informe HTML opcional. Los datos no se suben a la nube.
Puede eliminar sesiones individuales desde Session Library. Para borrar dentro de la app sesiones locales, grabaciones, notas de voz, listas de especies personalizadas, preferencias y cachés de BirdNET Live, use **Ajustes → Zona de peligro → Borrar todos los datos**. También puede borrar el almacenamiento de BirdNET Live en los ajustes del sistema o desinstalar la app.

## Contacto
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
