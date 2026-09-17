$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$entry = Join-Path $appRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
$port = 18080
$url = "http://127.0.0.1:$port"
$stdoutLog = Join-Path $appRoot 'dsh-service.stdout.log'
$stderrLog = Join-Path $appRoot 'dsh-service.stderr.log'

Write-Host 'DeepSeek Harness launcher'
Write-Host ('Port: ' + $port)

function Test-WebUi {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) { return $true }
        return $false
    }
}

$serviceEnabled = Test-WebUi

if (-not $serviceEnabled) {
    Write-Host 'Starting service...'
    try {
        $node = (Get-Command node.exe -ErrorAction Stop).Source
        Start-Process -FilePath $node -ArgumentList @(('"' + $entry + '"'), '--profile', 'web', '--host', '127.0.0.1', '--port', $port, '--no-open') -WorkingDirectory $appRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog | Out-Null
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            Start-Sleep -Seconds 1
            if (Test-WebUi) { break }
        }
        $serviceEnabled = Test-WebUi
    } catch {
        Write-Host ('Start error: ' + $_.Exception.Message)
    }
}

if ($serviceEnabled) {
    if (Test-Path -LiteralPath $stdoutLog) {
        $launchMatch = [regex]::Matches((Get-Content -LiteralPath $stdoutLog -Raw), 'http://127\.0\.0\.1:' + $port + '/\?token=[^\s]+')
        if ($launchMatch.Count -gt 0) { $url = $launchMatch[$launchMatch.Count - 1].Value }
    }
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
        Write-Host 'Service enabled: YES'
        Write-Host ('Web UI: ' + $url)
        Write-Host 'Use the complete URL above, including the token.'
        Start-Process -FilePath $url | Out-Null
    } catch {
        $serviceEnabled = $false
        Write-Host ('Could not open the Web UI: ' + $_.Exception.Message)
    }
} else {
    Write-Host 'Service enabled: NO'
    Write-Host ('DeepSeek Harness failed to start. Check Node.js and port ' + $port + '.')
}

Read-Host 'Press Enter to close'
if (-not $serviceEnabled) { exit 1 }
