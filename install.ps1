$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodeMinimum = [version]'22.19.0'

function Read-YesNo($prompt) {
    do {
        $answer = ([string](Read-Host "$prompt [Y/N]")).Trim().ToUpperInvariant()
    } while ($answer -notin @('Y', 'N', ''))
    return $answer -eq 'Y'
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Get-NodeInfo {
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $nodeCommand) {
        return $null
    }

    $rawVersion = (& $nodeCommand.Source --version 2>$null | Select-Object -First 1)
    $versionText = ([string]$rawVersion).Trim() -replace '^v', ''
    try {
        $version = [version]$versionText
    } catch {
        return $null
    }

    return [pscustomobject]@{
        Command = $nodeCommand.Source
        Version = $version
    }
}

function Install-Node {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'winget is unavailable. Install Node.js 22.19.0 or newer manually, then run install.cmd again.'
    }

    $nodeInfo = Get-NodeInfo
    if ($nodeInfo) {
        & $winget.Source upgrade --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
    } else {
        & $winget.Source install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Node.js installation did not complete successfully.'
    }
    Refresh-Path
}

function Ensure-Node {
    $nodeInfo = Get-NodeInfo
    if ($nodeInfo -and $nodeInfo.Version -ge $nodeMinimum) {
        Write-Host ("Node.js $($nodeInfo.Version) detected.")
        return
    }

    if ($nodeInfo) {
        Write-Host ("Node.js $($nodeInfo.Version) is older than required $nodeMinimum.")
    } else {
        Write-Host 'Node.js 22.19.0 or newer was not detected.'
    }

    if (-not (Read-YesNo 'Install or upgrade Node.js automatically using winget?')) {
        throw 'Node.js 22.19.0 or newer is required.'
    }
    Install-Node

    $nodeInfo = Get-NodeInfo
    if (-not $nodeInfo -or $nodeInfo.Version -lt $nodeMinimum) {
        throw 'Node.js 22.19.0 or newer was not found after installation. Restart the terminal and run install.cmd again.'
    }
    Write-Host ("Node.js $($nodeInfo.Version) is ready.")
}

function Ensure-Corepack {
    Refresh-Path
    $corepack = Get-Command corepack.cmd -ErrorAction SilentlyContinue
    if ($corepack) {
        $pnpmVersion = (& $corepack.Source pnpm --version 2>$null | Select-Object -First 1)
        if ($pnpmVersion) {
            $script:PackageManager = $corepack.Source
            $script:PackageManagerPrefix = @('pnpm')
            Write-Host 'Corepack and pnpm are ready.'
            return
        }
        & $corepack.Source enable
        if ($LASTEXITCODE -eq 0) {
            $script:PackageManager = $corepack.Source
            $script:PackageManagerPrefix = @('pnpm')
            Write-Host 'Corepack and pnpm are ready.'
            return
        }
    }

    $pnpm = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if ($pnpm) {
        $script:PackageManager = $pnpm.Source
        $script:PackageManagerPrefix = @()
        Write-Host 'pnpm is ready.'
        return
    }

    Write-Host 'Corepack and pnpm were not detected.'
    if (-not (Read-YesNo 'Install Corepack automatically using npm?')) {
        throw 'Corepack or pnpm is required to install dependencies.'
    }
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npm) {
        throw 'npm was not found. Repair the Node.js installation, then run install.cmd again.'
    }
    & $npm.Source install --global corepack@latest
    if ($LASTEXITCODE -ne 0) {
        throw 'Corepack installation did not complete successfully.'
    }
    Refresh-Path
    $corepack = Get-Command corepack.cmd -ErrorAction SilentlyContinue
    if (-not $corepack) {
        throw 'Corepack is still unavailable after installation.'
    }
    $script:PackageManager = $corepack.Source
    $script:PackageManagerPrefix = @('pnpm')
    Write-Host 'Corepack and pnpm are ready.'
}

function Install-Dependencies {
    $arguments = @($script:PackageManagerPrefix) + @('install', '--dir', $root, '--frozen-lockfile')
    & $script:PackageManager @arguments
    if ($LASTEXITCODE -ne 0) {
        throw 'Dependency installation failed. Check the network connection and run install.cmd again.'
    }
    Write-Host 'DeepSeek Harness dependencies installed.'
}

function Install-Shortcut {
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $shortcutPath = Join-Path $startMenu 'DeepSeek Harness.lnk'
    $launcher = Join-Path $root 'start-deepseek-harness.cmd'
    $icon = Join-Path $root 'deepseek-harness-official-black.ico'

    if (-not (Test-Path -LiteralPath $launcher)) {
        throw 'The launcher file is missing from the deployment directory.'
    }
    if (-not (Test-Path -LiteralPath $icon)) {
        throw 'The official icon file is missing from the deployment directory.'
    }

    if ([System.IO.File]::Exists($shortcutPath)) {
        [System.IO.File]::Delete($shortcutPath)
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $env:ComSpec
    $shortcut.Arguments = '/k call "' + $launcher + '"'
    $shortcut.WorkingDirectory = $root
    $shortcut.IconLocation = $icon + ',0'
    $shortcut.WindowStyle = 1
    $shortcut.Description = 'Launch DeepSeek Harness'
    $shortcut.Save()

    $ie4uinit = Join-Path $env:SystemRoot 'System32\ie4uinit.exe'
    if (Test-Path -LiteralPath $ie4uinit) {
        & $ie4uinit -ClearIconCache
    }
    Write-Host 'Start Menu shortcut installed.'
}

try {
    Ensure-Node
    Ensure-Corepack
    Install-Dependencies
    Install-Shortcut
    Write-Host ''
    Write-Host 'Installation complete.' -ForegroundColor Green
    Write-Host 'Open Start Menu and launch DeepSeek Harness.'
} catch {
    Write-Host ''
    Write-Host ('Installation failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
