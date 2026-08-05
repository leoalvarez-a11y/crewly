$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "ASSERTION_FAILED $Message" }
}

function Invoke-WrapperChild {
  param([string[]]$Arguments)

  $priorErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $script:PowerShellPath -NoProfile -ExecutionPolicy Bypass -File $script:WrapperPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $priorErrorAction
  }
  $text = $output -join "`n"
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = $text
    Error = $text
  }
}

$script:RepoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$script:WrapperPath = Join-Path $PSScriptRoot 'crewly-vps-remote.ps1'
$script:PowerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$source = Get-Content -Raw -LiteralPath $script:WrapperPath
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script:WrapperPath, [ref]$null, [ref]$null)
$parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

Assert-True (-not ($parameterNames -contains 'Command')) 'The wrapper must not expose a free Command parameter.'
Assert-True (-not ($parameterNames -contains 'HostName')) 'The wrapper must not accept a host override.'
Assert-True (-not ($source -match '(?i)Invoke-Expression|\biex\b')) 'Invoke-Expression and iex must not exist.'
Assert-True (-not ($source -match '(?i)cmd(?:\.exe)?\s*/c')) 'cmd /c must not exist.'
Assert-True ($source -match "\$AllowedHost = 'finboard-vps'") 'The only host must be fixed internally.'

$unknown = Invoke-WrapperChild @('UnknownOperation', '-DryRun')
Assert-True ($unknown.ExitCode -ne 0) 'Unknown operations must be rejected.'
$otherHost = Invoke-WrapperChild @('InspectHost', '-DryRun', '-HostName', 'example.invalid')
Assert-True ($otherHost.ExitCode -ne 0) 'A host override must be rejected by parameter binding.'

$traversal = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', 'evaluation-artifacts/../package.json', '-ReleaseSha', ('a' * 40))
Assert-True ($traversal.ExitCode -ne 0 -and $traversal.Error -match 'LOCAL_TRAVERSAL_REJECTED') 'Parent traversal must be rejected.'
$siblingPath = "$($script:RepoRoot)-sibling\artifact.tgz"
$sibling = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', $siblingPath, '-ReleaseSha', ('a' * 40))
Assert-True ($sibling.ExitCode -ne 0 -and $sibling.Error -match 'LOCAL_PATH_NOT_ALLOWED') 'Sibling-prefix paths must be rejected.'
$outside = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', 'C:\Windows\Temp\artifact.tgz', '-ReleaseSha', ('a' * 40))
Assert-True ($outside.ExitCode -ne 0 -and $outside.Error -match 'LOCAL_PATH_NOT_ALLOWED') 'Paths outside the repository must be rejected.'

$testRoot = Join-Path $script:RepoRoot "evaluation-artifacts\wrapper-test-$PID"
$artifact = Join-Path $testRoot 'crewly-test.tgz'
$junction = Join-Path $testRoot 'escape-junction'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
[System.IO.File]::WriteAllText($artifact, 'validated release fixture')
$checksum = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
try {
  $valid = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', $artifact, '-ReleaseSha', ('a' * 40), '-ExpectedChecksum', $checksum)
  Assert-True ($valid.ExitCode -eq 0 -and $valid.Output -match 'DRY_RUN=true') "A valid artifact and checksum must pass dry-run validation. exit=$($valid.ExitCode) error=$($valid.Error) output=$($valid.Output)"
  Assert-True ($valid.Output -match 'EXECUTABLE=scp') 'Upload dry-run must show its executable.'

  $mismatch = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', $artifact, '-ReleaseSha', ('a' * 40), '-ExpectedChecksum', ('b' * 64))
  Assert-True ($mismatch.ExitCode -ne 0 -and $mismatch.Error -match 'LOCAL_CHECKSUM_MISMATCH') 'Checksum mismatches must fail.'

  New-Item -ItemType Junction -Path $junction -Target 'C:\Windows\Temp' | Out-Null
  $junctionResult = Invoke-WrapperChild @('UploadRelease', '-DryRun', '-LocalPath', (Join-Path $junction 'artifact.tgz'), '-ReleaseSha', ('a' * 40))
  Assert-True ($junctionResult.ExitCode -ne 0 -and $junctionResult.Error -match 'LOCAL_REPARSE_POINT_REJECTED') 'Junction escapes must be rejected.'
} finally {
  if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  Assert-True ($resolvedTestRoot.StartsWith([System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'evaluation-artifacts')) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) 'Test cleanup path must remain scoped.'
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

$dryRun = Invoke-WrapperChild @('InspectHost', '-DryRun')
Assert-True ($dryRun.ExitCode -eq 0) 'InspectHost dry-run must pass.'
Assert-True ($dryRun.Output -match 'HOST=finboard-vps' -and $dryRun.Output -match 'EXPECTED_EFFECT=') 'Dry-run must show host and expected effects.'

$env:CREWLY_WRAPPER_TEST_MODE = '1'
try {
  . $script:WrapperPath -Operation InspectHost -DryRun
  Assert-True ((Protect-Output 'token=abc123 Bearer abcdefghijklmnop') -eq 'token=[REDACTED] Bearer [REDACTED]') 'Secret-like output must be redacted.'

  $helperRoot = Join-Path $script:RepoRoot "evaluation-artifacts\process-test-$PID"
  New-Item -ItemType Directory -Path $helperRoot -Force | Out-Null
  $exitHelper = Join-Path $helperRoot 'exit.ps1'
  $timeoutHelper = Join-Path $helperRoot 'timeout.ps1'
  [System.IO.File]::WriteAllText($exitHelper, 'exit 7')
  [System.IO.File]::WriteAllText($timeoutHelper, 'Start-Sleep -Seconds 3')
  try {
    $exitCaught = $false
    try { Invoke-ProcessChecked -Executable $script:PowerShellPath -Arguments @('-NoProfile', '-File', $exitHelper) -Seconds 10 | Out-Null } catch { $exitCaught = $_.Exception.Message -match 'REMOTE_EXIT_CODE=7' }
    Assert-True $exitCaught 'Non-zero remote exit codes must propagate.'
    $timeoutCaught = $false
    try { Invoke-ProcessChecked -Executable $script:PowerShellPath -Arguments @('-NoProfile', '-File', $timeoutHelper) -Seconds 1 | Out-Null } catch { $timeoutCaught = $_.Exception.Message -match 'REMOTE_TIMEOUT' }
    Assert-True $timeoutCaught 'Remote process timeouts must propagate.'
  } finally {
    $resolvedHelperRoot = [System.IO.Path]::GetFullPath($helperRoot)
    Assert-True ($resolvedHelperRoot.StartsWith([System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'evaluation-artifacts')) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) 'Process test cleanup path must remain scoped.'
    if (Test-Path -LiteralPath $helperRoot) { Remove-Item -LiteralPath $helperRoot -Recurse -Force }
  }
} finally {
  Remove-Item Env:CREWLY_WRAPPER_TEST_MODE -ErrorAction SilentlyContinue
}

Write-Output 'CREWLY_VPS_REMOTE_WRAPPER_TESTS=PASS'
