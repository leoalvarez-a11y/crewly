[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PidFile = Join-Path $env:USERPROFILE '.crewly\run\crewly-windows.json'
$BackendPath = Join-Path $RepoRoot 'dist\backend\backend\src\index.js'

try {
    if (-not (Test-Path -LiteralPath $PidFile)) {
        $message = 'Crewly para Windows ya está detenido.'
    }
    else {
        $state = Get-Content -LiteralPath $PidFile -Raw | ConvertFrom-Json
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($state.pid)" -ErrorAction SilentlyContinue
        if ($process -and $process.CommandLine -like "*$BackendPath*") {
            Stop-Process -Id $state.pid
            Wait-Process -Id $state.pid -Timeout 15 -ErrorAction SilentlyContinue
            $message = 'Crewly para Windows se detuvo correctamente.'
        }
        elseif ($process) {
            throw "El PID $($state.pid) pertenece a otro proceso; no se detuvo."
        }
        else {
            $message = 'Crewly para Windows ya estaba detenido.'
        }
        Remove-Item -LiteralPath $PidFile -Force
    }

    $shell = New-Object -ComObject WScript.Shell
    $shell.Popup($message, 4, 'Crewly', 64) | Out-Null
}
catch {
    $shell = New-Object -ComObject WScript.Shell
    $shell.Popup($_.Exception.Message, 10, 'No se pudo detener Crewly', 16) | Out-Null
    exit 1
}
