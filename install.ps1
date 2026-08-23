$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    throw 'Node.js is required. Install Node.js 20 or newer, then run this script again.'
}

if (-not (Get-Command corepack.exe -ErrorAction SilentlyContinue)) {
    throw 'Corepack is required. Install a current Node.js release, then run this script again.'
}

corepack pnpm install --dir $root --frozen-lockfile
Write-Host 'DeepSeek Harness dependencies installed.'
