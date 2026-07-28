# 🏗️ ARQUITECTURA FRONTEND Y ESTILOS

Este documento establece las reglas fundamentales de la interfaz (UI) de Coro LLDM, las metodologías de CSS y los patrones arquitectónicos visuales.

## 📂 1. Organización Reactiva sin Frameworks

En Coro LLDM **NO se utilizan** frameworks reactivos pesados (como React, Vue o Angular). En su lugar, utilizamos un patrón Vanilla JS con un Event Bus y `stateManager`.

### Módulos Funcionales
* **`src/features/dashboardUI.js`**: Implementa renderizado condicional. Suscribe un listener al Store global y repinta únicamente las listas (`ul`) cuando detecta cambios en las categorías o búsquedas. Contiene la lógica para la UI Mobile-First.
* **`src/features/jukeboxUI.js`**: Aísla la complejidad visual de la barra flotante inferior del reproductor (Play, Pausa, Progreso). Modifica el DOM directamente (`element.style.width = ...`) para que la barra de progreso a 60fps no penalice la memoria repintando componentes completos.

### CSS Modular y Puro (Vanilla)
* **Prohibido Tailwind / Bootstrap:** El control estético se realiza a mano mediante clases BEM (Block Element Modifier).
* **`/src/styles/components/`**: Módulos independientes como `modals.css`, `notifications.css`.
* **`/src/styles/gestor/`**: Panel de control administrativo con una cuadrícula (CSS Grid) estilo Dashboard.

---

## 🎨 2. Estándares de Diseño (Premium iOS)

El objetivo central es que la aplicación **no se sienta** como una página web, sino como una App Nativa de iOS de alta gama.

### Micro-interacciones Táctiles
* **Scale down:** Todo botón interactivo debe reducir su tamaño sutilmente al presionarse: `:active { transform: scale(0.96); }`.
* **Feedback Hóptico:** Uso explícito de `navigator.vibrate([200])` para acciones irreversibles y `[50, 50]` (Doble pulso) para notificaciones de éxito.
* **Highlight:** El clásico destello azul/gris de las webs al tocar un elemento está desactivado globalmente (`-webkit-tap-highlight-color: transparent`).

### Gestos Nativos
* **Banners (Swipe-to-Dismiss):** Los avisos y toasts pueden descartarse tirando de ellos hacia la derecha o hacia arriba. Esto se logra mapeando `touchstart`, `touchmove` y calculando el delta (`clientX` / `clientY`), aplicando un `transform: translateX(...)` fluido.

---

## 📝 3. El Motor de Anotaciones UI (v4.0.x)

Para la funcionalidad de poder "rayar" o tomar notas sobre la partitura de PDF.js, nos negamos rotundamente a usar Modales de HTML estándar o la función `prompt()`. En vez de eso, se implementó una **UI Flotante Inyectada**.

### Patrón de Inserción Absoluta
Cuando un usuario hace "Tap & Hold" sobre el lienzo (canvas) del PDF para agregar texto:
1. El `anotacionesManager.js` calcula las coordenadas `(X, Y)` relativas al documento, neutralizando el valor actual del Zoom o Scroll.
2. Se instancia y monta un elemento `<input type="text" class="input-anotacion-fantasma">`.
3. Se aplica `position: absolute; left: Xpx; top: Ypx;`.
4. El navegador enfoca el input automáticamente (`focus()`), abriendo el teclado en pantalla justo en ese punto exacto del documento.
5. Al detectar el evento `blur` (pierde enfoque) o la tecla `Enter`, el input se destruye del DOM y el texto resultante se transfiere permanentemente a las capas internas (paths) de la anotación.

### Bloqueo de Trazos por Pinch-to-Zoom
Para distinguir entre "Escribir un trazo" y "Hacer Zoom":
* El event listener intercepta `e.touches.length`.
* Si es `> 1` (Dos dedos), la bandera interna `isDrawing` se fuerza a `false` inmediatamente. Se cede el control absoluto al motor nativo del navegador o al `pdfEngine` para escalar el viewport sin rayar la página accidentalmente.
