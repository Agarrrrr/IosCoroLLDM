# Historial de cambios

## 3.1.0

### Reproductor y estudio

- Tempo musical expresado en negras por minuto: ♩ = BPM.
- Nuevo deslizador de velocidad de 0.50x a 2.00x, con ajustes de 0.05x.
- Cambios de velocidad fluidos que conservan el punto de reproducción.
- Control de volumen recalibrado para mejorar el balance entre voces.

### Exportación de audio

- Corregida la exportación de alto, tenor, bajo y otras voces en cantos como
  **Canten a Cristo Rey**, donde anteriormente solo se podía exportar soprano.
- Corregida la lectura de eventos MIDI con estado omitido (*running status*)
  al conservar el tempo y el compás de las exportaciones individuales.
- Actualizada la caché de exportaciones para generar los archivos con la corrección.

### Sincronización y cuenta

- Mejoras en el reconocimiento de la suscripción entre dispositivos.
- Nuevas opciones en Ajustes para restaurar compras y vincular dispositivos.

### Rendimiento y almacenamiento

- Mejoras de estabilidad y respuesta de la aplicación.
- Guardado y carga de anotaciones extensas en un isolate secundario.
- Optimización del espacio ocupado por el repertorio offline.
- Incorporados los PDF y MIDI que faltaban en los recursos offline del catálogo.

### Compendio USA 2026

- My Divine Jesus Christ — con audio.
- One More Year Has Gone — con audio.
- The Centuries Have Passed By — con audio.
- The Great Potter.
- Ring the Bells of Heaven (Baptism).

### Partituras renovadas

- **Juventud:** partitura digital redibujada desde cero, con mayor nitidez y
  mejor contraste para la lectura en pantalla.

### Audios de ensayo incorporados

- Ángel Poderoso
- En Nuestro México
- Glory Unto Jesus Christ
- Señor Jesus tu Eres mi Esperanza
- A Jesucristo Rendid
- Del Cielo Descienden
- Qué Gran Amor
- De su Mano
- A ti Solo Nuestro Rey
- Bendice a mi Señor
- Mi Ejemplo a Seguir
- Vamos!
- Regresa al Hogar
- Amor Celestial

### Verificación de la corrección MIDI

- Pruebas de regresión para las cuatro voces de **Canten a Cristo Rey** y para
  eventos MIDI con uno y dos bytes de datos que utilizan *running status*.
- Preparación de exportaciones individuales comprobada en 412 MIDI y 1.663
  voces. Esta verificación no sustituye la escucha del MP3 en un dispositivo.
