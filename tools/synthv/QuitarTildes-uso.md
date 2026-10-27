# Quitar tildes y recalcular pronunciación

En Synthesizer V Studio 2, abre **Scripts → Cantai - Quitar tildes y recalcular pronunciacion**.
Si no aparece, usa **Scripts → Rescan**.

Elige el alcance (selección, grupo abierto, pista o todo el proyecto) y una operación:

- **SOLO las notas con tildes**: trata á, é, í, ó, ú y sus mayúsculas.
- **TODAS las notas con letra**: también recalcula las que ya estaban escritas sin tildes y conservaban fonemas manuales anteriores.
- **Restaurar**: recupera letra, idioma, fonemas y ajustes individuales anteriores al script. Conserva las ediciones posteriores que detecte.

La letra conserva ñ, ü, espacios y puntuación. No cambia alturas, duraciones, entradas ni dinámicas. Recalcula en español y sustituye los ajustes individuales de los fonemas en las notas tratadas. No guarda el proyecto.

La consulta se realiza en un grupo temporal silenciado que se retira al terminar. Se recoge la palabra completa: una consulta de una sola sílaba puede devolver solo el principio de «yoes».

La versión 3 se comprobó en Studio 2.2.1 con Choir Voices #2, versión 202. Incluye una solución para la omisión de ñ y ü en la consulta del motor: se usan grafías auxiliares únicamente en la prueba silenciada y se valida la presencia de sus sonidos. La letra visible conserva sus caracteres originales.

Si no obtiene una pronunciación fiable, conserva la nota y lo indica en el resultado. Esto incluye las cadenas de varias sílabas con + y ñ/ü que requieren conservar la distribución entre notas: no fuerza toda la palabra sobre su primera nota. Las continuaciones manuales de consonante final, como n, se conservan.

Las comprobaciones verifican los fonemas obtenidos y que no cambien notas ni tiempos; no constituyen una evaluación auditiva de cada voz disponible.
