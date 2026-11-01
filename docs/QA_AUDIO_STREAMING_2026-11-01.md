# QA de voces cantadas y servicio Android — 1 de noviembre de 2026

## Cambios

- La fuente vocal remota pasa por un servidor HTTP local, limitado a `127.0.0.1`. Una sola descarga alimenta al reproductor y escribe el archivo offline.
- El reproductor recibe bytes antes de terminar la descarga. Se admiten GET, HEAD y rangos de bytes; un adelanto fuera del contenido descargado espera los bytes necesarios.
- La pista offline se publica mediante rename solo después de completar la transferencia. Cancelaciones, errores HTTP y cortes de red eliminan el archivo parcial y permiten reintentar.
- Detener el reproductor mantiene la descarga en curso. Una reproducción posterior utiliza el archivo local completo.
- El servicio Android llama a `startForeground()` con una notificación mínima antes de crear la sesión multimedia, procesar imágenes o adquirir locks. La notificación usa un icono monocromático propio.
- Se deduplican arranques pendientes y se atiende una parada pendiente después de la promoción. Las actualizaciones de metadatos en pausa no arrancan un servicio nuevo. El servicio deja de ser `START_STICKY`.
- Las imágenes de notificación se reducen y el icono de respaldo se decodifica una sola vez. Los fallos de arranque/promoción se registran en `CoroMediaPlayback`.

## Evidencia

Dispositivo físico: Samsung SM-G986U, Android 13. Variante aislada: `com.lldm.coro.perfaudit`.

- 13 pruebas automatizadas aprobadas: descarga progresiva, rangos y HEAD, parada sin cancelar descarga, cancelación y reintento, archivo borrado, HTTP 503, conexión truncada y regresiones de carga/cambio/parada del reproductor.
- 2 pruebas de integración aprobadas en el teléfono.
- Con la segunda mitad de un MP3 bloqueada, el reproductor avanzó 1.793 segundos; hubo una sola solicitud al origen y el archivo offline aún no existía. Después se completó la descarga y se reprodujo localmente.
- Se ejercitaron 12 ciclos rápidos de arranque/parada del servicio en cada ejecución de la primera prueba.
- Voz real: `es/113. Piedad oh Santo Dios/Piedad oh Santo Dios - Bajo.mp3`, 873047 bytes. Preparación/inicio medidos: 947 ms en esta ejecución. Pasaron pausa, reanudación, seek a 5 segundos y reproducción desde el archivo local.
- El buffer de crashes de Android estaba vacío después de las pruebas; no quedó servicio de reproducción activo.
- El análisis de los archivos modificados y las pruebas no reportó problemas.
- Se compiló, instaló y abrió también la app funcional (`lib/main.dart`) en la variante de pruebas. El APK debug está en `build/app/outputs/flutter-apk/app-debug.apk`.

## Repetir

```powershell
C:/src/flutter/bin/flutter.bat test --no-pub test/progressive_audio_cache_test.dart test/vocal_panel_playback_test.dart test/player_dismiss_test.dart
$env:ORG_GRADLE_PROJECT_performanceAudit='true'
C:/src/flutter/bin/flutter.bat test --no-pub integration_test/vocal_streaming_device_test.dart -d R5CN30027WW
adb logcat -d -b crash -t 200
```

## Alcance

El stack compartido confirma `ForegroundServiceDidNotStartInTimeException`; no incluye una excepción interna específica de la app que demuestre cuál de las rutas anteriores disparó cada evento de Play Console. Los cambios cubren retraso en la promoción y carreras de inicio/parada identificadas en el código.

La validación física cubre Android 13. Android 14–16, otras ROM y la reducción de crashes en producción requieren validación adicional y una actualización publicada. Estas pruebas no demuestran ausencia de todos los crashes posibles. No se publicó una actualización en Google Play ni se cambió el número de versión.

Referencia de plataforma: [Android — Troubleshoot foreground services](https://developer.android.com/develop/background-work/services/fgs/troubleshooting).

Actualización posterior: la validación de interfaz en Android 16, la optimización DEX y las comprobaciones del release 3.6.3 (51) están documentadas en `QA_ANDROID_PRODUCCION_3.6.3.md`.
