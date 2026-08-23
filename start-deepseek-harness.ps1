$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$entry = Join-Path $appRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
$port = 18080
$url = "http://127.0.0.1:$port"

Write-Host 'DeepSeek Harness launcher'
Write-Host ('Port: ' + $port)

function Test-WebUi {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    } catch {
        return $false
    }
}

$serviceEnabled = Test-WebUi
Write-Host ('Service enabled: ' + $(if ($serviceEnabled) { 'YES' } else { 'NO' }))

if (-not $serviceEnabled) {
    Write-Host 'Starting service...'
    try {
        $node = (Get-Command node.exe -ErrorAction Stop).Source
        Start-Process -FilePath $node -ArgumentList @($entry, '--profile', 'web', '--host', '127.0.0.1', '--port', $port, '--no-open') -WorkingDirectory $appRoot -WindowStyle Hidden | Out-Null
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
    Write-Host 'Service enabled: YES'
    Write-Host ('Web UI: ' + $url)
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $url | Out-Null
} else {
    Write-Host 'Service enabled: NO'
    Write-Host ('DeepSeek Harness failed to start. Check Node.js and port ' + $port + '.')
}

Read-Host 'Press Enter to close'
if (-not $serviceEnabled) { exit 1 }
