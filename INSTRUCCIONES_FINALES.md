# Instrucciones Finales - Distribución Oficial de la App

Este documento resume los cambios aplicados en la aplicación, el estado actual de los archivos y los pasos precisos que debes seguir para subir el código a GitHub y publicar la app en la App Store (utilizando **Xcode Cloud** o **GitHub Actions**).

---

## 1. Cambios Habilitados en el Código (Listo para Producción)

*   **Anotaciones Táctiles Reparadas:** Se corrigieron los problemas de interferencia en iOS. La paleta de colores, tamaños, borrador y herramienta de texto tienen soporte táctil completo y no traspasan los eventos al visor del PDF de fondo.
*   **Audio Desactivado:** Se configuró el plugin dinámico de audio para retornar `null` de forma segura. Se removió el botón MIDI de la barra superior del visor para evitar reclamos o rechazos de Apple.
*   **Premium por Defecto:** La app está configurada para desbloquear todo de inmediato y no pedir compras integradas ni mostrar anuncios. Pasará la revisión de Apple limpia.
*   **Integración de CI/CD:** Se prepararon los archivos necesarios tanto para compilar en **GitHub Actions** como en **Xcode Cloud** de Apple.

---

## 2. Subir el Código a GitHub (Acción Inmediata)

El repositorio remoto ya está enlazado a tu URL: `https://github.com/Agarrrrr/IosCoroLLDM.git`.

Para subir el código a tu cuenta, abre la **Terminal** en la carpeta principal (`corolldm-main`) y ejecuta:

```bash
git push -u origin main
```

*   **Nota:** Al ejecutarlo, macOS te pedirá en pantalla iniciar sesión en tu cuenta de GitHub o ingresar tu Token para dar permisos de subida. Una vez que lo hagas, el código se subirá de forma privada.

---

## 3. Método Recomendado: Publicar usando Xcode Cloud (Gratis y Automático)

Dado que esta Mac es del 2017 y tiene un Xcode viejo, la compilación en la nube de Apple (Xcode Cloud) es la forma más fácil y rápida, ya que **no requiere configurar certificados manualmente.**

Ya creamos y agregamos a Git el script especial `ios/App/ci_scripts/ci_post_clone.sh` que requiere Xcode Cloud para generar los archivos web antes de compilar.

**Pasos para activarlo:**
1.  Asegúrate de haber hecho el `git push` a tu repositorio de GitHub.
2.  Abre el proyecto en **Xcode** en tu Mac local.
3.  Ve al menú superior de Xcode ➔ **Product** ➔ **Create Workflow...**
4.  Vincula tu cuenta de GitHub cuando te lo solicite y selecciona tu repositorio.
5.  ¡Listo! Xcode Cloud compilará la app automáticamente en la nube de Apple con el SDK de iOS más reciente y la enviará directamente a TestFlight.

---

## 4. Método Alternativo: GitHub Actions

Si decides no usar Xcode Cloud y prefieres que GitHub compile y firme la app en su propia infraestructura:
*   Sigue los pasos detallados en el manual **`GUIA_GITHUB_ACTIONS.md`** que creamos en la raíz del proyecto.
*   Deberás exportar tu certificado `.p12` desde tu Mac local, codificarlo en Base64 junto a tu perfil de provisión e ingresar las variables secretas en los ajustes de tu repositorio de GitHub.
*   El llavero virtual en la nube está configurado con la contraseña **`Television2012`** que elegiste.

---

## 5. Publicación Oficial en la App Store (Web)

Una vez que Xcode Cloud o GitHub Actions termine la compilación en la nube, el paquete aparecerá en tu cuenta de Apple. Para finalizar:

1.  Inicia sesión en **[App Store Connect](https://appstoreconnect.apple.com)**.
2.  Ve a **Mis Apps** ➔ **Nueva app** (botón `+`).
3.  Selecciona el Bundle ID (`com.lldm.coro`) y ponle nombre a tu app.
4.  En la ficha de la app, añade:
    *   Descripción de la app.
    *   Capturas de pantalla del iPad (puedes tomarlas usando el simulador).
    *   URL de Políticas de Privacidad: Puedes enlazar al archivo `privacy.html` que está en tu proyecto (subido a tu dominio web).
5.  En **Precios y disponibilidad**, configúrala como de **Pago único** (ej: $1.99 USD).
6.  Selecciona la compilación subida (Build) y haz clic en **Enviar para revisión**.
