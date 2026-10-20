$ErrorActionPreference = 'Stop'
$revisionRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$deliveryRoot = [System.IO.Path]::GetFullPath('E:\MusescoreCantai')
$manifest = Get-Content -LiteralPath (Join-Path $revisionRoot 'delivery-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$audit = Get-Content -LiteralPath (Join-Path $revisionRoot 'final-all41-validation.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($manifest).Count -ne 23 -or @($audit).Count -ne 41) { throw 'Inventario de entrega incompleto.' }
if (@($audit | Where-Object { @($_.issues).Count -gt 0 }).Count -gt 0) { throw 'Hay verificaciones pendientes.' }
foreach ($entry in $manifest) {
    $sourcePath = [System.IO.Path]::GetFullPath($entry.source)
    $destinationPath = [System.IO.Path]::GetFullPath($entry.destination)
    if (-not $sourcePath.StartsWith($revisionRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Origen fuera de la carpeta revisada.' }
    if ([System.IO.Path]::GetDirectoryName($destinationPath) -ne $deliveryRoot -or [System.IO.Path]::GetExtension($destinationPath) -ne '.mscz') { throw 'Destino de entrega inesperado.' }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne $entry.sha256) { throw "El MSCZ revisado cambió: $sourcePath" }
    $currentHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($currentHash -ne $entry.originalHash -and $currentHash -ne $entry.sha256) { throw "El destino contiene cambios posteriores: $destinationPath" }
}
foreach ($entry in $manifest) {
    Copy-Item -LiteralPath $entry.source -Destination $entry.destination -Force
    $deliveredHash = (Get-FileHash -LiteralPath $entry.destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($deliveredHash -ne $entry.sha256) { throw "La copia no coincide: $($entry.destination)" }
}
$inventory = Get-Content -LiteralPath (Join-Path $revisionRoot 'inventory.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $inventory) {
    $expectedHash = $entry.originalHash
    $delivered = @($manifest | Where-Object { $_.index -eq $entry.index })
    if ($delivered.Count -eq 1) { $expectedHash = $delivered[0].sha256 }
    if ((Get-FileHash -LiteralPath $entry.destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw "Verificación final de carpeta fallida: $($entry.name)" }
}
$receipt = [ordered]@{ corrected = @($manifest).Count; verified = @($inventory).Count; directory = $deliveryRoot; time = (Get-Date).ToString('o'); files = @($manifest | ForEach-Object { [ordered]@{ destination = $_.destination; sha256 = $_.sha256 } }) }
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $revisionRoot 'delivery-receipt.json') -Encoding UTF8
Write-Output 'Entregados 23 MSCZ corregidos; verificados los 41 archivos de E:\MusescoreCantai.'
Get-ChildItem -LiteralPath $deliveryRoot -File | Group-Object Extension | Select-Object Name, Count
