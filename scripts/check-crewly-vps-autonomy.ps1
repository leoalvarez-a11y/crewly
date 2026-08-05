[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-Decision {
  param(
    [Parameter(Mandatory = $true)][string]$CodexPath,
    [Parameter(Mandatory = $true)][string[]]$RuleArguments,
    [Parameter(Mandatory = $true)][string[]]$Argv
  )

  $output = & $CodexPath execpolicy check --pretty @RuleArguments -- @Argv
  if ($LASTEXITCODE -ne 0) { throw "execpolicy check failed for $($Argv[0])" }
  $result = ($output -join "`n") | ConvertFrom-Json
  if ($result.decision) { return [string]$result.decision }
  return 'no_match'
}

$codexHome = if ($env:CODEX_HOME) { [System.IO.Path]::GetFullPath($env:CODEX_HOME) } else { [System.IO.Path]::GetFullPath((Join-Path $HOME '.codex')) }
$codexCommand = Get-Command codex -ErrorAction Stop
$codexPath = $codexCommand.Source
$powerShellPath = [System.IO.Path]::GetFullPath((Get-Command powershell.exe -ErrorAction Stop).Source)
$wrapperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'crewly-vps-remote.ps1'))
$ruleFiles = @(Get-ChildItem -LiteralPath (Join-Path $codexHome 'rules') -Filter '*.rules' -File | Sort-Object FullName)
if ($ruleFiles.Count -eq 0) { throw 'No effective Codex execpolicy rules were found.' }
$ruleArguments = @()
foreach ($ruleFile in $ruleFiles) { $ruleArguments += @('--rules', $ruleFile.FullName) }

$wrapperDecision = Get-Decision -CodexPath $codexPath -RuleArguments $ruleArguments -Argv @($powerShellPath, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapperPath, 'InspectHost', '-DryRun')
$rawSshDecision = Get-Decision -CodexPath $codexPath -RuleArguments $ruleArguments -Argv @('ssh', '-o', 'ConnectTimeout=10', 'finboard-vps', 'true')
$rawScpDecision = Get-Decision -CodexPath $codexPath -RuleArguments $ruleArguments -Argv @('scp', 'artifact.tgz', 'finboard-vps:/tmp/crewly-deploy/artifact.tgz')
$arbitraryPowerShellDecision = Get-Decision -CodexPath $codexPath -RuleArguments $ruleArguments -Argv @($powerShellPath, '-Command', 'Write-Output unsafe')
$otherWrapper = Join-Path $PSScriptRoot 'other\crewly-vps-remote.ps1'
$otherWrapperDecision = Get-Decision -CodexPath $codexPath -RuleArguments $ruleArguments -Argv @($powerShellPath, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $otherWrapper, 'InspectHost', '-DryRun')

Write-Output "CREWLY_WRAPPER_DECISION = $wrapperDecision"
Write-Output "RAW_SSH_DECISION = $rawSshDecision"
Write-Output "RAW_SCP_DECISION = $rawScpDecision"
Write-Output "ARBITRARY_POWERSHELL_DECISION = $arbitraryPowerShellDecision"
Write-Output "WRAPPER_FROM_OTHER_PATH_DECISION = $otherWrapperDecision"

if ($wrapperDecision -ne 'allow') { throw 'Crewly wrapper is not allowed.' }
foreach ($decision in @($rawSshDecision, $rawScpDecision, $arbitraryPowerShellDecision, $otherWrapperDecision)) {
  if ($decision -eq 'allow') { throw 'An unsafe command unexpectedly evaluated to allow.' }
}
Write-Output 'AUTONOMY_CHECK=PASS'
