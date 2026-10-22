param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$resolvedBundle = (Resolve-Path -LiteralPath $BundlePath).Path
$bundle = [System.IO.Compression.ZipFile]::OpenRead($resolvedBundle)
try {
    $manifest = $bundle.GetEntry('base/manifest/AndroidManifest.xml')
    if ($null -eq $manifest) { throw 'El archivo no contiene un manifiesto AAB.' }

    # Flutter loads this class by reflection. A release may compile successfully
    # without it, then fail on path_provider before the native splash is removed.
    $hasRegistrant = $false
    foreach ($entry in $bundle.Entries | Where-Object {
        $_.FullName -match '^base/dex/classes[0-9]*\.dex$'
    }) {
        $reader = [System.IO.StreamReader]::new(
            $entry.Open(), [System.Text.Encoding]::GetEncoding(28591))
        try {
            if ($reader.ReadToEnd().Contains(
                'Lio/flutter/plugins/GeneratedPluginRegistrant;')) {
                $hasRegistrant = $true
                break
            }
        } finally { $reader.Dispose() }
    }
    if (!$hasRegistrant) {
        throw ('AAB rechazado: falta GeneratedPluginRegistrant. ' +
            'Ejecuta flutter pub get en el proyecto de compilacion y recompila. ' +
            'No basta con copiar package_config.json y usar --no-pub.')
    }
    Write-Output "Registro nativo de plugins verificado: $resolvedBundle"
} finally { $bundle.Dispose() }
