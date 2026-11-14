# Modo ARU

!!! note "Implementación temprana"
    El modo ARU actualmente guarda puntos de control del despliegue programado, graba ciclos programados, ejecuta inferencia en vivo durante los ciclos activos, guarda clips de detección retenidos cuando se selecciona ese modo de grabación y muestra controles de notificación en primer plano en Android. El comportamiento en segundo plano en iOS aún necesita validación de campo.

El modo ARU (Autonomous Recording Unit) es el flujo de trabajo para despliegues acústicos programados en una ubicación fija.

## Flujo de configuración actual

- **Detalles y ajustes de análisis**:
    - **Metadatos**: Introduce un nombre de despliegue, el ID de ARU/estación y el nombre del observador.
    - **Ubicación**: Indica las coordenadas del sitio mediante la adquisición automática por GPS o la entrada manual de latitud y longitud, o bien omite la ubicación. La latitud y la longitud son obligatorias si se usa un horario vinculado al sol. Iconos: GPS :app-myLocation:, coordenadas manuales :app-editLocationAlt:, omitir ubicación :app-locationOff: y selector de mapa :app-mapSheet:.
    - **Análisis**: Elige el micrófono, la tasa de inferencia, el umbral de confianza y la sensibilidad.
    - **Formato de grabación**: Elige entre los formatos FLAC (comprimido sin pérdidas) y WAV (sin comprimir).
    - **Modo de grabación**:
        - *Completo*: Graba la duración total de cada ciclo activo.
        - *Solo detecciones*: Guarda clips de audio cortos alrededor de las vocalizaciones detectadas. Puedes personalizar el contexto del clip (añadiendo entre 0 y 5 segundos de búfer de audio antes y después de la detección) y elegir el método de muestreo (*Todas*, *Top N* o muestreo *Smart* para limitar el uso del almacenamiento).
        - *Desactivado*: Ejecuta inferencia en tiempo real durante los ciclos y registra las detecciones, pero no guarda ningún archivo de audio.
- **Horario**:
    - **Duración y repetición**: Selecciona cuánto dura cada ciclo de grabación activo y con qué frecuencia se repite.
    - **Ventana de grabación (Patrón diurno/nocturno)**: Elige grabar las 24 horas del día (*Continuo*) o restringe los ciclos a *Horas de luz*, *Noche* o a ventanas específicas: *Alrededor del amanecer*, *Alrededor del atardecer* o *Alrededor del amanecer y el atardecer*. Las ventanas de amanecer/atardecer se calculan dinámicamente en función de las coordenadas del despliegue.
    - **Fin del despliegue**: Elige si quieres detener el despliegue manualmente, detenerlo tras un número fijo de ciclos completados o detenerlo automáticamente en una fecha y hora concretas.
    - **Gestión de batería**: Establece un umbral de pausa por batería baja (0-50 %) para pausar los despliegues y evitar que la batería se agote por completo. Si está configurado, puedes establecer un umbral de reanudación por batería baja para reiniciar automáticamente los ciclos de grabación cuando el nivel de batería se recupere (por ejemplo, mediante carga solar).
    - **Prueba**: Un ciclo de prueba opcional de un minuto está activado por defecto para verificar la entrada del micrófono y la inferencia inmediatamente después de iniciar, sin contar para el límite de ciclos programados.
    - **Agrupación**: Configura si quieres guardar cada ciclo como una Session separada (recomendado para tiempos de carga más rápidos y visualización modular) o combinar todos los ciclos en una única Session de varios segmentos.
- **Listo**: Revisa el horario, el consumo estimado de almacenamiento de audio y las restricciones diurnas/nocturnas, y luego inicia el despliegue.

Los controles de configuración usan los mismos iconos que los demás asistentes: :app-micRounded: micrófono, :app-speedRounded: tasa de inferencia, :app-verifiedRounded: confianza, :app-hearing: sensibilidad, :app-fiberManualRecordRounded: modo de grabación, :app-timerOutlined: contexto del clip y duración del ciclo, :app-filterAltRounded: muestreo de detecciones y :app-formatListNumberedRounded: límite de clips por especie. El intervalo de repetición usa :app-repeatRounded:, los controles de batería baja :app-batteryAlert: y :app-batteryChargingFull:, y la prueba y la agrupación de Sessions :app-scienceRounded: y :app-libraryBooks:. Toca el botón :app-helpOutline: junto a un control para ver su explicación.

Al iniciar, se guarda inmediatamente una Session `SessionType.aru` con metadatos del horario ARU. Además, los ciclos de grabación se guardan cada 30 segundos, incluidos los ciclos sin detecciones. Tras un cierre inesperado o un corte de energía, el último despliegue parcial aparece en la biblioteca de Sessions como una Session finalizada; la grabación no se reinicia. Puede perderse lo registrado desde el último guardado.

Las exportaciones JSON y ZIP incluyen metadatos del despliegue ARU. Las exportaciones ZIP agrupan los archivos de grabación por ciclo guardados en `aru_cycles/`.

## Pantalla de despliegue activo

La pantalla ARU activa muestra si el despliegue está esperando, grabando o completado. Su diseño usa cuatro pestañas:
- **Estado**: Muestra el estado del despliegue, el temporizador del horario activo y una lista de detecciones en tiempo real.
- **Audio**: Muestra un espectrograma en vivo para verificar la entrada de audio mientras mantiene las detecciones visibles abajo.
- **Horario**: Enumera los próximos 10 horarios de ciclo programados, indicando las alineaciones de amanecer/atardecer si las restricciones diurnas/nocturnas están activas.
- **Resumen**: Resume el tiempo transcurrido, la duración total del audio grabado y las estadísticas de detección.

En Android, los despliegues activos muestran una notificación en primer plano con acciones Detener y Abrir.

Al detener un despliegue se abre la revisión de la Session. Si los ciclos se agruparon en una sola Session, se abre esa Session combinada; si se guardaron como Sessions separadas, se abre la última Session de ciclo completada.

En iOS, esta implementación temprana debe tratarse como un flujo de trabajo en primer plano hasta que el comportamiento de audio/segundo plano programado haya sido validado en iOS.

## Aún planeado

- Validación del comportamiento en segundo plano en iOS.
- Soporte completo de reproducción y espectrograma en la revisión de la Session para grabaciones ARU segmentadas.
