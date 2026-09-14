# Manual de Identidad Visual — Coro LLDM

Documento oficial con las especificaciones, reglas de diseño, códigos cromáticos, anatomía del emblema y lineamientos de plataforma para **Coro LLDM** (y su versión en inglés **TLOTW Choir**).

---

## 1. Filosofía y Posicionamiento de Marca

### Propósito Estratégico
Coro LLDM renueva su identidad visual para desmarcarse de cualquier competidor del sector (especialmente aquellos que adoptaron tonalidades verdes) y consolidar un lenguaje propio: **atemporal, festivo, sagrado y de alta gama**. 

Evoca la sensación de **luz de vela sobre papel marfil con suave destello metálico**. Es una estética de papelería noble, encuadernación clásica y respeto litúrgico combinada con la precisión de una aplicación móvil de última generación.

* **Lema Oficial (ES):** *«Tu coro, sus cantos, siempre contigo.»*
* **Subtítulo Descriptivo:** *«Partituras y audios de ensayo en un solo lugar.»*
* **Lema Oficial (EN):** *«Scores and rehearsal audio, all in one place.»*

---

## 2. Paleta Cromática Oficial

La paleta se apoya en un fondo cálido marfil que aporta luz y pureza, equilibrado con un ancla profunda color espresso y acentos metálicos dorados.

| Color | Código HEX | RGB | Función y Uso |
| :--- | :--- | :--- | :--- |
| **Marfil Vela** | `#F5F0E6` | `245, 240, 230` | **Fondo principal** de toda la identidad, papelería, web e iconos. Aporta luminosidad cálida sin encandilar. |
| **Oro Metálico Clásico** | `#D4AF37` | `212, 175, 55` | **Emblema sagrado**, logotipo, sellos y acentos principales de jerarquía. |
| **Oro Bronce Suave** | `#B08D57` | `176, 141, 87` | Líneas divisorias, badges secundarios de tiendas (`Google Play` / `App Store`) y detalles ornamentales. |
| **Deep Espresso** | `#3B2F2F` | `59, 47, 47` | **Ancla tipográfica principal**. Títulos, isotipos cuando se requiere máximo contraste y lectura formal. |
| **Espresso Suave** | `#5A4B4B` | `90, 75, 75` | Subtítulos, lemas y cuerpos de texto secundario. |
| **Blanco Puro** | `#FFFFFF` | `255, 255, 255` | Toques de luz, brillos discretos y limpieza. |

### Reglas de Uso del Color
* **Reserva de Oro:** El oro más brillante (`#D4AF37`) debe reservarse para el emblema, titulares y acentos finos para que las composiciones se mantengan livianas y distinguidas.
* **Prohibición de Verdes:** No utilizar tonalidades verdes de fondo ni en botones; la identidad se distingue por la calidez del marfil y la nobleza del espresso.

---

## 3. Anatomía del Emblema Sagrado

El imagotipo oficial fusiona la fe de la **Iglesia La Luz del Mundo** con el propósito del **canto coral**:

1. **El Libro Abierto (Base):** Representa las Sagradas Escrituras y el himnario oficial. Es el cimiento doctrinal y musical de donde brota la alabanza.
2. **La Lira Clásica (Cuerpo):** Símbolo de la música sacra, el ensamble coral y la armonía de las cuatro voces (Soprano, Contralto, Tenor y Bajo).
3. **La Llama Viva (Corazón):** Representa *"La Luz"*, el fuego de la fe viva y el testimonio espiritual.
4. **Las Ramas de Laurel (Marco Triunfal):** Flanquean el emblema simbolizando la victoria espiritual, la perseverancia y la conmemoración del Centenario.

### Criterios de Simplificación Aprobados
* **Sin alas:** Se eliminaron las alas de querubín para evitar pesadez y mantener trazos vectoriales puros.
* **Sin cuadrícula del mundo:** Se suprimieron las líneas de paralelos/meridianos del fondo para garantizar que el isotipo sea 100% legible a escalas diminutas (16×16 px o 32×32 px en navegadores).
* **Sin marcos cuadrados o bordes genéricos:** El emblema vive libremente sobre el fondo o contenido dentro del squircle oficial de la app, eliminando marcos añadidos que den sensación de icono prefabricado.

---

## 4. Tipografía Oficial

* **Titulares y Nombres de Marca:** Tipografía Serif de alto contraste editorial (`Playfair Display`, `Georgia`). Transmite herencia, música y tradición coral.
* **Textos de Interfaz y Redes:** Tipografía Sans-Serif geométrica y legible (`DM Sans`, `Arial`, `system-ui`).
* **Datos Técnicos y Monospace:** `DM Mono`.

---

## 5. Especificaciones Técnicas y Márgenes Seguros

### A. Icono de Aplicación (App Icon)
* **Archivo:** `website/public/social-kit/coro-lldm-app-icon-rounded.png`
* **Dimensiones:** `1024 × 1024 px`
* **Formato:** PNG con canal Alpha (32-bit ARGB).
* **Fondo interior:** Marfil Vela (`#F5F0E6`) con radio de curvatura oficial Squircle (`radius: 224px`).
* **Exterior:** `100% transparente` fuera de las esquinas redondeadas.
* **Emblema:** Proporción centrada de `760 × 760 px` en el lienzo.

### B. Avatar de Perfiles (YouTube, Instagram, TikTok, Facebook)
* **Archivo:** `website/public/social-kit/coro-lldm-perfil-redes.png`
* **Dimensiones:** `512 × 512 px`
* **Zona de Resguardo Circular:** El emblema está contenido en una caja de `340 × 340 px` centrada. Al ser recortado por las plataformas en un círculo perfecto, los laureles exteriores conservan un margen de resguardo de al menos 36 px sin cortarse.

### C. Banner de YouTube
* **Archivo:** `website/public/social-kit/coro-lldm-youtube-banner.png`
* **Dimensiones:** `2560 × 1440 px` (Proporción 16:9).
* **Zona Segura Central (Safe Area):** `1546 × 423 px` en el centro exacto del lienzo:
  * Eje X: de `507 px` a `2053 px`.
  * Eje Y: de `508 px` a `931 px`.
* Todo el texto, emblema y llamadas a la acción residen estrictamente dentro de esta zona. En pantallas móviles no se recorta información; en TV y Desktop se aprecia la extensión del degradado Marfil Vela.

### D. Banner de Facebook
* **Archivo:** `website/public/social-kit/coro-lldm-facebook-banner.png`
* **Dimensiones:** `1500 × 500 px`
* **Margen Lateral:** El bloque visual está centrado con márgenes de más de 140 px a los lados para evitar que la foto de perfil en la app móvil de Facebook o los botones de mensaje tapen el contenido.

### E. Social Preview para la Web (Open Graph)
* **Archivos:** 
  * Español: `website/public/social-preview.jpg` (y copia en `social-kit/coro-lldm-social-preview.jpg`)
  * Inglés: `website/public/social-preview-en.jpg` (y copia en `social-kit/tlotw-choir-social-preview.jpg`)
* **Dimensiones:** `1200 × 630 px` (Proporción 1.91:1 oficial para WhatsApp, Facebook, iMessage, LinkedIn y X).

### F. Marca de Agua para Videos (YouTube Video Watermark)
* **Archivo:** `website/public/social-kit/coro-lldm-watermark-youtube.png`
* **Dimensiones:** `512 × 512 px` (Escalable a 150×150 px por YouTube).
* **Composición:** Emblema en oro sobre Marfil Vela con recuadro dorado y texto «CORO LLDM - SUSCRÍBETE».

### G. Afiche Promocional Vertical
* **Archivo:** `website/public/social-kit/coro-lldm-promo.jpg`
* **Dimensiones:** `1080 × 1350 px` (Proporción 4:5 vertical para Feed de Instagram y Facebook).

---

## 6. Inventario de Archivos en el Repositorio

### Recursos Activos (`website/public/social-kit/`)
1. `coro-lldm-app-icon-rounded.png` — Icono maestro Squircle.
2. `coro-lldm-emblema-transparente.png` — Emblema vectorial puro en oro con transparencia.
3. `coro-lldm-perfil-redes.png` — Avatar para perfiles sociales.
4. `coro-lldm-youtube-banner.png` — Banner oficial para canal de YouTube.
5. `coro-lldm-facebook-banner.png` — Portada oficial para página de Facebook.
6. `coro-lldm-watermark-youtube.png` — Marca de agua para videos.
7. `coro-lldm-promo.jpg` — Afiche promocional vertical para publicaciones.
8. `coro-lldm-social-preview.jpg` — Preview web en español.
9. `tlotw-choir-social-preview.jpg` — Preview web en inglés.
10. `miniatura-youtube-el-aliento-de-mi-ser.jpg` — Miniatura de YouTube 16:9 con partitura real.
11. `miniatura-reels-tiktok-el-aliento-de-mi-ser.jpg` — Miniatura de Reels/TikTok 9:16.

### Recursos Web Públicos (`website/public/`)
Sincronizados en Marfil Vela y Oro:
* `app-icon.png` (512 × 512 px)
* `icon-512.png` (512 × 512 px - PWA)
* `icon-192.png` (192 × 192 px - PWA)
* `apple-touch-icon.png` (180 × 180 px - iOS Safari)
* `favicon-32.png` (32 × 32 px)
* `favicon-16.png` (16 × 16 px)
* `social-preview.jpg` (1200 × 630 px)
* `social-preview-en.jpg` (1200 × 630 px)

### Archivo Histórico de Respaldo (`website/public/social-kit/archivo-identidad-anterior/`)
Carpeta que resguarda todos los materiales verdes anteriores (`coro-lldm-01-catalogo.jpg` a `05-anotaciones.jpg`, banners antiguos, previews y experimentos iniciales).
