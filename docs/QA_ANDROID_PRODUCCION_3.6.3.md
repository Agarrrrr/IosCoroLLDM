# Preparación Android 3.6.3 (51)

Fecha: 1 de noviembre de 2026.

## Correcciones incluidas

- Servicio multimedia: promoción inmediata a foreground, notificación válida, deduplicación de arranques, parada pendiente atendida después de la promoción y eliminación de reinicios sticky sin reproductor.
- Voces: una descarga progresiva alimenta el reproductor y publica el archivo offline al completarse. Las conexiones interrumpidas no publican pistas parciales.
- Edge-to-edge: `WindowCompat.enableEdgeToEdge(window)` mediante AndroidX Core 1.17.0, manteniendo los insets de Flutter.
- Catálogo: se ocultan temporalmente minirreproductor y banner durante la búsqueda con teclado; abrir el menú retira el foco del campo.
- Menú: en ventanas cortas o con texto ampliado se desplaza el conjunto completo, permitiendo alcanzar Ajustes y Premium.
- Cola del reproductor: las filas usan su propio Material para que el fondo no tape la respuesta visual al tocar.

## Optimización DEX

Medición del `BUNDLE-METADATA/com.android.tools/r8.json` del AAB, no estimación por tamaño.

| Métrica | AAB anterior | AAB con corrección |
| --- | ---: | ---: |
| Optimización | 13.32% | 54.67% |
| Ofuscación | 13.71% | 55.70% |
| Shrinking | 13.52% | 55.71% |
| DEX sin comprimir | 12,599,744 bytes | 9,176,204 bytes |

Se conserva el par de SDKs de anuncios compatible con el plugin actual. La transformación Gradle elimina únicamente `-keep class com.google.android.gms.** { *; }` del consumer de Liftoff 7.6.1. Se comprobaron los 14 archivos del AAR: solo cambió `proguard.txt`; el resto es idéntico por SHA-256. Las demás reglas de los SDKs y las protecciones JNI permanecen activas. La transformación trabaja sobre un artefacto derivado, sin modificar el SDK instalado ni la caché original.

También está activo el shrinking optimizado de recursos. `tools/check_android_optimization.ps1` comprueba las tres métricas y falla si alguna queda por debajo del 25%.

## QA completado

- 69 pruebas automatizadas aprobadas: accesibilidad (incluido texto al 200%), catálogo, gestos de cierre, reproducción vocal y caché progresiva.
- Samsung A55 SM-A556E, Android 16/API 36, navegación de tres botones: 28 escenarios físicos aprobados con capturas y 411 comprobaciones de controles respecto a los insets reales.
- Matriz física: catálogo, teclado real, menú lateral, ajustes, reproductor, controles del reproductor y visor, en claro y oscuro, vertical y horizontal.
- Se verificó la presencia real del teclado: 358.4 dp en vertical y 208.36 dp en horizontal. Los desbordamientos de 14 dp del catálogo y 61 dp del menú encontrados en la primera pasada quedaron corregidos.
- Capturas y reportes: `output/qa_android16_2026_11_01/threebutton_approved/edge_qa/`.
- Registro de pruebas automatizadas: `output/qa_android16_2026_11_01/unit_tests_pass.log`.
- Registro de la pasada física aprobada: `output/qa_android16_2026_11_01/device_layout_threebutton_verified.log`.

## QA del release optimizado

Samsung S20 SM-G986U, Android 13. APK compilado en modo release con R8 y firma de QA para conservar los datos de `com.lldm.coro.perfaudit`.

- Seis comprobaciones técnicas aprobadas: render nativo de PDF, SoundFont/nota MIDI por JNI, MP3 progresivo incompleto, voz real con seek/offline y servicio, inicialización de anuncios con carga de banner de prueba, e inicialización nativa de RevenueCat.
- El audio avanzó 1.829 segundos mientras la segunda mitad de la descarga permanecía bloqueada. Se hizo una sola solicitud al origen.
- La voz real inició en 763 ms. La reproducción continuó al enviar la app al inicio; se observó el ciclo de vida en segundo plano y Android confirmó `isForeground=true`, notificación 7742.
- Se ejecutaron 30 ciclos rápidos de inicio/parada. No se observaron crashes de la app ni un servicio de reproducción residual al finalizar.
- El banner de prueba cargó con el código Google Mobile Ads optimizado. El adaptador Liftoff siguió registrado.
- RevenueCat quedó configurado, pero Play no devolvió los productos para el paquete de QA (`ConfigurationError`, código 23). Esto no valida ofertas, compra ni restauración de una transacción; ese chequeo requiere la instalación de Play y una cuenta habilitada para la aplicación real.

Evidencia: `output/qa_android16_2026_11_01/release_smoke.json` y `release_foreground_service.txt`.

## Artefacto de publicación

- `build/app/outputs/bundle/release/app-release.aab`.
- Paquete verificado: `com.lldm.coro`; versión `3.6.3`; código `51`; target SDK `36`.
- Validación estructural con bundletool aprobada y firma JAR verificada.
- El mapping de R8 está incluido dentro del AAB para desofuscar los futuros reportes de Play.
- Métricas DEX finales verificadas mediante `tools/check_android_optimization.ps1`.
- Identidad, hash SHA-256, firma y mapping se conservaron en `output/qa_android16_2026_11_01/production_*`.
- Se dejó la app funcional 3.6.3 (51) instalada y abierta en el S20, en la variante de QA y conservando sus datos. Se comprobó el arranque sin errores de Flutter ni del servicio y se guardó una captura completa en `final_app_android13.png`.

## Alcance y entrega

El A55 fue prestado y se desconectó al terminar la pasada aprobada. La ampliación a navegación por gestos queda pendiente por indicación del usuario; no se cambió su modo de navegación. Para evitar el bloqueo durante QA se activó temporalmente mantener la pantalla encendida al cargar. Al retirarse el dispositivo no fue posible restaurar ese ajuste (valor original: 0; se puede desactivar en las opciones de desarrollador).

No se han hecho compras ni publicado una actualización en Google Play. La confirmación de que disminuyeron los crashes de usuarios reales requiere observar Android vitals tras distribuir la actualización. El stack suministrado identifica el timeout de foreground service; no permite demostrar qué ruta concreta causó cada evento anterior.

Referencias: [métricas DEX de Android vitals](https://developer.android.com/google/play/vitals/code-optimization), [edge-to-edge e insets](https://developer.android.com/develop/ui/views/layout/edge-to-edge), [recomendaciones para reglas R8](https://developer.android.com/blog/posts/configure-and-troubleshoot-r8-keep-rules).
