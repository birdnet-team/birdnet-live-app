# Modo ARU

!!! note "Implementación temprana"
    El modo ARU actualmente guarda puntos de control del despliegue programado, graba ciclos programados, ejecuta inferencia en vivo durante los ciclos activos, guarda clips de detección retenidos cuando se selecciona ese modo de grabación y muestra controles de notificación en primer plano en Android. El comportamiento en segundo plano en iOS aún necesita validación de campo.

El modo ARU (Autonomous Recording Unit) es el flujo de trabajo para despliegues acústicos programados en una ubicación fija.

## Flujo de configuración actual

- **Detalles y ajustes de análisis**:
    - **Metadatos**: Introduzca un nombre de despliegue, ID de ARU/estación y nombre del observador.
    - **Ubicación**: Proporcione las coordenadas del sitio usando la adquisición automática de GPS, la entrada manual de latitud/longitud o salte la configuración de ubicación. La latitud y la longitud son requeridas si se utiliza la programación vinculada al sol. Iconos: GPS :app-myLocation:, coordenadas manuales :app-editLocationAlt:, omitir ubicación :app-locationOff: y selector de mapa :app-mapSheet:.
    - **Análisis**: Elige el micrófono, la tasa de inferencia, el umbral de confianza y la sensibilidad.
    - **Formato de grabación**: Elija entre los formatos FLAC (comprimido sin pérdidas) y WAV (sin comprimir).
    - **Modo de grabación**:
        - *Completo*: Graba la duración total de cada ciclo activo.
        - *Solo detecciones*: Guarda clips de audio cortos alrededor de los cantos de aves detectados. Puede personalizar el contexto del clip (añadiendo entre 0 y 5 segundos de búfer de audio antes y después de la detección) y elegir el método de muestreo (*Todas*, *Top N* o muestreo *Smart* para limitar el uso del almacenamiento).
        - *Desactivado*: Ejecuta inferencia en tiempo real durante los ciclos y registra las detecciones, pero no guarda ningún archivo de audio.
- **Horario (Plan)**:
    - **Duración y repetición**: Seleccione cuánto dura cada ciclo de grabación activo y con qué frecuencia se repite.
    - **Ventana de grabación (Patrón diurno/nocturno)**: Elija grabar las 24 horas del día (*En cualquier momento*) o restrinja los ciclos a *Solo día*, *Solo noche* o ventanas específicas *Alrededor del amanecer*, *Alrededor del atardecer* o *Alrededor del amanecer y atardecer*. Las ventanas de amanecer/atardecer se calculan dinámicamente en función de las coordenadas del despliegue.
    - **Fin del horario**: Elija si desea detener el despliegue manualmente, detener después de un número de ciclos completados o detener automáticamente en una fecha y hora específicas.
    - **Gestión de batería**: Establezca un umbral de parada por batería baja (0-50%) para pausar los despliegues y evitar el drenaje completo de la batería. Si está configurado, puede establecer un umbral de reanudación por batería baja para reiniciar automáticamente los ciclos de grabación cuando el nivel de batería se recupere (por ejemplo, mediante carga solar).
    - **Prueba**: Un ciclo de prueba opcional de un minuto está activado por defecto para verificar la entrada del micrófono y la inferencia inmediatamente después de iniciar, sin contar para el límite de ciclos programados.
    - **Agrupación de Sessions**: Configure si desea guardar cada ciclo como una Session separada (recomendado para tiempos de carga más rápidos y visualización modular) o combinar todos los ciclos en una única Session de múltiples segmentos.
- **Listo**: Revise el horario, el consumo estimado de almacenamiento de audio y las restricciones diurnas/nocturnas, luego inicie el despliegue.

Los controles de configuración usan los mismos iconos que los demás asistentes: :app-micRounded: micrófono, :app-speedRounded: tasa de inferencia, :app-verifiedRounded: confianza, :app-hearing: sensibilidad, :app-fiberManualRecordRounded: modo de grabación, :app-timerOutlined: contexto del clip y duración del ciclo, :app-filterAltRounded: muestreo de detecciones y :app-formatListNumberedRounded: límite de clips por especie. El intervalo de repetición usa :app-repeatRounded:, los controles de batería baja :app-batteryAlert: y :app-batteryChargingFull:, y la prueba y la agrupación de Sessions :app-scienceRounded: y :app-libraryBooks:. Toque el botón :app-helpOutline: junto a un control para ver su explicación.

Al iniciar, se guarda inmediatamente una Session `SessionType.aru` con metadatos del horario ARU. Además, los ciclos de grabación se guardan cada 30 segundos, incluidos los ciclos sin detecciones. Tras un cierre inesperado o un corte de energía, el último despliegue parcial aparece en la Biblioteca de sesiones como una Session finalizada; la grabación no se reinicia. Puede perderse lo registrado desde el último guardado.

Las exportaciones JSON y ZIP incluyen metadatos del despliegue ARU. Las exportaciones ZIP agrupan los archivos de grabación por ciclo guardados en `aru_cycles/`.

## Pantalla de despliegue activo

La pantalla ARU activa muestra si el despliegue está esperando, grabando o completado. Su diseño usa cuatro pestañas:
- **Estado**: Muestra el estado del despliegue, el temporizador del horario activo y una lista de detecciones en tiempo real.
- **Audio**: Muestra un espectrograma en vivo para verificar la entrada de audio mientras mantiene las detecciones visibles abajo.
- **Plan**: Enumera los próximos 10 horarios de ciclo programados, indicando las alineaciones de amanecer/atardecer si las restricciones diurnas/nocturnas están activas.
- **Resumen**: Resume el tiempo transcurrido, la duración total del audio grabado y las estadísticas de detección.

En Android, los despliegues activos muestran una notificación en primer plano con acciones Detener y Abrir.

Al detener un despliegue se abre el Resumen de la Session. Si los ciclos se agruparon en una sola Session, se abre esa Session combinada; si se guardaron como Sessions separadas, se abre la última Session de ciclo completada.

En iOS, esta implementación temprana debe tratarse como un flujo de trabajo en primer plano hasta que el comportamiento de audio/segundo plano programado haya sido validado en iOS.

## Aún planeado

- Validación del comportamiento en segundo plano en iOS.
- Soporte completo de reproducción y espectrograma en el Resumen de la Session para grabaciones ARU segmentadas.
