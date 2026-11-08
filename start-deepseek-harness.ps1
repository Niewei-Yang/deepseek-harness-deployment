param([switch]$NoOpen, [switch]$NoPause, [int]$Port = 18080)
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$entry = Join-Path $appRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
$baseUrl = "http://127.0.0.1:$Port"
$stdoutLog = Join-Path $appRoot 'dsh-service.stdout.log'
$stderrLog = Join-Path $appRoot 'dsh-service.stderr.log'

function Test-HarnessPage([string]$Address, [switch]$AllowUnauthorized) {
    try {
        $response = Invoke-WebRequest -Uri $Address -UseBasicParsing -TimeoutSec 2
        return $response.StatusCode -eq 200
    } catch {
        if ($AllowUnauthorized -and $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
            return $true
        }
        return $false
    }
}

function Get-HarnessLaunchUrl {
    if (-not (Test-Path -LiteralPath $stdoutLog)) { return $null }
    try {
        # Empty redirected logs return null until the child writes its first line.
        $logText = [string](Get-Content -LiteralPath $stdoutLog -Raw -ErrorAction Stop)
        if ([string]::IsNullOrWhiteSpace($logText)) { return $null }
        $pattern = [regex]::Escape($baseUrl) + '/\?token=[^\s]+'
        $launchMatches = [regex]::Matches($logText, $pattern)
        if ($launchMatches.Count -gt 0) { return $launchMatches[$launchMatches.Count - 1].Value }
    } catch {
        # A concurrent log write is transient; the readiness loop retries.
    }
    return $null
}

Write-Host 'DeepSeek Harness launcher'
Write-Host ('Port: ' + $Port)
try {
    & (Join-Path $appRoot 'check-updates.ps1')
} catch {
    Write-Host 'Update check unavailable; launch will continue.' -ForegroundColor DarkYellow
}

$serviceEnabled = $false
$serviceProcess = $null
$mutex = $null
$ownsMutex = $false
try {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $rootHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($appRoot.ToLowerInvariant()))).Replace('-', '') }
    finally { $sha.Dispose() }
    $mutex = New-Object Threading.Mutex($false, ('Local\DeepSeekHarnessLauncher-' + $rootHash + '-' + $Port))
    try { $ownsMutex = $mutex.WaitOne(10000) }
    catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'Another launcher is still starting this service. Try again shortly.' }

    if (-not (Test-HarnessPage $baseUrl -AllowUnauthorized)) {
        Write-Host 'Starting service...'
        $node = (Get-Command node.exe -ErrorAction Stop).Source
        $serviceProcess = Start-Process -FilePath $node -ArgumentList @(('"' + $entry + '"'), '--profile', 'web', '--host', '127.0.0.1', '--port', $Port, '--no-open') -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru
        # Retain the process handle so Windows PowerShell can read its exit code.
        $null = $serviceProcess.Handle
    }

    Write-Host 'Waiting for the authenticated Web UI...'
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt 90) {
        if ($serviceProcess) {
            $serviceProcess.Refresh()
            if ($serviceProcess.HasExited) {
                if ($null -ne $serviceProcess.ExitCode) { throw ('The service exited during startup (exit code ' + $serviceProcess.ExitCode + ').') }
                throw 'The service exited during startup. Check the service error log.'
            }
        }
        $url = Get-HarnessLaunchUrl
        if (-not $url) { $url = $baseUrl }
        # A listening port or HTTP 401 alone is not a ready, usable launch URL.
        if (Test-HarnessPage $url) { $serviceEnabled = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $serviceEnabled) {
        throw 'The authenticated Web UI was not ready within 90 seconds. The service may still be starting; retry the launcher shortly.'
    }
    Write-Host 'Service enabled: YES'
    Write-Host ('Web UI: ' + $url)
    Write-Host 'You can close this window after the Web UI opens.'
    if (-not $NoOpen) { Start-Process -FilePath $url | Out-Null }
} catch {
    $serviceEnabled = $false
    Write-Host ('Launch failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Service output: ' + $stdoutLog)
    Write-Host ('Service errors: ' + $stderrLog)
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}

if (-not $NoPause) { Read-Host 'Press Enter to close' }
if (-not $serviceEnabled) { exit 1 }
