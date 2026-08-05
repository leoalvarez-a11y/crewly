[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$LauncherDirectory = $PSScriptRoot
$AssetsDirectory = Join-Path $LauncherDirectory 'assets'
$IconPath = Join-Path $AssetsDirectory 'crewly.ico'
$DesktopPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
$WScriptExecutable = Join-Path $env:WINDIR 'System32\wscript.exe'
$PowerShellExecutable = (Get-Process -Id $PID).Path
$Shell = New-Object -ComObject WScript.Shell

if (-not (Test-Path -LiteralPath $DesktopPath -PathType Container)) {
    throw "Windows no devolvió una ruta de escritorio válida."
}

function Set-CrewlyShortcut {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$Arguments,
        [Parameter(Mandatory)][string]$Description
    )

    $shortcutPath = Join-Path $DesktopPath $Name
    $shortcut = $Shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $LauncherDirectory
    $shortcut.Description = $Description
    if (Test-Path -LiteralPath $IconPath -PathType Leaf) {
        $shortcut.IconLocation = "$IconPath,0"
    }
    $shortcut.Save()
    return $shortcutPath
}

$startShortcut = Set-CrewlyShortcut `
    -Name 'Crewly.lnk' `
    -TargetPath $WScriptExecutable `
    -Arguments "`"$(Join-Path $LauncherDirectory 'Start-Crewly.vbs')`"" `
    -Description 'Iniciar Crewly y abrir el dashboard'

$stopShortcut = Set-CrewlyShortcut `
    -Name 'Detener Crewly.lnk' `
    -TargetPath $PowerShellExecutable `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $LauncherDirectory 'Stop-Crewly.ps1')`"" `
    -Description 'Detener Crewly'

$logsShortcut = Set-CrewlyShortcut `
    -Name 'Crewly Logs.lnk' `
    -TargetPath $PowerShellExecutable `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $LauncherDirectory 'Crewly-Logs.ps1')`"" `
    -Description 'Ver logs locales de Crewly'

Write-Output "DESKTOP_PATH=$DesktopPath"
Write-Output "CREWLY_SHORTCUT=$startShortcut"
Write-Output "STOP_SHORTCUT=$stopShortcut"
Write-Output "LOGS_SHORTCUT=$logsShortcut"
