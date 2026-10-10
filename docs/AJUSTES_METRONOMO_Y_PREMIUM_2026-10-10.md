# Metrónomo, lectura y suscripciones — 10 de octubre de 2026

Cambios locales por solicitud del usuario. Sin commit ni publicación en GitHub.

## Cambios

- El péndulo recorre un arco mayor con pulsos lentos y uno menor con pulsos rápidos. Cada desplazamiento entre extremos dura un pulso completo, con aceleración y frenado suaves. Se alargó la varilla y se conserva la preferencia de reducir animaciones.
- La etiqueta muestra únicamente el compás (por ejemplo, `6/8`). La agrupación sigue utilizándose internamente para mantener la duración de los pulsos.
- Todas las partituras mantienen encendida la pantalla, tengan o no audio. El bloqueo se libera al cerrar el visor o pasar a segundo plano y se recupera al regresar. Las operaciones se serializan y comparten referencias para evitar que el cambio de idioma desactive el bloqueo de la nueva partitura.
- Cada plan es un botón que solicita directamente la compra mediante el controlador existente de RevenueCat y la tienda. Se eliminó la selección previa y el botón «Continuar». Se mantienen precios, periodos, condiciones de ofertas, restauración y cierre.
- El anual aparece destacado como «Mejor plan» / «Best plan», sin introducir un porcentaje de ahorro sin verificar.
- Los dos enlaces legales están en columnas adyacentes. Cada texto puede ocupar varias líneas para respetar el tamaño de texto del usuario.
- Una compra pendiente bloquea ambos planes y restaurar; la cancelación vuelve a habilitar las acciones.

## Verificación

- Suite principal: 76 pruebas aprobadas, incluyendo compra directa en español e inglés, enlaces legales adyacentes en 320 px con texto al 200 %, bloqueo de compras repetidas, cancelación, foco del teclado, temas, controles compactos y cierre mediante gesto.
- Suite del reproductor ampliada: 9 pruebas aprobadas (8 ya incluidas en la suite principal). La prueba adicional comprueba que el péndulo cruza el centro a mitad del pulso y llega al otro extremo, y que se muestra `6/8` sin `3+3`. Total: 77 pruebas distintas.
- Pruebas de pantalla encendida: apertura, sustitución de un visor por otro, segundo plano, retorno y cierre del último visor, con una implementación de plataforma simulada.
- Análisis dirigido de componentes nuevos y pruebas: sin incidencias. El archivo del visor conserva avisos informativos previos de `withOpacity`; no se detectaron errores ni advertencias.
- Compilación Android de depuración: completada correctamente, con el nuevo complemento nativo incluido (`build/app/outputs/flutter-apk/app-debug.apk`). Kotlin registró conflictos de caché incremental entre las unidades C: y E: y compiló mediante su alternativa. No se modificó la configuración del proyecto para resolver ese comportamiento local.
- Dependencia: `wakelock_plus` 1.4.0, con su interfaz como dependencia de pruebas. Se comprobó la API en la [documentación del paquete](https://pub.dev/packages/wakelock_plus/versions/1.4.0).

Registros: `output/accessibility/metronome-premium-wakelock-2026-10-10.log`, `metronome-swing-widget-2026-10-10.log` y `metronome-premium-wakelock-targeted-analysis-2026-10-10.log`.
La compilación queda registrada en `output/accessibility/metronome-wakelock-android-build-2026-10-10.log`.

## Alcance de la validación

Las pruebas no realizan compras reales. La presentación de la hoja de compra nativa y la prevención del apagado de pantalla necesitan una comprobación en dispositivo. iOS requiere compilar en macOS y resolver los nuevos plugins con Flutter/CocoaPods. Esta sesión no afirma una validación física de iOS.
