param([switch]$CheckOnly, [string]$Version)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($CheckOnly) {
    & (Join-Path $root 'check-updates.ps1') -Force
    return
}
$lock = $null
$swapped = $false
$oldMoved = $false
$restart = $false
$backup = $null
$node = (Get-Command node.exe -ErrorAction Stop).Source
$entry = Join-Path $root 'node_modules\@deepseek-ai\dsh\lib\bin.js'

function Start-HarnessService {
    Start-Process -FilePath $node -ArgumentList @(('"' + $entry + '"'), 'web', '--host', '127.0.0.1', '--port', '18080', '--no-open') -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'dsh-service.stdout.log') -RedirectStandardError (Join-Path $root 'dsh-service.stderr.log') | Out-Null
}

try {
    New-Item -ItemType Directory -Path (Join-Path $root 'work') -Force | Out-Null
    $lock = [IO.File]::Open((Join-Path $root 'work\update.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $info = & (Join-Path $root 'check-updates.ps1') -Force -AsObject
    $target = $info.Latest
    if ($Version) { $target = $Version }
    if ($target -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw 'Invalid release version.' }
    if ($target -eq $info.Installed) { Write-Host ('Already installed: ' + $target); return }
    $nodeVersion = [version]((& $node --version).TrimStart('v'))
    if ($nodeVersion -lt [version]'24.9.0') { throw 'Node.js 24.9 or newer is required.' }
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $stage = Join-Path $root ('work\update-stage-' + $stamp)
    $backup = Join-Path $root ('work\upgrade-backup-' + $stamp)
    New-Item -ItemType Directory -Path $stage, $backup -Force | Out-Null
    $manifest = Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw | ConvertFrom-Json
    $manifest.dependencies.'@deepseek-ai/dsh' = $target
    $manifest.packageManager = 'pnpm@11.28.5'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $stage 'package.json') -Encoding UTF8
    @'
allowBuilds:
  '@deepseek-ai/dsh-subprocess-local': true
  '@google/genai': true
  koffi: true
  node-pty: true
  protobufjs: true
'@ | Set-Content -LiteralPath (Join-Path $stage 'pnpm-workspace.yaml') -Encoding UTF8
    $corepack = (Get-Command corepack.cmd -ErrorAction Stop).Source
    Write-Host ('Installing release in staging: ' + $target)
    & $corepack pnpm@11.28.5 install --dir $stage --registry=https://registry.npmjs.org --reporter=append-only
    if ($LASTEXITCODE -ne 0) { throw 'Staged installation failed; current installation is untouched.' }
    $reported = & $node (Join-Path $stage 'node_modules\@deepseek-ai\dsh\lib\bin.js') --version
    if ($LASTEXITCODE -ne 0 -or ([string]$reported).Trim() -ne $target) { throw 'Staged version verification failed.' }

    $listeners = @(Get-NetTCPConnection -LocalPort 18080 -State Listen -ErrorAction SilentlyContinue)
    $servicePids = @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($servicePid in $servicePids) {
        $process = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $servicePid)
        if (-not $process -or $process.Name -ne 'node.exe' -or -not $process.CommandLine.Contains($entry)) {
            throw 'Port 18080 belongs to another program; it will not be stopped.'
        }
    }
    foreach ($servicePid in $servicePids) {
        Stop-Process -Id $servicePid -ErrorAction Stop
        $restart = $true
        Wait-Process -Id $servicePid -Timeout 15 -ErrorAction SilentlyContinue
    }
    Get-ChildItem -LiteralPath $root -File -Force | Copy-Item -Destination $backup
    $dataHome = $env:DSH_HOME
    if (-not $dataHome) { $dataHome = Join-Path $env:USERPROFILE '.dsh' }
    if (Test-Path -LiteralPath $dataHome) {
        & robocopy.exe $dataHome (Join-Path $backup 'user-data') /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
        if ($LASTEXITCODE -ge 8) { throw 'User data backup failed.' }
    }
    # All move targets are fixed descendants of this deployment directory.
    $modulePath = Join-Path $root 'node_modules'
    $backupModules = Join-Path $backup 'node_modules'
    foreach ($path in @($modulePath, $backupModules, (Join-Path $stage 'node_modules'))) {
        if (-not [IO.Path]::GetFullPath($path).StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Move target escaped deployment directory.' }
    }
    Move-Item -LiteralPath $modulePath -Destination $backupModules
    $oldMoved = $true
    # pnpm uses absolute Windows junctions. Keep the release at its original path.
    New-Item -ItemType Junction -Path $modulePath -Target (Join-Path $stage 'node_modules') | Out-Null
    $swapped = $true
    Copy-Item -LiteralPath (Join-Path $stage 'package.json'), (Join-Path $stage 'pnpm-lock.yaml'), (Join-Path $stage 'pnpm-workspace.yaml') -Destination $root -Force
    $reported = & $node $entry --version
    if ($LASTEXITCODE -ne 0 -or ([string]$reported).Trim() -ne $target) { throw 'Installed version verification failed.' }
    Write-Host ('Updated to ' + $target) -ForegroundColor Green
    Write-Host ('Backup: ' + $backup)
    if ($restart) { Start-HarnessService; $restart = $false }
    Write-Host 'Open DeepSeek Harness from the Start Menu. Previous releases and data remain in the backup.'
} catch {
    $failure = $_
    if ($oldMoved) {
        if ($swapped -and (Test-Path -LiteralPath (Join-Path $root 'node_modules'))) {
            Move-Item -LiteralPath (Join-Path $root 'node_modules') -Destination (Join-Path $stage 'failed-node_modules')
        }
        Move-Item -LiteralPath (Join-Path $backup 'node_modules') -Destination (Join-Path $root 'node_modules')
        Copy-Item -LiteralPath (Join-Path $backup 'package.json'), (Join-Path $backup 'pnpm-lock.yaml') -Destination $root -Force
    }
    if ($restart) { Start-HarnessService }
    throw $failure
} finally {
    if ($lock) { $lock.Dispose() }
}
