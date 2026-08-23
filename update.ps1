$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

git -C $root pull --ff-only
corepack pnpm install --dir $root --frozen-lockfile
Write-Host 'Deployment files and dependencies updated.'
