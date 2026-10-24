# Meta Audience Network mediante AdMob Bidding

App ID de Meta proporcionado por el titular: `1757119605587243`.
Package name / Bundle ID: `com.lldm.coro`.

## Integración

El paquete `gma_mediation_meta` está fijado en 1.5.0, compatible con
`google_mobile_ads` 6.x. Flutter registra el plugin para Android e iOS e incorpora
el adaptador y SDK nativos. No se deben sustituir los IDs de AdMob por los de
Meta en `AdUnitIds`: los placements se asignan en el panel de AdMob.

El adaptador declara `compileSdk` 33, pero sus dependencias AndroidX requieren
34 o superior. `android/build.gradle.kts` ajusta únicamente ese módulo a API 36
al finalizar su DSL, igual que la app, sin modificar el paquete descargado.

En iOS 15/16, `AppDelegate` transmite a Meta el estado real de ATT al arrancar
y al volver al primer plano. Solo permite seguimiento cuando ATT está
`authorized`; no solicita ni concede permisos automáticamente. En iOS 17 o
superior el SDK de Meta consulta ATT directamente.

Meta admite bidding y no se debe configurar en waterfall. Esta integración
usa banner, interstitial y rewarded. Meta no ofrece App Open mediante este
adaptador; ese formato conserva AdMob y Liftoff.

## Mapeos

Los placements de Android e iOS son distintos, aunque comparten el prefijo del
App ID. Mantener la asignación exacta proporcionada por el titular.

| Plataforma | Formato | Bloque de AdMob | Placement ID de Meta |
| --- | --- | --- | --- |
| Android | Banner | `ca-app-pub-1667188991926373/7485759845` | `1757119605587243_1757119802253890` |
| iOS | Banner | `ca-app-pub-1667188991926373/3375918008` | `1757119605587243_1757119785587225` |
| Android | Interstitial | `ca-app-pub-1667188991926373/7190512306` | `1757119605587243_1757119808920556` |
| iOS | Interstitial | `ca-app-pub-1667188991926373/1005171461` | `1757119605587243_1757119792253891` |
| Android | Rewarded | `ca-app-pub-1667188991926373/5266790613` | `1757119605587243_1757119788920558` |
| iOS | Rewarded | `ca-app-pub-1667188991926373/2764975693` | `1757119605587243_1757119795587224` |

## Antes de publicar

- Añadir Meta Audience Network como fuente de bidding en los seis grupos/bloques
  correspondientes de AdMob y guardar los placements de la tabla.
- Verificar en Meta que cada placement pertenece a la plataforma y formato
  indicados y que Google AdMob está seleccionado como mediador.
- Añadir Meta a los proveedores de los mensajes de consentimiento de AdMob y
  comprobar sus requisitos de privacidad para los territorios atendidos.
- Obtener la entrada de `app-ads.txt` desde Monetization Manager de Meta. El
  App ID no permite deducir de forma segura el identificador del vendedor; no
  publicar una entrada inventada usando ese número.
- Los identificadores `v9wttpbfk9.skadnetwork` y `n38lu8286q.skadnetwork` ya
  están presentes en `ios/Runner/Info.plist` y no se duplican.
- Ejecutar `flutter pub get` y `pod install --repo-update` en macOS antes de
  compilar iOS. No editar `Podfile.lock` manualmente desde Windows.
- Registrar el dispositivo de prueba en AdMob y Meta. Comprobar cada formato
  en Ad Inspector con Meta Audience Network (Bidding) como única fuente. Los
  IDs de prueba de Google usados en debug no comprueban estos mapeos: usar
  perfil con el dispositivo registrado y el modo de prueba de Meta habilitado.
- Desactivar el modo de prueba antes de publicar en las tiendas.

## Referencia

https://developers.google.com/admob/flutter/mediation/meta
