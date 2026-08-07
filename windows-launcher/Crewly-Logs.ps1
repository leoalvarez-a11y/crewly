[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$LogDirectory = Join-Path $env:USERPROFILE '.crewly\logs'
$StdoutLog = Join-Path $LogDirectory 'crewly-windows.log'
$StderrLog = Join-Path $LogDirectory 'crewly-windows-error.log'

Write-Host '=== Crewly para Windows: salida ===' -ForegroundColor Cyan
if (Test-Path -LiteralPath $StdoutLog) {
    Get-Content -LiteralPath $StdoutLog -Tail 100
} else {
    Write-Host 'Todavía no existe un registro de salida.'
}

Write-Host "`n=== Crewly para Windows: errores ===" -ForegroundColor Yellow
if (Test-Path -LiteralPath $StderrLog) {
    Get-Content -LiteralPath $StderrLog -Tail 100
} else {
    Write-Host 'No hay errores registrados.'
}
