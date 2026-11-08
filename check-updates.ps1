param([switch]$Force, [switch]$AsObject)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$retryPath = Join-Path $root 'work\update-check-retry.json'
$requestAttempted = $false

function Compare-DshVersion([string]$Left, [string]$Right) {
    $a = $Left.Split('-', 2)
    $b = $Right.Split('-', 2)
    $core = ([version]$a[0]).CompareTo([version]$b[0])
    if ($core -ne 0) { return $core }
    if ($a.Count -eq 1 -and $b.Count -eq 1) { return 0 }
    if ($a.Count -eq 1) { return 1 }
    if ($b.Count -eq 1) { return -1 }
    $ap = $a[1].Split('.')
    $bp = $b[1].Split('.')
    for ($i = 0; $i -lt [Math]::Min($ap.Count, $bp.Count); $i++) {
        if ($ap[$i] -eq $bp[$i]) { continue }
        $an = $ap[$i] -match '^\d+$'
        $bn = $bp[$i] -match '^\d+$'
        if ($an -and $bn) { return ([decimal]$ap[$i]).CompareTo([decimal]$bp[$i]) }
        if ($an) { return -1 }
        if ($bn) { return 1 }
        return [string]::CompareOrdinal($ap[$i], $bp[$i])
    }
    return $ap.Count.CompareTo($bp.Count)
}

try {
    $installed = (Get-Content -LiteralPath (Join-Path $root 'node_modules\@deepseek-ai\dsh\package.json') -Raw | ConvertFrom-Json).version
    $cachePath = Join-Path $root 'work\update-check.json'
    $cache = $null
    if (Test-Path -LiteralPath $cachePath) {
        try { $cache = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json } catch { $cache = $null }
    }
    $now = [DateTimeOffset]::UtcNow
    $cacheFresh = $false
    if ($cache) {
        try {
            $age = $now - [DateTimeOffset]::Parse($cache.checkedUtc)
            $cacheFresh = $age.TotalSeconds -ge 0 -and $age.TotalHours -lt 24 -and $cache.latest -match '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$'
        } catch { $cacheFresh = $false }
    }
    if ($Force -or -not $cacheFresh) {
        if (-not $Force -and (Test-Path -LiteralPath $retryPath)) {
            $retryAfter = $null
            try {
                $retry = Get-Content -LiteralPath $retryPath -Raw | ConvertFrom-Json
                $retryAfter = [DateTimeOffset]::Parse($retry.retryAfterUtc)
            } catch { $retryAfter = $null }
            if ($retryAfter -and $retryAfter -gt $now) {
                if ($AsObject) { throw 'Update checks are temporarily unavailable. Use -Force to retry now.' }
                Write-Host 'Update check temporarily unavailable; retrying within one hour. Launch will continue.' -ForegroundColor DarkYellow
                return
            }
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $requestAttempted = $true
        $tags = Invoke-RestMethod -Uri 'https://registry.npmjs.org/-/package/@deepseek-ai%2Fdsh/dist-tags' -TimeoutSec 5
        if ($tags.latest -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw 'Invalid version in registry response.' }
        $cache = [pscustomobject]@{ latest = $tags.latest; checkedUtc = $now.ToString('o') }
        New-Item -ItemType Directory -Path (Split-Path $cachePath -Parent) -Force | Out-Null
        $cache | ConvertTo-Json | Set-Content -LiteralPath $cachePath -Encoding UTF8
    }
    $info = [pscustomobject]@{
        Installed = $installed
        Latest = $cache.latest
        UpdateAvailable = (Compare-DshVersion $cache.latest $installed) -gt 0
        CheckedUtc = $cache.checkedUtc
    }
    if ($AsObject) { return $info }
    if ($info.UpdateAvailable) {
        Write-Host ("Update available: {0} -> {1}" -f $installed, $info.Latest) -ForegroundColor Yellow
        Write-Host ('Run to upgrade: "' + (Join-Path $root 'update.cmd') + '"')
    } else {
        Write-Host ("DeepSeek Harness {0}: up to date (npm latest; checked at most daily)." -f $installed)
    }
} catch {
    if ($requestAttempted) {
        try {
            New-Item -ItemType Directory -Path (Split-Path $retryPath -Parent) -Force | Out-Null
            [pscustomobject]@{ retryAfterUtc = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $retryPath -Encoding UTF8
        } catch { }
    }
    if ($AsObject) { throw }
    Write-Host ('Update check unavailable; launch will continue. ' + $_.Exception.Message) -ForegroundColor DarkYellow
}
