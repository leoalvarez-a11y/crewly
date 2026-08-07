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
if ($startContent -match 'wsl\.exe|/home/zytto|/mnt/c') {
    throw 'Start-Crewly.ps1 todavía depende de WSL.'
}
if ($startContent -notmatch 'dist\\backend\\backend\\src\\index\.js') {
    throw 'Start-Crewly.ps1 no apunta al backend nativo compilado.'
}
if ($startContent -notmatch 'CREWLY_HOME') {
    throw 'Start-Crewly.ps1 no configura el perfil nativo de Crewly.'
}
if ($startContent -notmatch "CREWLY_LOCAL_AUTH\s*=\s*'1'") {
    throw 'Start-Crewly.ps1 no habilita la autenticacion local restringida a loopback.'
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
