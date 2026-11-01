param(
    [Parameter(Mandatory = $true)][string]$BundlePath,
    [double]$MinimumPercentage = 25,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$resolvedBundle = (Resolve-Path -LiteralPath $BundlePath).Path
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedBundle)
try {
    $entry = $archive.GetEntry('BUNDLE-METADATA/com.android.tools/r8.json')
    if ($null -eq $entry) { throw 'The bundle has no R8 metadata.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { $metadata = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }

    foreach ($property in @('noOptimizationPercentage', 'noObfuscationPercentage', 'noShrinkingPercentage')) {
        if ($null -eq $metadata.stats.$property) { throw "Missing R8 statistic: $property" }
    }
    $dexFiles = @($archive.Entries | Where-Object FullName -Match '\.dex$')
    $report = [pscustomobject]@{
        bundle = $resolvedBundle
        r8Version = $metadata.version
        optimization = [math]::Round(100 - $metadata.stats.noOptimizationPercentage, 2)
        obfuscation = [math]::Round(100 - $metadata.stats.noObfuscationPercentage, 2)
        shrinking = [math]::Round(100 - $metadata.stats.noShrinkingPercentage, 2)
        dexFiles = $dexFiles.Count
        dexBytes = ($dexFiles | Measure-Object Length -Sum).Sum
        optimizedResourceShrinking = $metadata.resourceOptimization.isOptimizedShrinkingEnabled
        minimumPercentage = $MinimumPercentage
    }
    if ($ReportPath) { $report | ConvertTo-Json | Set-Content -LiteralPath $ReportPath -Encoding utf8 }
    $report
    foreach ($category in @('optimization', 'obfuscation', 'shrinking')) {
        if ($report.$category -lt $MinimumPercentage) {
            throw "$category is $($report.$category)%, below $MinimumPercentage%."
        }
    }
} finally {
    $archive.Dispose()
}
