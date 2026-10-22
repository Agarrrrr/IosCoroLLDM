param(
    [string]$FlutterPath = 'flutter',
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $pubArgs = @('pub', 'get')
    if ($Offline) { $pubArgs += '--offline' }
    & $FlutterPath @pubArgs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar los plugins.' }

    $registrant = 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
    if (!(Test-Path -LiteralPath $registrant)) {
        throw 'Falta el registro nativo de plugins; se cancela la compilacion.'
    }
    # Let the release command regenerate tooling in release mode as well.
    # A standalone pub get can include dev-only plugins (integration_test).
    & $FlutterPath build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del AAB.' }

    & "$PSScriptRoot/verify_android_release.ps1" `
        -BundlePath 'build/app/outputs/bundle/release/app-release.aab'
} finally { Pop-Location }
