# Guía de Publicación con GitHub Actions

Esta guía te muestra paso a paso cómo configurar GitHub Actions en tu repositorio privado para compilar y subir automáticamente la aplicación a **App Store Connect / TestFlight** desde la nube, evitando las limitaciones de tu Mac local.

---

## Paso 1: Exportar y Codificar tus Credenciales en la Mac Local

Para que GitHub Actions pueda firmar la app por ti, necesitamos codificar tu Certificado y tu Perfil de Provisión en Base64 para guardarlos de forma segura en GitHub.

### 1. Certificado de Distribución de Apple (`.p12`)
1. Abre la aplicación **Acceso a Llaveros** (Keychain Access) en tu Mac.
2. Busca tu certificado **Apple Distribution** o **iPhone Distribution** activo.
3. Haz clic derecho sobre él y selecciona **Exportar "..."**.
4. Guárdalo con el nombre `certificado.p12` y asígnale una contraseña (recuerda esta contraseña, la usaremos más adelante).
5. Abre la **Terminal** en la carpeta donde guardaste el archivo y ejecutas:
   ```bash
   base64 -i certificado.p12 | pbcopy
   ```
   *(Esto copiará automáticamente el código base64 largo en tu portapapeles)*.

### 2. Perfil de Provisión (`.mobileprovision`)
1. Descarga tu perfil de provisión de App Store para este Bundle ID desde [developer.apple.com](https://developer.apple.com).
2. Abre la **Terminal** en la carpeta donde lo descargaste y ejecuta:
   ```bash
   base64 -i tu_perfil.mobileprovision | pbcopy
   ```
   *(Esto copiará automáticamente el código base64 del perfil en tu portapapeles)*.

---

## Paso 2: Crear una Clave API en App Store Connect

Para autenticar la subida a TestFlight desde la nube de forma automatizada:
1. Ve a [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
2. Ve a **Usuarios y acceso** ➔ pestaña **Claves de API**.
3. Haz clic en el botón **`+`** (Agregar clave API).
4. Dale un nombre (ej. `GitHub Actions`) y asígnale el rol de **Desarrollador** o **Gestor de apps**.
5. Copia los siguientes datos:
   * **Issuer ID** (ID de emisor - texto arriba de la tabla).
   * **Key ID** (ID de clave - texto en la tabla).
6. Descarga el archivo de clave privada (un archivo `.p8`). Abre este archivo `.p8` con cualquier editor de texto para copiar todo su contenido.

---

## Paso 3: Configurar los Secretos en GitHub

En la página de tu repositorio de GitHub:
1. Ve a la pestaña **Settings** (Configuración) de tu repositorio.
2. En la barra lateral izquierda, selecciona **Secrets and variables ➔ Actions**.
3. Haz clic en **New repository secret** para añadir cada una de estas variables:

| Nombre del Secreto | Valor a colocar |
| :--- | :--- |
| `APPLE_P12_BASE64` | Pega el código Base64 copiado en el paso del **Certificado** (`certificado.p12`). |
| `APPLE_P12_PASSWORD` | La contraseña de seguridad que le pusiste al exportar el archivo `.p12`. |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Pega el código Base64 copiado en el paso del **Perfil de Provisión** (`.mobileprovision`). |
| `APPSTORE_ISSUER_ID` | El **Issuer ID** copiado de App Store Connect. |
| `APPSTORE_KEY_ID` | El **Key ID** copiado de App Store Connect. |
| `APPSTORE_PRIVATE_KEY` | El contenido de texto completo del archivo `.p8` descargado. |

---

## Paso 4: Desencadenar la Compilación

Una vez configurados los secretos:
1. Cada vez que hagas `git push` a tu rama `main`, la compilación iniciará automáticamente.
2. Puedes ver el progreso en tiempo real entrando en la pestaña **Actions** en tu página de GitHub.
3. Al finalizar con éxito, el ejecutable final se enviará automáticamente a tu panel de **TestFlight** en App Store Connect listo para enviar a revisión.

---

### Notas Técnicas:
* El llavero temporal creado en la nube se configuró con la contraseña **`Television2012`** tal como lo solicitaste.
* El archivo de configuración de compilación virtual está listo en tu repositorio en la ruta: `.github/workflows/build-ios.yml`.
