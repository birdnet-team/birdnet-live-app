# Subidas

Las subidas envían las sesiones terminadas desde muchos teléfonos a una única carpeta de proyecto. Quien dirige el proyecto configura una carpeta una sola vez y reparte un enlace o un código QR; cada colaborador lo pega o lo escanea y, a partir de entonces, cualquier sesión puede enviarse a esa carpeta con dos toques desde el diálogo de Compartir. Los despliegues ARU pueden enviar por sí solos cada sesión terminada.

Las subidas van en un solo sentido. La app escribe archivos en la carpeta del proyecto y nunca lee, lista ni borra nada allí. Borrar una sesión en tu teléfono deja intacta la copia subida, y nunca se sube nada salvo que hayas marcado un destino o activado las subidas automáticas de ARU.

## Cómo funciona

Un **destino** es una carpeta WebDAV en la que la app puede escribir. Tres tipos funcionan sin más configuración:

- un recurso compartido **File Drop de Nextcloud**, la opción recomendada para la mayoría de los proyectos;
- cualquier **dirección WebDAV** con nombre de usuario y contraseña, por ejemplo una carpeta de tu propia cuenta en la nube o un servidor institucional;
- el **servidor de depósito de referencia** que acompaña a BirdNET Live, para responsables que quieran tokens por colaborador y una exportación CSV ya preparada (consulta la [Guía para desarrolladores](../developer/upload-drop-server.md)).

Cada subida es **un archivo ZIP por sesión**, con el mismo nombre que la exportación de Compartir, por ejemplo `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Siempre contiene el registro JSON de la sesión y, según lo que marques, el audio, las tablas de detecciones, el informe HTML y el archivo de metadatos de la app. El ZIP aterriza en una carpeta cuyo nombre es tu **ID de subida**, un código de ocho caracteres que la app deriva de una identidad aleatoria que conserva para esta instalación. La carpeta de quien dirige el proyecto tiene, por tanto, este aspecto:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

La carpeta `.birdnet-live` contiene un pequeño archivo de registro por dispositivo, escrito por la prueba de conexión. Nextcloud la oculta salvo que «Mostrar archivos ocultos» esté activado. Contiene el ID de subida, la versión de la app, la plataforma y el **identificador de participante** opcional (un nombre, un correo o un número de participante) que haya introducido el colaborador, de modo que quien dirige el proyecto pueda saber quién está detrás de cada código sin que ningún nombre llegue a convertirse en nombre de carpeta. El mismo identificador se escribe en el registro JSON de cada sesión subida.

## Para quien dirige el proyecto

### Opción A: un File Drop de Nextcloud

1. En Nextcloud, crea una carpeta para el proyecto, por ejemplo `Spring Survey 2027`.
2. Abre su panel de compartir, crea un **enlace compartido** y establece sus permisos en **File Drop (solo subida)**. Así los colaboradores pueden añadir archivos pero nunca ven lo que han enviado los demás.
3. Pon una **contraseña** al enlace. Sin ella, cualquiera que encuentre el enlace puede subir a la carpeta. Un File Drop no puede leerse ni siquiera entonces, así que la ausencia de contraseña es una decisión que la app acepta sin protestar.
4. Opcionalmente, fija una fecha de caducidad para el final del proyecto.
5. Copia el enlace compartido. Tiene un aspecto como `https://cloud.example.org/s/AbCdEf123456`.

La app convierte ese enlace por sí misma en el punto de acceso WebDAV del recurso compartido; los colaboradores nunca ven una dirección WebDAV. Un File Drop nunca sobrescribe: cuando un colaborador sube de nuevo la misma sesión, Nextcloud conserva la copia anterior con un nombre numerado, de modo que el archivo más reciente es el que no lleva número.

Los recursos compartidos de Nextcloud con permiso de **subir y editar** también funcionan, pero la app avisará a los colaboradores de que la credencial puede listar la carpeta, porque cualquiera con el enlace puede entonces leer los datos de todos los demás. Los recursos compartidos de solo lectura son rechazados por la prueba de conexión.

### Opción B: tu propia carpeta WebDAV

Sirve cualquier servidor WebDAV: una carpeta en una cuenta personal en la nube, un servidor de archivos institucional, ownCloud o Nextcloud con una cuenta normal. Los colaboradores introducen la dirección más un nombre de usuario y una contraseña en **Avanzado** al unirse. Para una cuenta de Nextcloud u ownCloud usa una **contraseña de aplicación** de los ajustes de seguridad de la cuenta, nunca la contraseña de inicio de sesión; cuando solo se indica un nombre de host, la app prueba también las ubicaciones habituales de Nextcloud y ownCloud en ese host.

Una credencial así normalmente puede leer la carpeta, por lo que la prueba de conexión muestra una advertencia. Prefiere una configuración de solo escritura cuando los colaboradores no sean todos de un mismo equipo.

### Opción C: el servidor de depósito de referencia

`tools/webdav_drop_server`, en el repositorio del código fuente, es un pequeño servidor en Python con tokens por colaborador que puedes revocar, un comando `collect` que fusiona cada registro JSON subido en `sessions.csv`, `detections.csv` y `species_summary.csv`, y un comando `invite` que imprime un enlace de acceso y un código QR. La instalación y el despliegue se describen en la [Guía para desarrolladores](../developer/upload-drop-server.md).

### Crear el enlace de acceso y el código QR

Un enlace de acceso reúne en una sola pieza todo lo que necesita un colaborador: el destino, la credencial, un nombre de proyecto y los valores predeterminados que sugieres. Abre la [página de acceso](../join.md) de este sitio y rellena:

- **Share link or WebDAV address**: el enlace compartido de Nextcloud de arriba, o la dirección de la carpeta WebDAV.
- **User name**: déjalo vacío para un enlace compartido de Nextcloud.
- **Share password or token**: la contraseña del recurso compartido, o el secreto de la cuenta o del token.
- **Project name shown in the app**: lo que los colaboradores verán como nombre del destino. Pueden renombrarlo, pero este es el valor predeterminado.
- **Suggest including audio** y **Suggest Wi-Fi only**: los valores predeterminados de los interruptores del destino.

Pulsa **Build link and QR code**. Todo ocurre en tu navegador; no se envía nada a ningún sitio. El secreto va en la parte del enlace posterior a `#`, que los navegadores nunca transmiten al servidor web que aloja la página.

Como alternativa, únete primero al destino desde tu propio teléfono (ver más abajo), abre después el destino en **Ajustes → Exportación y sincronización → Destinos de subida** y toca **Mostrar código de acceso**. La app muestra el mismo tipo de código QR con un botón **Copiar enlace**.

### Repartirlo

Imprime el código QR en la hoja de campo, muéstralo en una pantalla durante la reunión previa o envía el enlace por mensaje. **Trata el enlace y el código como una contraseña**: cualquiera que lo tenga puede subir a tu proyecto. Si se filtra, cambia la contraseña del recurso compartido o revoca el token y reparte un código nuevo.

Cuando un colaborador escanea el código con la cámara de su teléfono, el navegador abre una pequeña página de bienvenida con un botón **Open in BirdNET Live**, que lleva a la pantalla Añadir destino de la app con el enlace ya rellenado. Pegar el enlace directamente en esa pantalla funciona exactamente igual.

### Qué verás

Una carpeta por dispositivo, un ZIP por sesión y los registros ocultos de `.birdnet-live`. Abre un ZIP para encontrar el registro JSON (siempre presente) y las tablas, el informe y el audio que el colaborador haya decidido incluir. Para saber qué persona está detrás de un ID de subida, lee el archivo de registro de ese código o el campo `meta.participant` dentro de cualquiera de sus registros JSON. Con el servidor de depósito de referencia, `collect` lo hace por ti y escribe una columna `participant`.

## Para colaboradores

### Unirse a un destino

1. Abre **Ajustes → Exportación y sincronización → Destinos de subida** y toca **Añadir destino**. Escanear el código QR de un proyecto con la cámara, o tocar un enlace de acceso que hayas recibido, te lleva a la misma pantalla con el enlace ya rellenado.
2. Pega el enlace de acceso, el enlace compartido de Nextcloud o una dirección WebDAV en **Enlace de acceso o dirección del servidor**. El botón **Pegar** lo toma del portapapeles.
3. Si quieres, rellena **ID de participante, nombre o correo (opcional)**. Se guarda con cada subida para que quien dirige el proyecto sepa quién la envió, y nunca aparece en los nombres de carpeta. Bajo el campo, la app muestra **Tu ID de subida**, la carpeta en la que aterrizarán tus subidas.
4. Para una dirección WebDAV normal, abre **Avanzado** e introduce el **Nombre de usuario** y la **Contraseña o token**. Un enlace compartido de Nextcloud no necesita ninguno de los dos; si el recurso compartido tiene contraseña, introdúcela como contraseña.
5. Toca **Probar conexión**. La app contacta con el servidor, crea la carpeta de registro oculta, comprueba si la credencial puede listar la carpeta y escribe tu archivo de registro. El resultado es una sola frase: **La conexión funciona**, una advertencia que conviene leer, o un fallo con la solución probable.
6. Dale al destino un **Nombre del destino** (rellenado previamente a partir del enlace de acceso), decide si quieres **Subir solo con Wi-Fi** y toca **Guardar destino**.

No se guarda nada hasta que la prueba se ha superado. La credencial va al llavero del dispositivo, nunca a los datos exportados.

Advertencias que conviene entender:

- **Esta credencial puede listar el destino** significa que el recurso compartido o la cuenta puede leer los datos de otros colaboradores. Las subidas funcionan, pero pide a quien dirige el proyecto un File Drop o un token de solo escritura si en el proyecto participan personas ajenas a tu equipo.
- **Este enlace compartido no tiene contraseña y permite listar el contenido** combina los dos riesgos: cualquiera con el enlace puede leerlo todo. Pide a quien dirige el proyecto que ponga una contraseña o use un File Drop.
- **Este servidor no permite carpetas** es informativo: las subidas usan nombres de archivo planos como `4ee91c8f__BirdNET_Live_….zip` en lugar de una carpeta.

### La pantalla del destino

Tocar un destino de la lista abre su pantalla con la dirección del servidor, cuándo se añadió y cuándo se usó por última vez, y estos controles:

- **Renombrar** (el lápiz de la barra de la app) cambia el nombre que se muestra en la app.
- **Subir solo con Wi-Fi** retiene las subidas mientras el teléfono usa datos móviles.
- **Subir las Sessions ARU automáticamente** pone en cola cada ARU Session terminada para este destino sin preguntar (ver más abajo).
- **Probar conexión** repite la prueba de conexión, por ejemplo después de que quien dirige el proyecto haya cambiado la contraseña.
- **Mostrar código de acceso** muestra un código QR junto con **Copiar enlace** para que un segundo teléfono pueda unirse al mismo destino.
- **Quitar destino** olvida el destino y su credencial y descarta las subidas pendientes hacia él. Las sesiones ya subidas permanecen en el servidor.

La primera entrada de la lista de destinos es **Tu ID de subida**, con el identificador de participante debajo; tócala para cambiar el identificador. Cambiarlo no mueve nada en el servidor, ya que las carpetas se nombran por el ID.

### Subir una sesión

Las subidas parten de la misma acción **Compartir** que ya usas, en tres lugares:

- el **menú de tres puntos** (:app-moreVert:) de una tarjeta de sesión en la Biblioteca de sesiones;
- el botón **Compartir** tras seleccionar varias sesiones en la Biblioteca de sesiones;
- el icono **Compartir** (:app-share:) de la barra de herramientas del Resumen de la Session.

El diálogo de Compartir tiene dos pestañas en cuanto existe al menos un destino:

- **Contenido** elige qué contiene la exportación: **Audio** (la grabación completa, o los clips de detección cuando solo se conservaron clips) y **Metadatos** (las tablas, el informe y el archivo de metadatos de la app activados en Exportación y sincronización). Las casillas empiezan coincidiendo con tus ajustes y se aplican solo a esta compartición.
- **Enviar a** lista **Hoja de compartir** (otras apps, archivos, mensajes) y una casilla por destino. La insignia de la pestaña cuenta los destinos marcados. Los destinos marcados la última vez vienen premarcados, excepto aquellos a los que ya fue esta sesión: empiezan desmarcados y muestran **Subido el** con la fecha y **Marca para subir de nuevo**. Al abrirse el diálogo, la app comprueba discretamente cada destino; si el servidor indica que rechazaría la subida, por ejemplo porque la contraseña cambió o el recurso compartido se eliminó, la fila se pone en rojo con el motivo.

Desmarca **Hoja de compartir** y el botón pasa a decir **Subir**; con ambas marcadas dice **Compartir y subir**. Un snackbar confirma cuántas sesiones se han puesto en cola. Una sesión siempre entra primero en la cola y se sube en segundo plano, así que puedes seguir trabajando.

### Seguir una subida

La tarjeta de sesión de la Biblioteca de sesiones muestra el estado como primera línea bajo el título de la sesión: **En cola**, **Esperando Wi-Fi**, **Esperando una red**, **Subiendo…**, **Subido el** con la fecha, o un fallo. Toca la línea para ver la lista por destino con **Reintentar ahora** y **Quitar de la cola**. El Resumen de la Session muestra el mismo estado como un icono de nube en la barra de la app; tocarlo abre la misma lista.

Las subidas fallidas se reintentan por sí solas con esperas crecientes, de hasta seis horas entre intentos, durante un máximo de treinta intentos. **Falló, se reintentará** significa que la app volverá a intentarlo. **La subida falló. Revisa los ajustes del destino.** significa que el servidor la rechazó y que un reintento no puede ayudar: la contraseña cambió, las subidas se desactivaron o el destino se eliminó. Abre el destino, ejecuta **Probar conexión** y quítalo y añádelo de nuevo si la credencial cambió.

La línea y el icono solo aparecen mientras al menos uno de los destinos a los que se envió la sesión sigue existiendo en Ajustes. Quita el destino y desaparecen, porque «subido» ya no es un hecho relativo a ningún destino que tengas.

### Qué se ejecuta en segundo plano

Las subidas en cola se ejecutan mientras la app está abierta y cada vez que vuelve al primer plano. En Android también se ejecutan con la app cerrada: el sistema las inicia en cuanto hay disponible una red adecuada, Wi-Fi cuando el destino lo exige, y sigue reintentando hasta que la cola queda vacía. En iOS las subidas se ejecutan mientras la app está abierta.

### Subir una sesión de nuevo

Subir de nuevo la misma sesión, por ejemplo después de corregir detecciones en el Resumen de la Session, escribe el mismo nombre de archivo en la misma carpeta. Los servidores que lo permiten sustituyen el archivo; un File Drop de Nextcloud conserva en cambio la copia anterior con un nombre numerado. En ambos casos quien dirige el proyecto recibe la versión más reciente y no se borra nada.

## Modo ARU

Los despliegues de campo producen muchas sesiones, a menudo cuando no hay nadie junto al teléfono. Activa **Subir las Sessions ARU automáticamente** en un destino y cada ARU Session terminada se pondrá en cola para él sin ningún diálogo, usando los valores predeterminados de Exportación y sincronización para Audio y Metadatos. Un despliegue que guarda cada ciclo como sesión propia sube ciclo a ciclo; la sesión combinada del despliegue no se sube dos veces.

Deja **Subir solo con Wi-Fi** activado en una estación con tarifa de datos móviles salvo que la tarifa pueda asumir el audio, y considera grabar en **Solo detecciones** o **Desactivado** cuando el audio sea demasiado grande para enviarlo. Las subidas salen entonces cada vez que el teléfono ve una red adecuada, también mientras la app está en segundo plano en Android.

## Dos ejemplos prácticos

### Un Survey de fin de semana con un File Drop de Nextcloud

Quien dirige el proyecto crea una carpeta `Birdathon 2027` en el Nextcloud de la universidad, la comparte como File Drop con contraseña, pega el enlace compartido y la contraseña en la página de acceso, da nombre al proyecto e imprime el código QR en la hoja de la reunión previa. Veinte voluntarios lo escanean el sábado por la mañana, introducen su nombre como identificador de participante, superan la prueba de conexión y guardan.

El domingo por la tarde cada voluntario abre la Biblioteca de sesiones, selecciona las sesiones del fin de semana, toca Compartir, deja el proyecto marcado en Enviar a y toca **Subir**. Las subidas esperan al Wi-Fi de casa y terminan durante la noche. El lunes, quien dirige el proyecto encuentra veinte carpetas nombradas por ID de subida, cada una con un puñado de ZIP, y lee los nombres de los voluntarios en los archivos de registro ocultos o en el campo `meta.participant` dentro de los registros JSON.

### Correcciones en el Resumen de la Session y, después, una estación ARU

Un colaborador revisa una sesión, elimina dos detecciones falsas, añade una especie a mano y guarda. El icono de nube de la barra de la app del Resumen de la Session muestra que la sesión se subió el sábado. Toca el icono Compartir de la barra de herramientas, marca el proyecto en Enviar a, donde empieza desmarcado y dice **Subido el** con la fecha, y pulsa **Subir**. El ZIP corregido sustituye al anterior, o aterriza junto a él con un nombre numerado en un File Drop.

El mismo colaborador deja un teléfono como estación ARU en un carrizal con un punto de acceso Wi-Fi en la caseta. Se une al destino del proyecto en ese teléfono, activa **Subir las Sessions ARU automáticamente** y mantiene activado **Subir solo con Wi-Fi**. Cada mañana los ciclos nocturnos terminados se ponen en cola y se suben mientras la estación está inactiva; quien dirige el proyecto ve aparecer nuevos ZIP bajo el ID de subida de ese teléfono sin que nadie lo toque.

## Privacidad y responsabilidad

Los destinos de subida los gestionan los organizadores de los proyectos, no el equipo de BirdNET. La carpeta, el servidor, quién puede leerlo y cuánto tiempo se conservan los datos se rigen por las propias normas de privacidad y seguridad del organizador; pídele detalles antes de unirte. BirdNET Live solo escribe lo que decidiste enviar y guarda la credencial en el llavero de tu dispositivo.

Una subida contiene lo que contendría una compartición: el registro JSON de la sesión con las detecciones, las horas, las coordenadas, el nombre del observador y el nombre del lugar si se indicaron, el ID de subida del dispositivo, el identificador de participante que introdujiste y la versión de la app; más el audio, las tablas y el informe que marcaste. Revisa la pestaña Contenido antes de enviar, y deja fuera el audio cuando una grabación pueda contener voces o cualquier otra cosa que no entregarías al proyecto. **Eres responsable de lo que subes.** No subas ni compartas datos que consideres privados o confidenciales, y no subas grabaciones que no tengas permiso para transmitir.

## Resolución de problemas

| Mensaje | Qué significa | Qué hacer |
| --- | --- | --- |
| Esto no parece un enlace ni una dirección de servidor. | El texto no es una URL. | Pega el enlace de acceso completo, el enlace compartido o la dirección `https://`. |
| El servidor rechazó las credenciales. | Contraseña incorrecta o ausente, o recurso compartido eliminado. Nextcloud responde así también para los recursos compartidos borrados. | Usa la contraseña del enlace compartido o una contraseña de aplicación; pregunta a quien dirige el proyecto si el recurso compartido sigue existiendo. |
| Esta dirección no es un punto de acceso WebDAV. | Pegaste la página web de una carpeta, no un enlace compartido ni una dirección WebDAV. | Pega el enlace compartido (`…/s/…`) o la dirección WebDAV. |
| Aquí no se permiten subidas. | El recurso compartido es de solo lectura. | Pide a quien dirige el proyecto un File Drop o permiso de subida. |
| La carpeta no existe en el servidor. | La dirección no apunta a nada, o la carpeta se borró. | Comprueba la dirección con quien dirige el proyecto. |
| No se pudo verificar el certificado del servidor. | TLS autofirmado o defectuoso. | Pide a quien dirige el proyecto una dirección con un certificado válido. |
| Esta dirección usa HTTP sin cifrar. | Conexión sin cifrar fuera de tu red local. | Usa una dirección `https://`. |
| Esperando Wi-Fi | El destino está configurado como solo Wi-Fi y el teléfono usa datos móviles. | Espera, o desactiva el interruptor de solo Wi-Fi del destino. |
| Falló, se reintentará | Un problema temporal, como una conexión interrumpida o un error del servidor. | Nada; la app reintenta por sí sola. **Reintentar ahora** fuerza un intento. |
| La subida falló. Revisa los ajustes del destino. | El servidor la rechazó por un motivo que un reintento no puede arreglar. | Abre el destino, ejecuta **Probar conexión** y quítalo y añádelo de nuevo si la credencial cambió. |
| La credencial de este destino no está en el llavero del dispositivo. | La entrada del llavero se perdió, por ejemplo tras restaurar en un teléfono nuevo. | Quita el destino y añádelo de nuevo. |

Consulta también el ajuste [Destinos de subida](settings.md#destinos-de-subida) y las guías de la [Biblioteca de sesiones](session-library.md) y del [Resumen de la Session](session-review.md).
