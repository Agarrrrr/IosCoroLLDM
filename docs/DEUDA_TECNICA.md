# Informe de deuda técnica — Coro LLDM

**Fecha del diagnóstico:** 1 de septiembre de 2026  
**Alcance:** aplicación Flutter, integraciones nativas Android/iOS, recursos offline, pruebas y CI/CD.  
**Estado del documento:** fotografía del repositorio local; incluye los cambios de audio y exportación presentes en el árbol de trabajo al momento del análisis.

## Resumen ejecutivo

La aplicación tiene una base funcional sólida: usa un catálogo offline-first, valida PDF/MIDI antes de persistirlos, mueve trabajo criptográfico pesado a un isolate y selecciona explícitamente el preset de piano. Sin embargo, la velocidad de evolución está elevando el riesgo en cinco áreas:

1. **Arquitectura concentrada:** `visor_screen.dart` acumula UI, reproducción, anotaciones, monetización, exportación y compartición en 2,897 líneas.
2. **Audio difícil de verificar:** el reproductor combina un singleton Dart, `flutter_midi_pro`, `audioplayers` y puentes nativos propios. La recuperación Bluetooth ya está reforzada, pero no tiene pruebas automatizadas de integración.
3. **Distribución pesada:** se empaquetan aproximadamente 360 MB y 2,078 archivos offline dentro de la aplicación, además del mecanismo de descarga bajo demanda.
4. **Cobertura insuficiente:** hay 4 archivos de prueba y 13 declaraciones de prueba para 28 archivos y unas 9,770 líneas de producción. Faltan pruebas de los flujos que más fallan en dispositivos reales.
5. **Seguridad mal delimitada:** la clave AES usada para descifrar recursos está dentro del binario. Esto sirve como ofuscación, pero no puede garantizar confidencialidad frente a un atacante que inspeccione la aplicación.

La recomendación es abordar primero observabilidad, audio/exportación y seguridad; después dividir el visor y reducir el tamaño de la instalación. No se recomienda una reescritura completa.

## Indicadores de la fotografía actual

| Indicador | Resultado | Lectura |
|---|---:|---|
| Archivos Dart de producción | 28 | Código todavía manejable, pero muy concentrado |
| Líneas Dart de producción | ~9,770 | El visor representa cerca del 30 % |
| Archivo Dart más grande | `visor_screen.dart`: 2,897 líneas | Riesgo alto de regresión y conflictos |
| Segundo archivo más grande | `midi_engine.dart`: 870 líneas | Demasiadas responsabilidades de audio |
| Archivos de prueba | 4 | Cobertura estructural baja |
| Declaraciones `test`/`testWidgets` | 13 | Predominan parser y validación de assets |
| Recursos `offline_assets` | 2,078 archivos / ~360.28 MB | Impacto en descarga, instalación y compilación |
| SoundFont | ~1.98 MB | Tamaño razonable |
| Hallazgos del analizador | 79 informativos | 76 usos obsoletos; sin errores ni warnings |
| Automatización CI | 1 workflow, solo iOS | Android y pruebas no son puertas de calidad |

## Registro priorizado

### DT-01 — Falta de observabilidad en audio y exportación

**Prioridad:** P0  
**Área:** confiabilidad y soporte

**Evidencia**

- Los fallos se registran principalmente con `debugPrint`.
- Existen bloques `catch (_) {}` que eliminan la causa del error.
- Los reportes Bluetooth no incluyen modelo de dispositivo, versión del sistema, ruta de audio, preset activo ni estado del motor.
- La recuperación de ruta nativa recién incorporada no produce un historial persistente que soporte diagnóstico remoto.

**Impacto**

Los reportes de “otro instrumento”, silencio, clipping o exportación defectuosa no se pueden reproducir ni clasificar con datos. El costo de soporte aumenta y se corre el riesgo de aplicar correcciones especulativas.

**Recomendación**

- Crear un `AudioDiagnosticsService` con eventos estructurados y un identificador de sesión no personal.
- Registrar plataforma, versión del sistema, ruta anterior/nueva, tipo de dispositivo, estado del SoundFont, banco/programa, ganancia, cantidad de voces y etapa de exportación.
- Mantener un buffer circular local y permitir al usuario copiar o compartir un diagnóstico.
- Integrar reporte remoto solamente con consentimiento y política de privacidad adecuada.

**Criterio de cierre**

Un reporte de usuario debe permitir distinguir entre fallo de ruta, fallo del sintetizador, clipping, metrónomo aislado y archivo MIDI defectuoso sin solicitar una compilación especial.

### DT-02 — Reproductor MIDI monolítico y estado global

**Prioridad:** P0  
**Área:** arquitectura de audio

**Evidencia**

- `MidiEngine` es un singleton con temporizador, parser, scheduler, mezcla, metrónomo, SoundFont, sesión de audio y recuperación de ruta.
- El `StreamController` se conserva abierto durante toda la sesión y el método `dispose` no libera el sintetizador.
- Hay estado duplicado entre Flutter y el plugin nativo: mute, volumen, canal, preset, notas activas y reproducción.
- Android e iOS tienen comportamientos nativos distintos, pero comparten una interfaz con poca capacidad de inspección.

**Impacto**

Las interrupciones, cambios Bluetooth, navegación y pausas pueden generar carreras difíciles de probar. El singleton también impide crear motores aislados en pruebas.

**Recomendación**

- Separar en `MidiTransport`, `MidiSynth`, `MixerState`, `MetronomeEngine` y `AudioRouteCoordinator`.
- Inyectar interfaces de plataforma y reloj para usar implementaciones falsas en pruebas.
- Definir una máquina de estados explícita: `idle`, `loading`, `ready`, `playing`, `recovering`, `paused`, `failed`, `disposed`.
- Establecer un propietario único de `AVAudioSession`/`AudioManager` y documentar el ciclo de vida.

**Criterio de cierre**

La recuperación de ruta, pausa, seek y cierre deben probarse sin hardware mediante dobles de prueba y sin depender de un singleton global.

### DT-03 — Ganancia sin medición de picos ni limitador de salida

**Prioridad:** P0  
**Área:** calidad de audio

**Evidencia**

- El master aplica un incremento fijo de +10 dB.
- La velocidad MIDI se limita, pero esto no equivale a limitar los picos PCM producidos por acordes, reverb o suma de voces.
- Android y iOS renderizan con motores diferentes y no existe una prueba de loudness/true peak que compare ambos resultados.

**Impacto**

Puede existir clipping audible, especialmente en bocinas Bluetooth con DSP propio. El mismo canto puede sonar diferente entre reproducción en vivo y MP3 exportado.

**Recomendación**

- Medir pico PCM y loudness integrado de un corpus representativo de MIDI.
- Sustituir la ganancia fija por normalización con techo, por ejemplo un limitador de salida y margen de seguridad configurable.
- Versionar el perfil de master y añadirlo a la clave de caché de exportación.
- Crear pruebas que rechacen archivos con muestras recortadas y diferencias excesivas entre plataformas.

**Criterio de cierre**

Ningún archivo del corpus debe superar el techo definido ni presentar clipping digital, y el loudness entre reproducción/exportación debe quedar dentro de una tolerancia acordada.

### DT-04 — `VisorScreen` concentra demasiadas responsabilidades

**Prioridad:** P1  
**Área:** mantenibilidad

**Evidencia**

`visor_screen.dart` contiene aproximadamente 2,897 líneas y coordina:

- visor PDF y zoom;
- anotaciones y herramientas;
- reproductor y mezclador MIDI;
- monetización y anuncios;
- exportación PDF/MIDI/MP3;
- guardado nativo y hoja de compartir;
- diálogos, traducciones y manejo de plataforma.

Además conserva un menú de compartir marcado como compatibilidad temporal y suprimido con `ignore: unused_element`.

**Impacto**

Cualquier cambio toca un archivo de alto conflicto, las pruebas requieren montar demasiada infraestructura y es fácil usar `BuildContext` después de operaciones asíncronas.

**Recomendación**

- Extraer controladores de exportación, audio y anotaciones.
- Dividir la UI en widgets por función, con modelos de estado inmutables.
- Eliminar el menú legado cuando se confirme que no tiene consumidores.
- Mantener las decisiones de Android/iOS fuera de la capa visual.

**Criterio de cierre**

El visor debe quedar como composición/orquestación y ningún archivo nuevo de funcionalidad debería superar aproximadamente 400–500 líneas sin justificación.

### DT-05 — Recursos offline duplican una arquitectura bajo demanda

**Prioridad:** P1  
**Área:** tamaño, rendimiento y distribución

**Evidencia**

- `offline_assets` contiene unos 2,078 archivos y 360.28 MB.
- La aplicación también implementa descargas individuales desde un servicio remoto.
- Los assets cifrados se copian, descifran y vuelven a escribir en documentos locales, generando duplicación temporal y permanente.

**Impacto**

Aumentan el tamaño de descarga, tiempo de instalación, presión de almacenamiento, duración de CI y riesgo de rechazo o abandono en redes lentas.

**Recomendación**

- Definir si el producto requiere biblioteca completa offline o descarga selectiva.
- Considerar paquetes por idioma/región, descarga inicial mínima o asset packs bajo demanda.
- Medir tamaño instalado y espacio máximo durante descifrado/exportación.
- Añadir políticas de retención, limpieza y cuota para PDF, MIDI, WAV temporal y MP3.

**Criterio de cierre**

Existirá un presupuesto de tamaño por versión y una prueba de CI fallará si se supera sin aprobación explícita.

### DT-06 — Clave criptográfica embebida en el cliente

**Prioridad:** P1, o P0 si se espera confidencialidad real  
**Área:** seguridad

**Evidencia**

- `FileCrypto` contiene `_rawKey = 'repertorio-coral-lldm-key-2026'`.
- Cualquier secreto distribuido dentro de una aplicación cliente puede recuperarse mediante ingeniería inversa.
- AES-GCM protege integridad durante el proceso, pero la clave compartida elimina la confidencialidad frente a quien posee el binario.

**Impacto**

Si el cifrado pretende proteger contenido licenciado o restringido, el control actual es insuficiente. La rotación también obliga a actualizar clientes o mantener compatibilidad con varias claves.

**Recomendación**

- Documentar el modelo de amenazas: ofuscación casual frente a control de acceso real.
- Para contenido restringido, usar autorización de servidor, URLs firmadas de corta duración y claves por usuario/dispositivo almacenadas en Keychain/Keystore.
- Versionar formalmente el formato criptográfico y diseñar rotación/migración.
- No describir el cifrado cliente como garantía de confidencialidad si seguirá siendo una clave global.

**Criterio de cierre**

El nivel de protección esperado estará documentado y la implementación corresponderá con ese nivel, incluyendo un procedimiento probado de rotación.

### DT-07 — Cachés y temporales sin política completa de limpieza

**Prioridad:** P1  
**Área:** almacenamiento

**Evidencia**

- La exportación conserva MP3 cacheados por huella y versión.
- Las copias para compartir se crean en subdirectorios temporales únicos.
- Algunos temporales WAV/MIDI se eliminan con `finally`, pero los errores de limpieza se silencian.
- No existe límite por edad, cantidad o espacio ocupado.

**Impacto**

Usuarios que exportan muchos cantos o voces pueden acumular archivos sin entender por qué crece el uso de almacenamiento.

**Recomendación**

- Implementar un `CacheMaintenanceService` con cuota, LRU/TTL y limpieza al iniciar o después de exportar.
- Separar claramente caché regenerable, documentos del usuario y temporales compartidos.
- Exponer “Liberar espacio” y métricas por categoría.

**Criterio de cierre**

El almacenamiento regenerable tendrá límites configurados y pruebas para limpieza, archivos en uso y recuperación tras cierre inesperado.

### DT-08 — Cobertura de pruebas insuficiente en flujos críticos

**Prioridad:** P1  
**Área:** calidad

**Evidencia**

- Solo hay 4 archivos de prueba y 13 casos declarados.
- El smoke test monta un `MaterialApp` mínimo, no la aplicación real.
- No hay pruebas automatizadas para Bluetooth, interrupciones, monetización, anuncios, descargas incompletas, caché concurrente, compartición, MP3, permisos o lifecycle.
- Las integraciones nativas nuevas no tienen pruebas unitarias Kotlin/Swift.

**Recomendación**

Crear una pirámide de pruebas:

1. unitarias para scheduler, máquina de estados, nombres, caché y normalización;
2. widgets para visor, controles, errores y monetización;
3. integración con canales nativos falsos;
4. pruebas físicas mínimas en Android/iOS con Bluetooth y exportación;
5. corpus de audio con validación automática de duración, silencio, clipping y formato.

**Criterio de cierre**

Cada incidente de producción relevante debe producir primero una prueba de regresión, y CI debe ejecutar el conjunto crítico en cada PR.

### DT-09 — CI/CD no funciona como puerta de calidad multiplataforma

**Prioridad:** P1  
**Área:** entrega

**Evidencia**

- Existe un único workflow orientado a compilar y desplegar iOS.
- No ejecuta explícitamente `flutter analyze` ni `flutter test` antes de archivar.
- No hay compilación Android en CI.
- El mismo workflow se activa en pull requests y contiene lógica de firma/despliegue, aumentando complejidad y duración.

**Recomendación**

- Separar `quality.yml`, `build-android.yml` y `release-ios.yml`.
- Hacer obligatorios formato, análisis, pruebas y compilación debug de ambas plataformas antes de merge.
- Ejecutar firma y publicación únicamente en ramas/tags protegidos o mediante aprobación de entorno.
- Cachear dependencias sin ocultar fallos de reproducibilidad.

**Criterio de cierre**

Ningún cambio podrá integrarse con errores de análisis, pruebas fallidas o código nativo que no compile.

### DT-10 — APIs obsoletas y dependencias sin proceso periódico

**Prioridad:** P2  
**Área:** mantenimiento preventivo

**Evidencia**

- El análisis registra 79 hallazgos informativos: 76 son `DEPRECATED_MEMBER_USE`.
- Predominan `withOpacity` y accesos obsoletos de `pdfrx`.
- La compilación Android muestra avisos de plugins con manifiestos/targets antiguos.
- No hay evidencia de un trabajo automatizado de actualización y compatibilidad.

**Recomendación**

- Crear un presupuesto de cero deprecaciones nuevas.
- Migrar primero APIs de la aplicación y después actualizar plugins por lotes pequeños.
- Ejecutar revisión mensual de dependencias, changelogs y requisitos mínimos de SO.
- Probar cambios de Flutter/Xcode/Gradle en una rama de mantenimiento antes de actualizar CI.

**Criterio de cierre**

El analizador quedará sin deprecaciones de código propio y las advertencias de terceros estarán registradas con responsable y versión objetivo.

### DT-11 — Configuración, localización y errores mezclados con código de producto

**Prioridad:** P2  
**Área:** mantenibilidad operativa

**Evidencia**

- URL de almacenamiento e identificadores publicitarios están codificados en archivos de producción.
- Muchas cadenas bilingües se construyen directamente con `strings.t(es, en)` dentro de widgets.
- Los errores se transforman en texto directamente en la UI y frecuentemente incluyen la excepción técnica.
- `pubspec.yaml` todavía conserva la descripción genérica de proyecto Flutter.

**Recomendación**

- Centralizar configuración por ambiente y validar variables obligatorias al arrancar/build.
- Migrar a catálogos ARB con claves estables y soporte de pluralización.
- Definir errores de dominio y mensajes seguros para usuario; conservar detalle técnico solo en diagnóstico.
- Completar metadatos del proyecto y documentación de ambientes.

**Criterio de cierre**

Producción, staging y desarrollo podrán configurarse sin editar código fuente, y las cadenas visibles estarán fuera de los widgets.

## Hoja de ruta sugerida

### 0–30 días: estabilización

- Implementar diagnóstico local estructurado de audio/rutas/exportación.
- Añadir pruebas de regresión para Bluetooth, pausa/seek, nombres exportados y caché.
- Incorporar `flutter analyze`, `flutter test` y compilación Android a CI.
- Medir clipping y loudness después del aumento de +10 dB.
- Añadir limpieza de temporales y límite inicial de caché.
- Decidir y documentar si el cifrado es ofuscación o control de acceso.

### 31–60 días: desacoplamiento

- Extraer exportación/compartición fuera de `VisorScreen`.
- Separar transporte, sintetizador, mezclador, metrónomo y rutas de audio.
- Introducir interfaces inyectables para canales nativos y reloj.
- Eliminar menú legado y capturas silenciosas de errores.
- Separar workflow de calidad de los workflows de despliegue.

### 61–90 días: distribución y sostenibilidad

- Implementar estrategia de contenido offline selectivo y presupuesto de tamaño.
- Migrar localización a ARB y configuración por ambiente.
- Reducir deprecaciones y actualizar dependencias de forma controlada.
- Añadir pruebas físicas documentadas para una matriz mínima de dispositivos Bluetooth.
- Si el contenido requiere protección real, diseñar autorización y rotación de claves del lado servidor.

## Matriz mínima de pruebas físicas

| Plataforma | Escenario | Resultado esperado |
|---|---|---|
| Android | Bluetooth conectado antes de abrir un canto | Piano correcto, sin silencio ni ráfagas |
| Android | Conectar/desconectar durante reproducción | Recuperación desde posición cercana, preset piano conservado |
| iOS | AirPods/A2DP antes de reproducir | Piano, master y metrónomo en la misma ruta |
| iOS | Cambio de ruta durante acorde sostenido | Sin bloqueo; se permite cortar la nota sostenida, no cambiar preset |
| Ambas | Llamada/anuncio/interrupción y retorno | Estado coherente y reanudación controlada |
| Ambas | Ensamble más denso del corpus | Sin clipping digital ni bombeo excesivo |
| Ambas | Exportar y compartir PDF/MIDI/MP3 | Nombre limpio, MIME correcto y reproducción interna cuando corresponda |

## Fortalezas que conviene preservar

- Validación de cabeceras PDF/MIDI antes de aceptar archivos.
- Escritura mediante temporal y reemplazo para reducir cachés parciales.
- Uso de isolate para descifrado costoso.
- Selección explícita de banco/programa de piano en todos los canales.
- Versionado de caché de exportación cuando cambia el procesamiento.
- Credenciales de RevenueCat inyectadas por entorno en lugar de incluir claves privadas en el repositorio.
- Pruebas que recorren todos los PDF/MIDI globales empaquetados.

## Definición de “deuda controlada”

La deuda no estará eliminada por completo; estará controlada cuando:

- cada riesgo P0 tenga propietario, fecha y prueba de regresión;
- CI sea una puerta obligatoria para Dart, Android e iOS;
- existan presupuestos medibles de tamaño, caché, loudness y deprecaciones;
- los módulos de audio/exportación puedan probarse sin hardware;
- los incidentes produzcan datos diagnósticos útiles;
- seguridad y distribución offline respondan a decisiones de producto documentadas, no a supuestos implícitos.

