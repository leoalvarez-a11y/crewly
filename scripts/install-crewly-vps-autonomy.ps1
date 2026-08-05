[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-EffectiveCodexHome {
  if ($env:CODEX_HOME) { return [System.IO.Path]::GetFullPath($env:CODEX_HOME) }
  return [System.IO.Path]::GetFullPath((Join-Path $HOME '.codex'))
}

function Test-ManagedPolicy {
  param([Parameter(Mandatory = $true)][string]$CodexHome)

  if ($env:CODEX_EXEC_POLICY_MANAGED -match '^(1|true|yes)$') { return $true }
  if ($env:CODEX_MANAGED_CONFIG) { return $true }
  foreach ($candidate in @('managed_config.toml', 'managed-policy.toml', 'policies\managed.toml')) {
    if (Test-Path -LiteralPath (Join-Path $CodexHome $candidate)) { return $true }
  }
  return $false
}

function ConvertTo-TomlString {
  param([Parameter(Mandatory = $true)][string]$Value)

  return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Get-RuleContent {
  param(
    [Parameter(Mandatory = $true)][string]$PowerShellPath,
    [Parameter(Mandatory = $true)][string]$WrapperPath
  )

  $powerShellToml = ConvertTo-TomlString $PowerShellPath
  $wrapperToml = ConvertTo-TomlString $WrapperPath
  return @"
prefix_rule(
    pattern = [
        "$powerShellToml",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "$wrapperToml"
    ],
    decision = "allow",
    justification = "Allow only structured Crewly operations on finboard-vps"
)
"@
}

function Test-RuleWithCodex {
  param(
    [Parameter(Mandatory = $true)][string]$CodexPath,
    [Parameter(Mandatory = $true)][string]$RulePath,
    [Parameter(Mandatory = $true)][string]$PowerShellPath,
    [Parameter(Mandatory = $true)][string]$WrapperPath
  )

  $output = & $CodexPath execpolicy check --pretty --rules $RulePath -- $PowerShellPath -NoProfile -ExecutionPolicy Bypass -File $WrapperPath InspectHost -DryRun
  if ($LASTEXITCODE -ne 0) { throw 'Codex rejected the generated Crewly execpolicy rule.' }
  $result = ($output -join "`n") | ConvertFrom-Json
  if ($result.decision -ne 'allow') { throw 'Generated Crewly rule did not evaluate to allow.' }
}

$codexHome = Get-EffectiveCodexHome
if (Test-ManagedPolicy -CodexHome $codexHome) {
  [Console]::Error.WriteLine('BLOCKED_MANAGED_POLICY Managed Codex policy detected; no files changed.')
  exit 20
}

$repoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$wrapperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'crewly-vps-remote.ps1'))
$powerShellPath = [System.IO.Path]::GetFullPath((Get-Command powershell.exe -ErrorAction Stop).Source)
$codexCommand = Get-Command codex.exe -ErrorAction SilentlyContinue
if (-not $codexCommand) { $codexCommand = Get-Command codex -ErrorAction Stop }
$codexPath = [System.IO.Path]::GetFullPath($codexCommand.Source)
if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) { throw 'Crewly VPS wrapper is missing.' }

$rulesDirectory = Join-Path $codexHome 'rules'
$targetRule = Join-Path $rulesDirectory 'crewly-vps-remote.rules'
$configPath = Join-Path $codexHome 'config.toml'
$desiredContent = Get-RuleContent -PowerShellPath $powerShellPath -WrapperPath $wrapperPath
if ((Test-Path -LiteralPath $targetRule -PathType Leaf) -and (Get-Content -Raw -LiteralPath $targetRule) -eq $desiredContent) {
  Test-RuleWithCodex -CodexPath $codexPath -RulePath $targetRule -PowerShellPath $powerShellPath -WrapperPath $wrapperPath
  Write-Output "CODEX_HOME=$codexHome"
  Write-Output "CODEX=$codexPath"
  Write-Output "POWERSHELL=$powerShellPath"
  Write-Output "REPO_ROOT=$repoRoot"
  Write-Output "RULE_PATH=$targetRule"
  Write-Output 'CONFIG_BACKUP=UNCHANGED'
  Write-Output 'RULE_BACKUP=UNCHANGED'
  Write-Output 'INSTALL_RESULT=PASS_IDEMPOTENT'
  exit 0
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
$backupDirectory = Join-Path $codexHome "backups\crewly-vps-autonomy\$timestamp"
$configBackup = 'NOT_PRESENT'
$ruleBackup = 'NOT_PRESENT'
$targetExisted = Test-Path -LiteralPath $targetRule

New-Item -ItemType Directory -Path $rulesDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
  $configBackup = Join-Path $backupDirectory 'config.toml'
  Copy-Item -LiteralPath $configPath -Destination $configBackup
}
if ($targetExisted) {
  $ruleBackup = Join-Path $backupDirectory 'crewly-vps-remote.rules'
  Copy-Item -LiteralPath $targetRule -Destination $ruleBackup
}

$temporaryRule = Join-Path $backupDirectory 'crewly-vps-remote.candidate.rules'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temporaryRule, $desiredContent, $utf8NoBom)

try {
  Test-RuleWithCodex -CodexPath $codexPath -RulePath $temporaryRule -PowerShellPath $powerShellPath -WrapperPath $wrapperPath
  $existingContent = if ($targetExisted) { Get-Content -Raw -LiteralPath $targetRule } else { '' }
  if ($existingContent -ne $desiredContent) {
    Copy-Item -LiteralPath $temporaryRule -Destination $targetRule -Force
  }
  Test-RuleWithCodex -CodexPath $codexPath -RulePath $targetRule -PowerShellPath $powerShellPath -WrapperPath $wrapperPath
} catch {
  if ($targetExisted -and (Test-Path -LiteralPath $ruleBackup)) {
    Copy-Item -LiteralPath $ruleBackup -Destination $targetRule -Force
  } elseif (Test-Path -LiteralPath $targetRule) {
    Remove-Item -LiteralPath $targetRule -Force
  }
  throw
}

Write-Output "CODEX_HOME=$codexHome"
Write-Output "CODEX=$codexPath"
Write-Output "POWERSHELL=$powerShellPath"
Write-Output "REPO_ROOT=$repoRoot"
Write-Output "RULE_PATH=$targetRule"
Write-Output "CONFIG_BACKUP=$configBackup"
Write-Output "RULE_BACKUP=$ruleBackup"
Write-Output 'INSTALL_RESULT=PASS'
