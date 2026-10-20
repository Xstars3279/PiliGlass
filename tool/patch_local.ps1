# Local (Windows) wrapper for lib/scripts/patch.ps1.
#
# The upstream script is written for GitHub Actions:
#   - it runs `git config --global user.name/email "ci"`, which would overwrite
#     the developer's global git identity;
#   - it relies on $env:GITHUB_WORKSPACE;
#   - for android it looks for the pub cache at ~/.pub-cache (Linux path).
# This wrapper runs a sanitized in-memory copy of the upstream script, so the
# patch list stays in sync with upstream.
#
# Usage (from the project root):  powershell -File tool/patch_local.ps1 [android]

param(
    [string]$platform = "android"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path "$PSScriptRoot/.."
$env:GITHUB_WORKSPACE = $ProjectRoot.Path

if (-not $env:FLUTTER_ROOT) {
    $env:FLUTTER_ROOT = Split-Path (Split-Path (Get-Command flutter).Source)
}
if (-not $env:PUB_CACHE) {
    throw "PUB_CACHE is not set; use a dedicated pub cache for this project"
}

# keep Flutter SDK sources LF so the LF patches apply after `git reset --hard`
git -C $env:FLUTTER_ROOT config core.autocrlf false

$script = Get-Content "$ProjectRoot/lib/scripts/patch.ps1" -Raw
$script = $script -replace '(?m)^git config --global .*$', ''
$script = $script -replace '\$PubCacheDir = "~/.pub-cache"', '$PubCacheDir = $env:PUB_CACHE'

Push-Location $ProjectRoot
try {
    & ([scriptblock]::Create($script)) -platform $platform

    # a missing registrant builds fine but hangs the app on the splash screen
    $registrant = "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
    if (-not (Test-Path $registrant)) {
        flutter pub get
        if (-not (Test-Path $registrant)) {
            throw "$registrant was not generated"
        }
    }
} finally {
    Pop-Location
}
