[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu'
$LinuxUser = 'zytto'
$LinuxCheckout = '/home/zytto/crewly/source'
$LinuxLogsScript = '/home/zytto/crewly/source/scripts/crewly-local-logs.sh'

& wsl.exe -d $Distro -u $LinuxUser --cd $LinuxCheckout -- $LinuxLogsScript --lines 100 --follow-seconds 120
if ($LASTEXITCODE -ne 0) {
    throw "No se pudieron mostrar los logs de Crewly (código $LASTEXITCODE)."
}
