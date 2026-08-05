[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu'
$LinuxUser = 'zytto'
$LinuxCheckout = '/home/zytto/crewly/source'
$LinuxStartScript = '/home/zytto/crewly/source/scripts/crewly-local-start.sh'
$DashboardUrl = 'http://localhost:8787'
$HealthUrl = "$DashboardUrl/health"
$LauncherStateDirectory = Join-Path $env:LOCALAPPDATA 'Crewly'
$LauncherLog = Join-Path $LauncherStateDirectory 'windows-launcher.log'

New-Item -ItemType Directory -Path $LauncherStateDirectory -Force | Out-Null

function Show-CrewlyError {
    param([Parameter(Mandatory)][string]$Message)

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        $Message,
        'Crewly no pudo iniciar',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}

try {
    $kernel = (& wsl.exe -d $Distro -u $LinuxUser -- uname -r 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $kernel -notmatch '(?i)(microsoft-standard-WSL2|WSL2)') {
        throw "Ubuntu no existe como WSL2 o no se puede abrir como $LinuxUser. Resultado: $kernel"
    }

    $startOutput = (& wsl.exe -d $Distro -u $LinuxUser --cd $LinuxCheckout -- $LinuxStartScript 2>&1 | Out-String).Trim()
    $startExitCode = $LASTEXITCODE
    "[$(Get-Date -Format o)]`r`n$startOutput" | Add-Content -LiteralPath $LauncherLog -Encoding UTF8
    if ($startExitCode -ne 0) {
        throw "Crewly devolvió el código $startExitCode.`n`n$startOutput`n`nRegistro: $LauncherLog"
    }

    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
    }
    catch {
        throw "Crewly terminó el arranque, pero Windows no pudo acceder a $HealthUrl.`n`n$($_.Exception.Message)"
    }
    if ($response.StatusCode -ne 200) {
        throw "El health endpoint respondió HTTP $($response.StatusCode)."
    }

    Start-Process $DashboardUrl
    [ordered]@{
        openedAt = (Get-Date).ToUniversalTime().ToString('o')
        url = $DashboardUrl
        healthStatus = $response.StatusCode
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $LauncherStateDirectory 'browser-open.json') -Encoding UTF8
}
catch {
    $message = $_.Exception.Message
    "[$(Get-Date -Format o)] ERROR: $message" | Add-Content -LiteralPath $LauncherLog -Encoding UTF8
    Show-CrewlyError -Message $message
    exit 1
}
