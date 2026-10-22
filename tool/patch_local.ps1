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
    # it ends in another directory
    Set-Location $ProjectRoot

    # a missing registrant builds fine but hangs the app on the splash screen
    $registrant = "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
    if (-not (Test-Path $registrant)) {
        flutter pub get
        if (-not (Test-Path $registrant)) {
            throw "$registrant was not generated"
        }
    }

    # our own patches to dependencies: tool/patches/<package>_*.patch
    $packages = (Get-Content ".dart_tool/package_config.json" -Raw | ConvertFrom-Json).packages
    Get-ChildItem "tool/patches" -Filter *.patch | ForEach-Object {
        # the name before the first "_"; a "-" in it stands for "_"
        $name = $_.BaseName.Split("_")[0].Replace("-", "_")
        if ($name -eq "getx") { $name = "get" }
        $package = $packages | Where-Object { $_.name -eq $name }
        if (-not $package) { throw "package $name not found for $($_.Name)" }
        $dir = ([Uri]$package.rootUri).LocalPath
        # pub may unpack a package with CRLF line ends; the patches are LF.
        # The check fails when the patch is not applied yet, which "Stop"
        # would turn into an error that ends the script.
        $ErrorActionPreference = "Continue"
        git -C $dir apply --ignore-whitespace --check --reverse $_.FullName 2>$null
        $applied = $LASTEXITCODE -eq 0
        $ErrorActionPreference = "Stop"
        if ($applied) {
            Write-Host "$($_.Name) already applied"
            return
        }
        git -C $dir apply --ignore-whitespace $_.FullName
        if ($LASTEXITCODE -ne 0) { throw "$($_.Name) failed in $dir" }
        Write-Host "$($_.Name) applied"
    }
} finally {
    Pop-Location
}
