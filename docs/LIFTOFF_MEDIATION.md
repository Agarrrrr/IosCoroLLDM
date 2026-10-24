# Liftoff Monetize mediante AdMob

## Integración en la aplicación

`gma_mediation_liftoffmonetize` 1.4.1 incorpora los adaptadores y SDK nativos
para Android e iOS. Esta versión está fijada porque es la última de la serie
compatible con `google_mobile_ads` 6.x; actualizarla requiere revisar también
la versión de Google Mobile Ads y los requisitos de Flutter.

Flutter registra el plugin automáticamente. `AdsService.initialize()` espera
el consentimiento de UMP y la inicialización de AdMob antes de cargar anuncios.
El adaptador obtiene el App ID y Reference ID de la configuración de AdMob;
no se inicializa Vungle directamente ni se sustituyen los bloques de AdMob.

`ios/Runner/Info.plist` incluye los identificadores SKAdNetwork y
AdAttributionKit de la lista oficial de compradores de Liftoff. Revisar la lista
al actualizar el SDK:
https://vungle-static-assets.s3.amazonaws.com/dashboard/admin/prod/skadnetworkids.xml

## Mapeos de AdMob

Bundle ID / Package name en ambas plataformas: `com.lldm.coro`.
Los siguientes valores son identificadores públicos, no claves de acceso.

### iOS

App ID de Liftoff: `6adc44badf651bb9b7aa98ba`.

| Formato | Bloque de AdMob | Reference ID de Liftoff |
| --- | --- | --- |
| App Open | `ca-app-pub-1667188991926373/6501040724` | `APPOPENIOS-2634775` |
| Interstitial | `ca-app-pub-1667188991926373/1005171461` | `INTERIOS-9442501` |
| Rewarded | `ca-app-pub-1667188991926373/2764975693` | `RWDIOS-4550305` |
| Banner | `ca-app-pub-1667188991926373/3375918008` | `BANNERIOS-3075359` |

### Android — CoroLLDMAndroid

App ID de Liftoff: `6adc478ddf651bb9b7aa98cf`.

| Formato | Bloque de AdMob | Reference ID de Liftoff |
| --- | --- | --- |
| App Open | `ca-app-pub-1667188991926373/4859596502` | `APPOPENANDROID-7510358` |
| Interstitial | `ca-app-pub-1667188991926373/7190512306` | `INTERANDROID-0041547` |
| Rewarded | `ca-app-pub-1667188991926373/5266790613` | `REWARDANDROID-5998825` |
| Banner | `ca-app-pub-1667188991926373/7485759845` | `BANNER-2206745` |

## Configuración externa pendiente y comprobación

1. Añadir Liftoff Monetize como fuente de bidding en los grupos de AdMob y
   guardar los mapeos anteriores. Los placements deben tener In-App Bidding
   activado y el refresco del banner desactivado en Liftoff.
2. Incluir Liftoff en los proveedores del mensaje de consentimiento de AdMob.
   Liftoff lee el consentimiento GDPR de UMP automáticamente. Verificar también
   la configuración de privacidad correspondiente a los estados de EE. UU.;
   no se debe asumir ni fijar consentimiento a `true` en el código.
3. Verificar `https://lldmcorobc.com/app-ads.txt`, que debe conservar Google y
   contener `vungle.com, 6adc4069eea009f890ee3791, DIRECT, c107d686becd2d77`.
4. En macOS ejecutar `flutter pub get` y `cd ios && pod install --repo-update`
   antes de compilar iOS. No editar `Podfile.lock` manualmente desde Windows.
5. Registrar un dispositivo de prueba en AdMob y habilitar el modo de prueba
   en Liftoff. Usar Ad Inspector con una sola fuente, Liftoff (Bidding), para
   comprobar los cuatro formatos en cada plataforma. Los bloques de Google de
   `kDebugMode` comprueban Google, pero no los mapeos de producción de Liftoff;
   usar una compilación de perfil con el dispositivo registrado para esta prueba.
6. Desactivar los modos de prueba antes de publicar las nuevas versiones.

Pangle queda fuera de esta integración: el titular es desarrollador individual
y Pangle exige documentación de una empresa constituida para monetizar. No se
ha añadido su SDK. Política oficial:
https://www.pangleglobal.com/knowledge/individual-developers

## Referencias

- https://developers.google.com/admob/flutter/mediation/liftoff-monetize
- https://pub.dev/packages/gma_mediation_liftoffmonetize/changelog
- https://support.vungle.com/hc/en-us/articles/360002925791-Integrate-Vungle-SDK-for-iOS
