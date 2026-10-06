# Modo Point Count

El Modo Point Count es el flujo de trabajo estacionario y cronometrado de BirdNET Live.

## Cómo abrirlo

Desde Inicio, toca la tarjeta **Modo Point Count** con el icono :app-locationOnRounded:.

## Flujo de configuración

La configuración del Point Count consta de cuatro pasos.

### 1. Duración y ubicación

Elige:

- una de las duraciones disponibles: 3, 5, 10, 15, 20, 25 o 30 minutos
- si el conteo continúa con la pantalla apagada (activado de forma predeterminada)
- GPS actual con :app-myLocation:
- coordenadas manuales con :app-editLocationAlt:
- sin ubicación con :app-locationOff:
- selector de mapa con :app-mapSheet:

La pantalla de configuración actualiza el GPS cuando vuelves del diálogo de permisos del sistema o de los ajustes de la app, de modo que un permiso de ubicación recién concedido debería actualizar las coordenadas sin reiniciar el asistente. Esta misma sección incluye también una tarjeta de clima. Si el acceso al clima está desactivado, la tarjeta solicita el consentimiento de **Permitir consulta del clima**; una vez activado, muestra una vista previa del sitio solo con un icono del tiempo, la temperatura y el viento. La misma instantánea en caché de Open-Meteo se reutiliza al guardar el Point Count.

### 2. Parámetros de inferencia

Elige los ajustes de análisis para esta Session, como la tasa de inferencia, el umbral de confianza y el modo del filtro de especies. Parten de tus ajustes globales, pero puedes adaptarlos a este conteo sin cambiar tus valores predeterminados.

| Control de configuración | Icono |
|---|---|
| Micrófono | :app-micRounded: |
| Modo de grabación | :app-fiberManualRecordRounded: |
| Contexto del clip | :app-timerOutlined: |
| Tasa de inferencia | :app-speedRounded: |
| Umbral de confianza | :app-verifiedRounded: |
| Sensibilidad | :app-hearing: |
| Filtro de especies | :app-filterAltRounded: |

El botón :app-helpOutline: junto a cada control explica su efecto. El control de duración :app-timerRounded: y el selector de ubicación tienen el mismo botón de ayuda en el primer paso.

Elige **Completa** para guardar audio continuo (predeterminado), **Solo clips** para guardar un fragmento de cada vocalización detectada o **Desactivada** para no guardar audio. Esta elección es independiente del ajuste de grabación de Live Mode y se recuerda para el siguiente Point Count. Los fragmentos usan la misma selección de ventana con mayor puntuación y el mismo contexto que Live Mode, sin reducción por ubicación. Con **Solo clips**, el control **Contexto del clip** determina los segundos conservados antes y después de cada ventana analizada; también actualiza el contexto de Live Mode.

### 3. Consejos de campo

Esta pantalla presenta una breve lista de comprobación dentro de la app para repasar antes de empezar.

### 4. Listo

La pantalla de listo resume la duración, la opción de grabación y el comportamiento con la pantalla apagada. Empieza con :app-playArrowRounded:.

## Pantalla del Point Count en vivo

La pantalla del Point Count en vivo se centra en un panel cronometrado.

### Barra superior

- :app-stopRounded: — finaliza el Point Count anticipadamente
- :app-timerRounded: — muestra el tiempo restante
- :app-helpOutlineRounded: — abre la ayuda de Point Count
- :app-tuneRounded: — abre los ajustes de Point Count

### Indicadores principales

- barra de progreso de cuenta atrás
- barra de información compacta con las detecciones actuales, el número de especies únicas y las detecciones totales
- vista del espectrograma
- lista de detecciones

## Después del conteo

Con **Continuar con la pantalla apagada** activado en la configuración de Point Count, el conteo continúa al bloquear la pantalla o cambiar de aplicación, incluso si la pantalla sigue encendida. Termina tras la duración elegida; la cuenta atrás usa el tiempo realmente transcurrido, por lo que una pantalla suspendida no alarga el conteo. Android muestra una notificación persistente con Abrir y Detener. Desactiva el interruptor para que estas acciones terminen el conteo antes. Point Count no se pausa y reanuda porque interrumpiría el conteo cronometrado. Si sales de la aplicación mientras se inicia, se cancela con un mensaje; vuelve a configurarlo. En Windows, minimizar la ventana no termina el conteo.

Al terminar el Point Count, BirdNET Live abre [Resumen de la Session](session-review.md). Si el guardado automático está activado, guarda la Session automáticamente; de lo contrario, guárdala desde el resumen si quieres conservarla.

Con el guardado automático activado, un conteo sin terminar también se guarda al inicio, cada 30 segundos y cuando la aplicación deja el primer plano. Tras un cierre inesperado o un corte de energía, el último conteo parcial está disponible en la Biblioteca de sesiones.
