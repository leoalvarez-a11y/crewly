[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$launcherFiles = @(
    'Start-Crewly.ps1',
    'Stop-Crewly.ps1',
    'Crewly-Logs.ps1',
    'Install-CrewlyShortcuts.ps1'
)

foreach ($name in $launcherFiles) {
    $path = Join-Path $PSScriptRoot $name
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "$name contiene errores de sintaxis: $($errors.Message -join '; ')"
    }
}

$startContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-Crewly.ps1') -Raw
if ($startContent -notmatch '/home/zytto/crewly/source/scripts/crewly-local-start\.sh') {
    throw 'Start-Crewly.ps1 no apunta al checkout WSL oficial.'
}
if ($startContent -notmatch 'Start-Process \$DashboardUrl') {
    throw 'Start-Crewly.ps1 no abre el dashboard.'
}

$installerContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Install-CrewlyShortcuts.ps1') -Raw
if ($installerContent -notmatch 'GetFolderPath') {
    throw 'El instalador no detecta el escritorio mediante la API de Windows.'
}
if ($installerContent -notmatch 'Iniciar Crewly y abrir el dashboard') {
    throw 'Falta la descripción requerida para Crewly.lnk.'
}

$vbsContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-Crewly.vbs') -Raw
if ($vbsContent -notmatch 'shell\.Run\(command, 0, True\)') {
    throw 'Start-Crewly.vbs no oculta la consola.'
}

Write-Output 'Windows launcher checks passed.'
