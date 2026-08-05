$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "ASSERTION_FAILED $Message" }
}

function Invoke-Installer {
  param([string]$CodexHome)

  $previous = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $CodexHome
    $output = & $script:PowerShellPath -NoProfile -ExecutionPolicy Bypass -File $script:InstallerPath 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
  } finally {
    if ($null -eq $previous) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $previous }
  }
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$script:InstallerPath = Join-Path $PSScriptRoot 'install-crewly-vps-autonomy.ps1'
$script:PowerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$source = Get-Content -Raw -LiteralPath $script:InstallerPath
Assert-True (-not ($source -match 'default\.rules')) 'Installer must never modify default.rules.'
Assert-True ($source -match 'crewly-vps-remote\.rules') 'Installer must target only the Crewly rule.'
Assert-True ($source -match 'BLOCKED_MANAGED_POLICY') 'Installer must detect managed policy.'
Assert-True ($source -match 'Copy-Item -LiteralPath \$ruleBackup -Destination \$targetRule') 'Installer must restore the prior rule on failure.'

$testHome = Join-Path $script:RepoRoot "evaluation-artifacts\installer-test-$PID"
$rulesDirectory = Join-Path $testHome 'rules'
New-Item -ItemType Directory -Path $rulesDirectory -Force | Out-Null
$configPath = Join-Path $testHome 'config.toml'
$targetRule = Join-Path $rulesDirectory 'crewly-vps-remote.rules'
[System.IO.File]::WriteAllText($configPath, "[features]`nexample = true`n")
[System.IO.File]::WriteAllText($targetRule, "# prior Crewly rule`n")
try {
  $first = Invoke-Installer -CodexHome $testHome
  Assert-True ($first.ExitCode -eq 0 -and $first.Output -match 'INSTALL_RESULT=PASS') 'First installer run must pass.'
  Assert-True (Test-Path -LiteralPath $targetRule -PathType Leaf) 'Crewly rule must be installed.'
  $installed = Get-Content -Raw -LiteralPath $targetRule
  Assert-True ($installed -match [regex]::Escape('Allow only structured Crewly operations on finboard-vps')) 'Rule justification must be exact.'
  Assert-True ($installed -match [regex]::Escape([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'crewly-vps-remote.ps1')).Replace('\', '\\'))) 'Rule must pin the exact wrapper path.'
  Assert-True ((Get-Content -Raw -LiteralPath $configPath) -eq "[features]`nexample = true`n") 'Existing config must remain unchanged.'
  $backupRules = @(Get-ChildItem -LiteralPath (Join-Path $testHome 'backups\crewly-vps-autonomy') -Filter 'crewly-vps-remote.rules' -Recurse)
  Assert-True ($backupRules.Count -eq 1 -and (Get-Content -Raw -LiteralPath $backupRules[0].FullName) -match 'prior Crewly rule') 'Prior rule backup must be preserved for rollback.'
  $firstHash = (Get-FileHash -LiteralPath $targetRule -Algorithm SHA256).Hash
  $backupDirectoryCount = @(Get-ChildItem -LiteralPath (Join-Path $testHome 'backups\crewly-vps-autonomy') -Directory).Count

  $second = Invoke-Installer -CodexHome $testHome
  Assert-True ($second.ExitCode -eq 0 -and $second.Output -match 'PASS_IDEMPOTENT') 'Second installer run must be idempotent.'
  Assert-True ((Get-FileHash -LiteralPath $targetRule -Algorithm SHA256).Hash -eq $firstHash) 'Idempotent installation must not rewrite the rule.'
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $testHome 'backups\crewly-vps-autonomy') -Directory).Count -eq $backupDirectoryCount) 'Idempotent installation must not create another backup.'

  $managedHome = Join-Path $script:RepoRoot "evaluation-artifacts\installer-managed-test-$PID"
  New-Item -ItemType Directory -Path $managedHome -Force | Out-Null
  $previousManaged = $env:CODEX_EXEC_POLICY_MANAGED
  $previousHome = $env:CODEX_HOME
  try {
    $env:CODEX_EXEC_POLICY_MANAGED = '1'
    $env:CODEX_HOME = $managedHome
    $priorErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & $script:PowerShellPath -NoProfile -ExecutionPolicy Bypass -File $script:InstallerPath *> $null
      $managedExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $priorErrorAction
    }
    Assert-True ($managedExitCode -eq 20) 'Managed policy must block installation with the documented code.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $managedHome 'rules\crewly-vps-remote.rules'))) 'Managed-policy block must not write a rule.'
  } finally {
    if ($null -eq $previousManaged) { Remove-Item Env:CODEX_EXEC_POLICY_MANAGED -ErrorAction SilentlyContinue } else { $env:CODEX_EXEC_POLICY_MANAGED = $previousManaged }
    if ($null -eq $previousHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $previousHome }
    $resolvedManagedHome = [System.IO.Path]::GetFullPath($managedHome)
    Assert-True ($resolvedManagedHome.StartsWith([System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'evaluation-artifacts')) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) 'Managed test cleanup must remain scoped.'
    if (Test-Path -LiteralPath $managedHome) { Remove-Item -LiteralPath $managedHome -Recurse -Force }
  }
} finally {
  $resolvedHome = [System.IO.Path]::GetFullPath($testHome)
  Assert-True ($resolvedHome.StartsWith([System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'evaluation-artifacts')) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) 'Installer test cleanup must remain scoped.'
  if (Test-Path -LiteralPath $testHome) { Remove-Item -LiteralPath $testHome -Recurse -Force }
}

Write-Output 'CREWLY_VPS_AUTONOMY_INSTALLER_TESTS=PASS'
