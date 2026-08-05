$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "ASSERTION_FAILED $Message" }
}

$repoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$powerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$installerPath = Join-Path $PSScriptRoot 'install-crewly-vps-autonomy.ps1'
$checkerPath = Join-Path $PSScriptRoot 'check-crewly-vps-autonomy.ps1'
$testHome = Join-Path $repoRoot "evaluation-artifacts\checker-test-$PID"
New-Item -ItemType Directory -Path $testHome -Force | Out-Null
$previousHome = $env:CODEX_HOME
try {
  $env:CODEX_HOME = $testHome
  & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $installerPath *> $null
  Assert-True ($LASTEXITCODE -eq 0) 'Temporary Crewly rule installation must pass.'
  $output = & $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $checkerPath 2>&1
  Assert-True ($LASTEXITCODE -eq 0) 'Real Codex execpolicy checker must pass.'
  $text = $output -join "`n"
  Assert-True ($text -match 'CREWLY_WRAPPER_DECISION = allow') 'Wrapper must evaluate to allow.'
  Assert-True ($text -match 'RAW_SSH_DECISION = no_match') 'Raw ssh must remain no_match.'
  Assert-True ($text -match 'RAW_SCP_DECISION = no_match') 'Raw scp must remain no_match.'
  Assert-True ($text -match 'ARBITRARY_POWERSHELL_DECISION = no_match') 'Arbitrary PowerShell must remain no_match.'
  Assert-True ($text -match 'WRAPPER_FROM_OTHER_PATH_DECISION = no_match') 'A wrapper at another path must remain no_match.'
} finally {
  if ($null -eq $previousHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $previousHome }
  $resolvedHome = [System.IO.Path]::GetFullPath($testHome)
  Assert-True ($resolvedHome.StartsWith([System.IO.Path]::GetFullPath((Join-Path $repoRoot 'evaluation-artifacts')) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) 'Checker test cleanup must remain scoped.'
  if (Test-Path -LiteralPath $testHome) { Remove-Item -LiteralPath $testHome -Recurse -Force }
}

Write-Output 'CREWLY_VPS_AUTONOMY_CHECKER_TESTS=PASS'
