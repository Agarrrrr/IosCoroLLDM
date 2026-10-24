# Verificación de releases Android

En una copia nueva del proyecto, ejecutar `flutter pub get` antes de compilar.
Este paso genera también `GeneratedPluginRegistrant.java`: copiar solamente
`.dart_tool/package_config.json` y `.flutter-plugins-dependencies` no lo sustituye.
Sin ese registro el AAB puede compilar y firmarse, pero fallar al inicializar
`path_provider` y quedar en el splash nativo.

```powershell
./tools/build_android_release.ps1
```

El script ejecuta `flutter pub get`, comprueba el registro nativo, compila y
verifica que el AAB contenga esa clase. Acepta `-FlutterPath` para indicar el
ejecutable de Flutter y `-Offline` para resolver desde la caché local.

Antes de entregar un AAB, verificar su versión y firma, generar los APKs desde
ese mismo AAB con bundletool e instalarlos conservando los datos existentes.
Comprobar varios arranques en frío, el acceso al catálogo, la apertura de una
partitura y la reproducción. Guardar las evidencias de arranque y los errores
de logcat. La compilación y las pruebas de widgets no verifican este arranque.

```powershell
./tools/check_android_startup.ps1 -AdbPath /ruta/al/adb.exe -EvidenceDir build/releases/startup-check
```

Este control exige la pantalla desbloqueada y un catálogo con cantos. Verifica
el campo de búsqueda y las tarjetas de canciones mediante la jerarquía de
accesibilidad; guarda capturas, logcat y un informe JSON de tres arranques.

Si Google Play firma la app instalada con otra clave, no se debe desinstalar
para forzar la actualización local. Generar y verificar los APKs del AAB y
probar el código en una instalación aislada mediante la propiedad Gradle
`performanceAudit`. En ese caso el chequeo de arranque admite
`-Package com.lldm.coro.perfaudit -Activity com.lldm.coro.MainActivity`.
Registrar esta limitación y completar después la prueba de actualización
mediante una pista de pruebas de Google Play con el AAB de producción.
