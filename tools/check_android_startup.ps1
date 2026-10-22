param(
    [Parameter(Mandatory = $true)][string]$AdbPath,
    [string]$Package = 'com.lldm.coro',
    [string]$EvidenceDir = 'build/releases/startup-check',
    [int]$Attempts = 3
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
$EvidenceDir = (Resolve-Path -LiteralPath $EvidenceDir).Path
function Invoke-Adb {
    param([string[]]$Arguments)
    $result = & $AdbPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return ($result -join "`n")
}

$report = @()
for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    Invoke-Adb @('shell', 'am', 'force-stop', $Package) | Out-Null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Adb @('shell', 'am', 'start', '-W', '-n', "$Package/.MainActivity") | Out-Null
    $appProcessId = (Invoke-Adb @('shell', 'pidof', $Package)).Trim()
    $ready = $false
    for ($poll = 0; $poll -lt 5; $poll++) {
        Invoke-Adb @('shell', 'uiautomator', 'dump', '/sdcard/coro-release-startup.xml') | Out-Null
        $screen = Invoke-Adb @('shell', 'cat', '/sdcard/coro-release-startup.xml')
        $screen | Set-Content -LiteralPath "$EvidenceDir/startup-$attempt.xml" -Encoding utf8
        [xml]$hierarchy = $screen
        $searchInputs = $hierarchy.SelectNodes("//node[@package='$Package' and @class='android.widget.EditText']")
        $songCards = $hierarchy.SelectNodes("//node[@package='$Package' and @class='android.widget.ScrollView']//node[@class='android.view.View' and @clickable='true' and string-length(@content-desc)>0]")
        if ($searchInputs.Count -gt 0 -and $songCards.Count -gt 0) {
            $ready = $true
            break
        }
    }
    $watch.Stop()
    $log = Invoke-Adb @('logcat', '-d', "--pid=$appProcessId", '-v', 'brief')
    $log | Set-Content -LiteralPath "$EvidenceDir/startup-$attempt.log" -Encoding utf8
    Invoke-Adb @('shell', 'screencap', '-p', '/sdcard/coro-release-startup.png') | Out-Null
    Invoke-Adb @('pull', '/sdcard/coro-release-startup.png', "$EvidenceDir/startup-$attempt.png") | Out-Null
    $fatal = $log -match 'MissingPluginException|Unhandled Exception|FATAL EXCEPTION|could not find.*GeneratedPluginRegistrant'
    $report += [pscustomobject]@{
        attempt = $attempt
        processId = $appProcessId
        dashboardVisible = $ready
        fatalStartupError = $fatal
        elapsedSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
    }
    $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$EvidenceDir/report.json" -Encoding utf8
    if (!$ready -or $fatal) { throw "Fallo el arranque $attempt. Revisar evidencias en $EvidenceDir" }
    Write-Output "Arranque ${attempt}: catalogo visible, sin errores fatales ($($watch.Elapsed.TotalSeconds.ToString('F1')) s)."
}
Invoke-Adb @('shell', 'rm', '-f', '/sdcard/coro-release-startup.xml', '/sdcard/coro-release-startup.png') | Out-Null
