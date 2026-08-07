[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CrewlyHome = Join-Path $env:USERPROFILE '.crewly'
$RuntimeDirectory = Join-Path $CrewlyHome 'run'
$LogDirectory = Join-Path $CrewlyHome 'logs'
$PidFile = Join-Path $RuntimeDirectory 'crewly-windows.json'
$StdoutLog = Join-Path $LogDirectory 'crewly-windows.log'
$StderrLog = Join-Path $LogDirectory 'crewly-windows-error.log'
$BackendPath = Join-Path $RepoRoot 'dist\backend\backend\src\index.js'
$DashboardUrl = 'http://localhost:8787'
$HealthUrl = "$DashboardUrl/health"

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

function Get-Node22Path {
    $userPrograms = Join-Path $env:LOCALAPPDATA 'Programs'
    $candidates = @(
        Get-ChildItem -LiteralPath $userPrograms -Directory -Filter 'nodejs-22*' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'node.exe' }
    )
    $pathNode = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($pathNode) {
        $candidates += $pathNode.Source
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }
        $version = (& $candidate --version 2>$null).TrimStart('v')
        if ([int]($version.Split('.')[0]) -ge 22) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Node.js 22 o posterior no está disponible para Windows.'
}

function Test-CrewlyHealth {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

try {
    if (Test-CrewlyHealth) {
        Start-Process $DashboardUrl
        exit 0
    }

    if (-not (Test-Path -LiteralPath $BackendPath)) {
        throw "No existe el backend compilado: $BackendPath"
    }

    New-Item -ItemType Directory -Path $RuntimeDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

    $nodePath = Get-Node22Path
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $gitBashDirectory = 'C:\Program Files\Git\bin'
    if (-not (Test-Path -LiteralPath (Join-Path $gitBashDirectory 'bash.exe'))) {
        throw 'Git Bash no está instalado; Crewly lo necesita para sus skills nativos.'
    }
    $env:Path = "$(Split-Path $nodePath -Parent);$gitBashDirectory;$userPath;$machinePath"
    $env:CREWLY_HOME = $CrewlyHome
    $env:WEB_PORT = '8787'
    $env:NODE_ENV = 'production'

    $process = Start-Process -FilePath $nodePath `
        -ArgumentList @('--expose-gc', '--max-old-space-size=4096', $BackendPath) `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $StdoutLog `
        -RedirectStandardError $StderrLog `
        -PassThru

    [ordered]@{
        pid = $process.Id
        startedAt = (Get-Date).ToUniversalTime().ToString('o')
        node = $nodePath
        backend = $BackendPath
    } | ConvertTo-Json | Set-Content -LiteralPath $PidFile -Encoding UTF8

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 1
        if (Test-CrewlyHealth) {
            $ready = $true
            break
        }
        if ($process.HasExited) {
            break
        }
    }

    if (-not $ready) {
        $details = if (Test-Path -LiteralPath $StderrLog) {
            (Get-Content -LiteralPath $StderrLog -Tail 30 | Out-String).Trim()
        } else {
            'Crewly terminó antes de publicar el dashboard.'
        }
        throw "Crewly no respondió en $HealthUrl.`n`n$details"
    }

    Start-Process $DashboardUrl
}
catch {
    $message = $_.Exception.Message
    "[$(Get-Date -Format o)] ERROR: $message" | Add-Content -LiteralPath $StderrLog -Encoding UTF8
    Show-CrewlyError -Message $message
    exit 1
}
