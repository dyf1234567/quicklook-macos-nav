# Build script for the macOS-style navigation QuickLook build.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/build.ps1 [-RepoPath <dir>] [-SkipSdkInstall]
#
# What it does:
#   1. Installs .NET SDK 9 to %LOCALAPPDATA%\dotnet if missing (unless -SkipSdkInstall).
#   2. Clones the official QuickLook repo at tag 4.5.0 (unless the repo already exists).
#   3. Applies patches/quicklook-4.5.0-macos-nav.patch.
#   4. Builds QuickLook.csproj (Release / AnyCPU) and copies QuickLook.exe to dist/.

param(
    [string]$RepoPath = "$PSScriptRoot\..\ql-src-build",
    [switch]$SkipSdkInstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$dotnetDir = Join-Path $env:LOCALAPPDATA 'dotnet'
$dotnet = Join-Path $dotnetDir 'dotnet.exe'

# 1. SDK
if (-not (Test-Path $dotnet) -and -not $SkipSdkInstall) {
    Write-Host "Installing .NET SDK 9 ..."
    $installer = Join-Path $env:TEMP 'dotnet-install.ps1'
    Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $installer -UseBasicParsing
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Channel 9.0 -InstallDir $dotnetDir
    if ($LASTEXITCODE -ne 0) { throw 'SDK install failed' }
} elseif (-not (Test-Path $dotnet)) {
    throw '.NET SDK not found. Run without -SkipSdkInstall or install it manually.'
}
Write-Host "Using $dotnet $(& $dotnet --version)"

# 2. Repo
if (-not (Test-Path (Join-Path $RepoPath 'QuickLook.slnx'))) {
    Write-Host "Cloning QuickLook 4.5.0 ..."
    git clone --depth 1 --branch 4.5.0 https://github.com/QL-Win/QuickLook.git $RepoPath
    if ($LASTEXITCODE -ne 0) { throw 'clone failed' }
}

# 3. Patch (idempotent: skip files that already contain the marker)
$patchFile = Join-Path $repoRoot 'patches\quicklook-4.5.0-macos-nav.patch'
Push-Location $RepoPath
$marker = 'macOS-like mouse-hover capture'
$hasPatch = Select-String -Path 'QuickLook\KeystrokeDispatcher.cs' -Pattern $marker -Quiet
if (-not $hasPatch) {
    Write-Host "Applying patch ..."
    git apply --verbose $patchFile
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'patch apply failed' }
} else {
    Write-Host "Patch already applied, skipping."
}

# 4. Build
Write-Host "Building Release ..."
& $dotnet build 'QuickLook\QuickLook.csproj' -c Release -p:Platform=AnyCPU '-p:PreBuildEvent='
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'build failed' }
Pop-Location

$outExe = Join-Path $repoRoot 'dist\QuickLook.exe'
$builtExe = Join-Path $RepoPath 'Build\Release\QuickLook.exe'
Copy-Item $builtExe $outExe -Force
Write-Host "OK. Build output: $outExe"
