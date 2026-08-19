# Install / backup / restore script for the modified QuickLook build.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1        # install dist\QuickLook.exe
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -BackupOnly
#   powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -Restore
#
# -install   (default) backs up the current QuickLook.exe, swaps in the modified one,
#            enables Topmost and disables auto-update so the build is not overwritten.
# -Restore   restores the original exe from backup.
# -BackupOnly just copies the current exe to the backup folder.

param(
    [switch]$BackupOnly,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$qlDir = Join-Path $env:LOCALAPPDATA 'Programs\QuickLook'
$qlExe = Join-Path $qlDir 'QuickLook.exe'
$newExe = Join-Path $repoRoot 'dist\QuickLook.exe'
$configPath = Join-Path $env:APPDATA 'pooi.moe\QuickLook\QuickLook.config'
$backupDir = Join-Path $repoRoot 'backup'
$origExe = Join-Path $backupDir 'QuickLook.exe.orig'

if (-not (Test-Path $qlDir)) { throw "QuickLook not found at $qlDir" }

# --- backup ---
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
if (-not (Test-Path $origExe)) {
    Copy-Item $qlExe $origExe -Force
    Write-Host "Backed up original to $origExe"
}
if ($BackupOnly) { Write-Host 'BackupOnly done.'; exit }

# --- restore ---
if ($Restore) {
    if (Test-Path $origExe) {
        Stop-Process -Name QuickLook -Force -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Copy-Item $origExe $qlExe -Force
        Write-Host "Restored original exe. Starting QuickLook ..."
        Start-Process $qlExe
    } else {
        Write-Host 'No backup found, nothing to restore.'
    }
    exit
}

# --- install ---
if (-not (Test-Path $newExe)) { throw "Modified build not found at $newExe. Run scripts/build.ps1 first." }

Stop-Process -Name QuickLook -Force -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Copy-Item $newExe $qlExe -Force
Write-Host "Installed modified build to $qlExe"

# Topmost: keeps the preview window above browsers so mouse-hover navigation works.
if (Test-Path $configPath) {
    $xml = [xml](Get-Content $configPath -Raw)
    $topmost = $xml.Settings.SelectSingleNode('Topmost')
    if ($null -eq $topmost) {
        $node = $xml.CreateElement('Topmost')
        $node.InnerText = 'True'
        $xml.Settings.AppendChild($node) | Out-Null
    } else {
        $topmost.InnerText = 'True'
    }
    $update = $xml.Settings.SelectSingleNode('DisableAutoUpdateCheck')
    if ($null -eq $update) {
        $node = $xml.CreateElement('DisableAutoUpdateCheck')
        $node.InnerText = 'True'
        $xml.Settings.AppendChild($node) | Out-Null
    } else {
        $update.InnerText = 'True'
    }
    $xml.Save($configPath)
    Write-Host "Enabled Topmost + disabled auto-update in $configPath"
}

Start-Process $qlExe
Write-Host 'Install done. QuickLook restarted.'
