# Instrucciones de migración para `repertorio_bc` (Flutter)

Proyecto destino: `C:\Users\Huri_\Documents\proyectos\repertorio_bc`.
Es una aplicación Flutter independiente con Riverpod, Hive, `pdfrx`, `flutter_midi_pro`, `audioplayers` y `flutter_lame`. Estas instrucciones describen cómo portar los cambios de `IosCoroLLDM`; no copiar el proyecto completo ni mezclar sus historiales Git.

## 1. Preparación

```powershell
cd C:\Users\Huri_\Documents\proyectos\repertorio_bc
git checkout -b codex/migrar-mejoras-ioscorolldm
flutter pub get
flutter analyze
flutter test
```

Haz una copia de las cajas Hive y de los datos de Supabase antes de modificar anotaciones. Conserva los cambios locales existentes del proyecto destino.

## 2. Archivos a comparar y portar

Usa como referencia los archivos equivalentes de `IosCoroLLDM`:

| Área | Destino en `repertorio_bc` | Referencia |
|---|---|---|
| Tema y preferencias | `lib/core/providers/theme_provider.dart` | `lib/core/providers/theme_provider.dart` |
| Ajustes | `lib/features/settings/settings_screen.dart` | `lib/features/settings/settings_screen.dart` |
| App | `lib/app/app.dart` | `lib/app/app.dart` |
| Inicialización | `lib/main.dart` | `lib/main.dart` |
| Visor | `lib/features/visor/visor_screen.dart` | `lib/features/visor/visor_screen.dart` |
| Motor PDF | `lib/core/pdf/pdf_engine.dart` | `lib/core/pdf/pdf_engine.dart` |
| Anotaciones | `lib/core/pdf/annotation_store.dart` y/o `annotation_sync_service.dart` | `lib/core/pdf/annotation_store.dart` |
| MIDI y exportación | `lib/core/midi/midi_engine.dart`, `midi_export_service.dart` | mismos archivos |
| Pruebas | `test/` | `test/theme_provider_test.dart`, `annotation_store_test.dart` |

Porta la lógica, no reemplaces archivos a ciegas: el destino usa Supabase y puede tener providers o modelos adicionales.

## 3. Persistencia compatible con actualizaciones

En `theme_provider.dart`, crea una caja Hive separada para preferencias, por ejemplo `settings`, y ábrela en `main.dart` antes de crear el `ProviderContainer`.

```dart
const userSettingsBoxName = 'settings';
await Hive.openBox(userSettingsBoxName);
```

Guarda allí `theme_mode`, `dark_oled_enabled`, `accent_color` y `pdf_carousel_mode`. Al leer, primero consulta `settings`; si la clave no existe, migra el valor de la caja antigua `cache` y escríbelo en `settings`. No borres las claves antiguas durante la migración. Hive conserva estas cajas cuando se instala una actualización; solo se pierden si el usuario desinstala o borra los datos.

Mantén el índice de los modos existentes y agrega `oscuroNormal` al final del enum. El valor predeterminado de OLED debe ser `true` para que los usuarios actuales conserven el comportamiento negro puro.

## 4. Temas y resaltes

En `theme_provider.dart` y `app.dart`:

- Mantén `oscuro` como OLED: fondo negro.
- Agrega `oscuroNormal` con fondo `#11161C`, superficie `#1B2430`, superficie secundaria `#16202A`, bordes `#314052`, texto `#F1F5F9`, texto suave `#C3CFDB`, inputs `#222D3A` y bordes de input `#3B4A5D`.
- Usa `#F6D96B` como acento predeterminado y `#FFE48F` como acento fuerte.
- Añade `#8B5A2B` (café) al selector de colores en Ajustes.
- El color elegido debe seguir siendo personalizable en todos los temas.
- Antes de construir `ThemeData`, adapta el color en HSV: oscurecerlo en claro, aumentar valor en OLED, reducir saturación en oscuro normal y suavizarlo en sepia/quiet. Conserva el hue y guarda siempre el color base original.
- Deriva `onPrimary`, sombra, foco de inputs, AppBar, botones y switches desde el color adaptado para mantener contraste.

En el visor, aplica el filtro específico de cada perfil: oscuro normal debe mapear blanco del PDF a `#1B2430` y negro a `#F1F5F9`; OLED conserva la inversión/fondo negro actual.

## 5. Anotaciones persistentes por página

Integra la lógica en `annotation_store.dart`, `annotation_sync_service.dart`, `visor_screen.dart` y `widgets/annotation_layer.dart`:

- Guardar y cargar por `cantoId + número de página`, nunca como un lienzo continuo.
- Persistir localmente antes de sincronizar y usar debounce.
- No sobrescribir una anotación local pendiente con datos de Supabase.
- Usar `upsert` por `usuario_id, canto_id, pagina`.
- Aceptar registros antiguos sin versión de PDF y asociarlos retroactivamente por canto y página.
- Si el JSON está corrupto, devolver una lista vacía y permitir abrir el canto.
- Restaurar las anotaciones después de cambiar orientación, zoom, página o versión del PDF.

Agrega pruebas de reinicio, actualización de versión del PDF, trabajo offline/online y datos corruptos.

## 6. Visor y carrusel

En `visor_screen.dart` y `pdf_engine.dart`:

- En carrusel, tratar cada página como unidad independiente y usar `PdfPageAnchor.all` o el equivalente disponible en la versión de `pdfrx` del destino.
- Abrir cada página ajustada completa al área visible; no iniciar con `fitWidth` si corta la partitura.
- Establecer el zoom mínimo al ajuste completo, permitir zoom superior y recalcularlo al rotar.
- Al cambiar de página con zoom, recentrar dentro de los límites y cancelar animaciones anteriores obsoletas.
- Añadir zonas táctiles laterales de aproximadamente 30% para avanzar/retroceder con un toque simple; no interferir con pinch-to-zoom.
- Mostrar durante un segundo una flecha circular de avance en el centro del borde derecho y desvanecerla usando colores del `ColorScheme`.
- Limitar caché/renderizado en móviles, cancelar tareas PDF anteriores y liberar documentos/canvas al cerrar el visor.

Verifica lectura de páginas completas, navegación lateral, zoom, rotación y anotaciones simultáneamente.

## 7. Audio, MP3 y Bluetooth

En `midi_engine.dart` y `midi_export_service.dart`:

- Colocar la ganancia máster lineal equivalente a +10 dB (`3.16227766`) antes del limitador; no duplicarla en reproducción y exportación.
- Añadir limitador/techo de aproximadamente `-1 dB` para evitar clipping.
- Mantener `audio/mpeg` y extensión `.mp3` al compartir para que WhatsApp lo trate como audio reproducible.
- Limpiar nombres de exportación y no incluir IDs internos.
- Reaccionar a cambios de ruta Bluetooth y reanudar el `AudioSession`/player sin cambiar instrumentos.
- Mantener el parseo MIDI y las precargas fuera del hilo de UI cuando el código existente ya use isolates.

Prueba piano, SATB, metrónomo, auriculares, altavoz, Bluetooth, bloqueo de pantalla y compartir MP3 en Android/iOS.

## 8. Verificación y entrega

```powershell
cd C:\Users\Huri_\Documents\proyectos\repertorio_bc
dart format lib test
flutter analyze
flutter test
flutter build appbundle --release
flutter build ipa --release
```

Comprueba que la versión de `pubspec.yaml` y el `versionCode`/`versionName` Android sean los del proyecto destino. Revisa manualmente que la migración no borre datos, que el tema se conserve tras reinicio/actualización, que el PDF se vea completo en carrusel y que el AAB/IPA use la firma propia de `repertorio_bc`.

Para publicar, crea un commit separado en el repositorio de `repertorio_bc`; no subas el AAB al repositorio salvo que su flujo actual lo requiera.
