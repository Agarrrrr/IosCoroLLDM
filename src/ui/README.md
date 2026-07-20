# 🎨 Capa UI (Interfaz y Eventos)
**Propósito:** Controlar lo que el usuario ve y toca.
**Reglas de la carpeta:**
1. **Cero Consultas Directas:** Ningún archivo aquí debe llamar a `supabase.from()`. Deben pedirle los datos a `main.js` o a la capa `api/`.
2. **Delegación de Eventos:** Preferir *Event Delegation* en listas dinámicas (como la lista de cantos) en lugar de agregar un *Listener* a cada elemento.
3. **Puros Renders:** Los módulos aquí (como `buscador.js` o `visor.js`) deben recibir datos (Arrays/Objetos) y devolver o actualizar elementos del DOM.