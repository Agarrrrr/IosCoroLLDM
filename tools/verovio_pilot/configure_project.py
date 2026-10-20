from pathlib import Path

root=Path('output/verovio_pilot')
(root/'pubspec.yaml').write_text('''name: coro_lldm
description: Prueba aislada de Verovio con fuentes propias.
publish_to: none
version: 0.1.0+1
environment:
  sdk: ^3.5.0
dependencies:
  flutter:
    sdk: flutter
  flutter_midi_pro: ^4.0.4
  audioplayers: ^6.0.0
  path_provider: ^2.1.4
  webview_flutter: ^4.13.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
flutter:
  uses-material-design: true
  assets:
    - assets/Piano.sf2
    - assets/audio/metro/
    - assets/reader/
    - assets/scores/
''',encoding='utf-8')
p=root/'android/app/build.gradle.kts'
s=p.read_text().replace('minSdk = flutter.minSdkVersion','minSdk = 24').replace('ndkVersion = flutter.ndkVersion','ndkVersion = "27.0.12077973"')
p.write_text(s)
p=root/'android/app/src/main/AndroidManifest.xml'
s=p.read_text().replace('android:label="coro_lldm"','android:label="Coro · Prueba lector"')
p.write_text(s,encoding='utf-8')
p=root/'android/gradle.properties'
s=p.read_text()
if 'kotlin.incremental=' not in s:s+='\nkotlin.incremental=false\n'
p.write_text(s)
