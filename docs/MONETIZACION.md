# Monetización móvil

La aplicación usa Google Mobile Ads para anuncios y RevenueCat para el
entitlement `premium`. En modo debug AdMob utiliza exclusivamente los bloques
de prueba oficiales de Google; los identificadores de producción sólo se usan
en compilaciones release.

## RevenueCat

La aplicación Android conserva la clave pública del proyecto anterior. Para
iOS falta completar la configuración externa:

1. Agregar en RevenueCat una app de App Store con bundle ID `com.lldm.coro`.
2. Conectar RevenueCat con App Store Connect.
3. Crear o importar en App Store Connect `corolldm_menusalv2` y
   `corolldm_anualv2`.
4. Asociar ambos productos al entitlement `premium`.
5. Agregarlos a la oferta predeterminada usando los paquetes `$rc_monthly` y
   `$rc_annual`.
6. Verificar que la clave pública iOS `appl_...` coincida con la mostrada en
   **Project settings > API keys**.

El paywall obtiene nombres y precios directamente de la oferta predeterminada;
no hay precios codificados en la aplicación.

La vigencia se vuelve a consultar al regresar la aplicación a primer plano y
antes de conceder acceso premium al audio. Una cancelación conserva Premium
hasta terminar el periodo pagado; después RevenueCat deja de incluir
`premium` entre los entitlements activos y la aplicación reactiva los límites
y anuncios.

La clave pública iOS está incluida como valor predeterminado. En CI puede
reemplazarse sin modificar el código usando:

```sh
flutter build ipa --release \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_REEMPLAZAR
```

La configuración iOS usa el App ID
`ca-app-pub-1667188991926373~5770412981` y tiene bloques propios para banner,
apertura, intersticial y recompensa. No necesita variables adicionales de
AdMob al compilar.

## Premium heredado de iOS

Sólo en iOS release se sincroniza una vez el recibo con RevenueCat. Se concede
Premium vitalicio cuando `originalApplicationVersion` pertenece a la familia
1.x. Android nunca participa en esta regla.

Los recibos sandbox de Apple siempre informan `1.0`; la aplicación detecta
`sandboxReceipt` nativamente y excluye tanto TestFlight como las pruebas
locales, evitando Premium falso durante testing.

## Comportamiento gratuito

- Cinco cantos MIDI distintos por día; repetir el mismo canto no consume otro.
- Un anuncio recompensado agrega un canto adicional cuando existe un bloque
  configurado para la plataforma.
- El primer intersticial aparece en la quinta apertura de partitura y después
  cada cinco a ocho aperturas.
- Separación global mínima de tres minutos entre anuncios a pantalla completa
  (App Open e Intersticial) para evitar acumulación.
- Banner adaptable en el catálogo.
- Anuncio de apertura al regresar a primer plano, con separación local mínima
  de dos minutos.
- Premium desactiva y libera todos los anuncios cargados.

El consentimiento publicitario se solicita mediante Google UMP antes de cargar
el primer anuncio.
