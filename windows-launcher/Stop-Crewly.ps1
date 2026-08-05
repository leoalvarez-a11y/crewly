[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu'
$LinuxUser = 'zytto'
$LinuxCheckout = '/home/zytto/crewly/source'
$LinuxStopScript = '/home/zytto/crewly/source/scripts/crewly-local-stop.sh'

try {
    $output = (& wsl.exe -d $Distro -u $LinuxUser --cd $LinuxCheckout -- $LinuxStopScript 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw $output
    }

    $shell = New-Object -ComObject WScript.Shell
    $shell.Popup($output, 4, 'Crewly', 64) | Out-Null
}
catch {
    $shell = New-Object -ComObject WScript.Shell
    $shell.Popup($_.Exception.Message, 10, 'No se pudo detener Crewly', 16) | Out-Null
    exit 1
}
