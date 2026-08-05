[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet(
    'InspectHost',
    'InspectCrewlyPrerequisites',
    'PrepareDeploymentDryRun',
    'UploadRelease',
    'InstallRelease',
    'ConfigureService',
    'Start',
    'Stop',
    'Restart',
    'Status',
    'Health',
    'Logs',
    'Backup',
    'ListBackups',
    'RestoreDryRun',
    'RollbackDryRun',
    'Rollback',
    'RunFixture',
    'CleanupFixture'
  )]
  [string]$Operation,

  [switch]$DryRun,

  [ValidateRange(1, 900)]
  [int]$TimeoutSeconds = 120,

  [ValidateRange(1, 500)]
  [int]$LogLines = 100,

  [string]$LocalPath = '',

  [string]$ReleaseSha = '',

  [string]$ExpectedChecksum = '',

  [string]$BackupId = ''
)

$ErrorActionPreference = 'Stop'

$AllowedHost = 'finboard-vps'
$RepoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot '..')).Path).TrimEnd('\', '/')
$AllowedLocalRoots = @(
  $RepoRoot,
  (Join-Path $RepoRoot 'dist'),
  (Join-Path $RepoRoot 'scripts'),
  (Join-Path $RepoRoot 'docs\adoption'),
  (Join-Path $RepoRoot 'evaluation-artifacts'),
  (Join-Path $RepoRoot 'deploy')
)
$AllowedRemotePaths = @(
  '/opt/crewly',
  '/opt/crewly/releases',
  '/opt/crewly/shared',
  '/opt/crewly/shared/crewly-home',
  '/opt/crewly/shared/backups',
  '/var/log/crewly',
  '/tmp/crewly-deploy'
)
$FixturePath = '/tmp/crewly-deploy/fixture'
$ServiceName = 'crewly.service'
$InternalPort = '8787'
$ConnectionTimeoutSeconds = 15

function Protect-Output {
  param([AllowEmptyString()][string]$Value)

  if ($null -eq $Value) { return '' }
  return $Value `
    -replace '(?i)(authorization:\s*bearer\s+)[^\s]+', '$1[REDACTED]' `
    -replace '(?i)(bearer\s+)[A-Za-z0-9._~+/=-]+', '$1[REDACTED]' `
    -replace '(?i)(token|secret|password|api[_-]?key|credential|cookie)\s*[:=]\s*[^\s,;]+', '$1=[REDACTED]'
}

function Fail-Restricted {
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [Parameter(Mandatory = $true)][string]$Message,
    [int]$ExitCode = 1
  )

  [Console]::Error.WriteLine("$Code $(Protect-Output $Message)")
  exit $ExitCode
}

function Test-StrictChildPath {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$Parent
  )

  $candidateFull = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\', '/')
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
  $comparison = [System.StringComparison]::OrdinalIgnoreCase
  return $candidateFull.Equals($parentFull, $comparison) -or $candidateFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-NoReparseEscape {
  param([Parameter(Mandatory = $true)][string]$PathValue)

  $current = [System.IO.Path]::GetFullPath($PathValue)
  while ($current -and (Test-StrictChildPath -Candidate $current -Parent $RepoRoot)) {
    if (Test-Path -LiteralPath $current) {
      $item = Get-Item -LiteralPath $current -Force
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Fail-Restricted 'LOCAL_REPARSE_POINT_REJECTED' 'Symlinks and junctions are not permitted in release paths.'
      }
    }
    if ($current.Equals($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) { break }
    $current = Split-Path -Parent $current
  }
}

function Resolve-AllowedLocalArtifact {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [switch]$AllowMissing
  )

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    Fail-Restricted 'LOCAL_PATH_REQUIRED' 'A release artifact path is required.'
  }
  if ($PathValue -match '(^|[\\/])\.\.([\\/]|$)') {
    Fail-Restricted 'LOCAL_TRAVERSAL_REJECTED' 'Parent traversal is not permitted.'
  }

  $combined = if ([System.IO.Path]::IsPathRooted($PathValue)) { $PathValue } else { Join-Path $RepoRoot $PathValue }
  $full = [System.IO.Path]::GetFullPath($combined)
  if (-not (Test-StrictChildPath -Candidate $full -Parent $RepoRoot)) {
    Fail-Restricted 'LOCAL_PATH_NOT_ALLOWED' 'The local path must remain inside the Crewly repository.'
  }
  Assert-NoReparseEscape -PathValue $full

  $allowed = $false
  foreach ($root in $AllowedLocalRoots) {
    if (Test-StrictChildPath -Candidate $full -Parent $root) {
      $allowed = $true
      break
    }
  }
  if (-not $allowed) {
    Fail-Restricted 'LOCAL_PATH_NOT_ALLOWED' 'The local path is outside the approved Crewly artifact roots.'
  }
  if (-not $AllowMissing -and -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    Fail-Restricted 'LOCAL_ARTIFACT_NOT_FOUND' 'The release artifact does not exist.'
  }
  if ([System.IO.Path]::GetFileName($full) -notmatch '^[A-Za-z0-9._-]+\.(tgz|tar\.gz)$') {
    Fail-Restricted 'LOCAL_ARTIFACT_NAME_REJECTED' 'Release artifacts must use a simple .tgz or .tar.gz filename.'
  }
  return $full
}

function Assert-ReleaseSha {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^[0-9a-fA-F]{40}$') {
    Fail-Restricted 'INVALID_RELEASE_SHA' 'Release SHA must contain exactly 40 hexadecimal characters.'
  }
  return $Value.ToLowerInvariant()
}

function Assert-Checksum {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^[0-9a-fA-F]{64}$') {
    Fail-Restricted 'INVALID_CHECKSUM' 'Expected checksum must be a SHA-256 value.'
  }
  return $Value.ToLowerInvariant()
}

function Assert-BackupId {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value -notmatch '^\d{8}T\d{6}Z-[0-9a-fA-F]{8,40}$') {
    Fail-Restricted 'INVALID_BACKUP_ID' 'Backup id must use the timestamp-and-SHA format.'
  }
  return $Value
}

function Format-Argument {
  param([Parameter(Mandatory = $true)][string]$Value)

  return (Protect-Output $Value).Replace("`r", '').Replace("`n", '')
}

function Write-DryRunInvocation {
  param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$Effect,
    [string]$RemotePath = ''
  )

  Write-Output 'DRY_RUN=true'
  Write-Output "OPERATION=$Operation"
  Write-Output "HOST=$AllowedHost"
  Write-Output "EXECUTABLE=$(Format-Argument $Executable)"
  for ($index = 0; $index -lt $Arguments.Count; $index++) {
    Write-Output "ARG[$index]=$(Format-Argument $Arguments[$index])"
  }
  if ($RemotePath) { Write-Output "REMOTE_PATH=$(Format-Argument $RemotePath)" }
  Write-Output "EXPECTED_EFFECT=$(Format-Argument $Effect)"
}

function Invoke-ProcessChecked {
  param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][int]$Seconds
  )

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  try {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $processHandle = $process.Handle
    if (-not $process.WaitForExit($Seconds * 1000)) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw [System.TimeoutException]::new("REMOTE_TIMEOUT operation=$Operation")
    }
    $process.WaitForExit()
    $process.Refresh()
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -Raw -LiteralPath $stdoutPath } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -Raw -LiteralPath $stderrPath } else { '' }
    if ($stderr) { [Console]::Error.WriteLine((Protect-Output $stderr.TrimEnd())) }
    if ($process.ExitCode -ne 0) {
      throw "REMOTE_EXIT_CODE=$($process.ExitCode) operation=$Operation"
    }
    return (Protect-Output $stdout.TrimEnd())
  } finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function New-SshArguments {
  param(
    [Parameter(Mandatory = $true)][string]$RemoteExecutable,
    [string[]]$RemoteArguments = @()
  )

  return @(
    '-o', 'BatchMode=yes',
    '-o', "ConnectTimeout=$ConnectionTimeoutSeconds",
    $AllowedHost,
    '--',
    $RemoteExecutable
  ) + $RemoteArguments
}

function Invoke-RemoteProgram {
  param(
    [Parameter(Mandatory = $true)][string]$RemoteExecutable,
    [string[]]$RemoteArguments = @(),
    [Parameter(Mandatory = $true)][string]$Effect,
    [string]$RemotePath = ''
  )

  $arguments = New-SshArguments -RemoteExecutable $RemoteExecutable -RemoteArguments $RemoteArguments
  if ($DryRun) {
    Write-DryRunInvocation -Executable 'ssh' -Arguments $arguments -Effect $Effect -RemotePath $RemotePath
    return ''
  }
  return Invoke-ProcessChecked -Executable 'ssh' -Arguments $arguments -Seconds $TimeoutSeconds
}

function Get-LocalHead {
  $head = (& git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') {
    Fail-Restricted 'INVALID_GIT_STATE' 'Unable to resolve the Crewly repository HEAD.'
  }
  return $head
}

function Get-EffectiveReleaseSha {
  if ($ReleaseSha) { return Assert-ReleaseSha $ReleaseSha }
  return Get-LocalHead
}

function Invoke-InspectionSet {
  param([Parameter(Mandatory = $true)][array]$Checks)

  foreach ($check in $Checks) {
    Write-Output "CHECK=$($check.Name)"
    try {
      $checkOutput = Invoke-RemoteProgram -RemoteExecutable $check.Executable -RemoteArguments $check.Arguments -Effect $check.Effect
      if ($DryRun -and $checkOutput) { Write-Output $checkOutput }
      if (-not $DryRun) { Write-Output 'CHECK_STATUS=available' }
    } catch {
      Write-Output 'CHECK_STATUS=unavailable'
      Write-Output "CHECK_ERROR=$(Protect-Output $_.Exception.Message)"
    }
  }
}

if ($env:CREWLY_WRAPPER_TEST_MODE -eq '1') {
  return
}

switch ($Operation) {
  'InspectHost' {
    $checks = @(
      @{ Name = 'hostname'; Executable = 'hostname'; Arguments = @(); Effect = 'Read hostname.' },
      @{ Name = 'os'; Executable = 'cat'; Arguments = @('/etc/os-release'); Effect = 'Read operating-system metadata.' },
      @{ Name = 'architecture'; Executable = 'uname'; Arguments = @('-m'); Effect = 'Read architecture.' },
      @{ Name = 'user'; Executable = 'id'; Arguments = @('-un'); Effect = 'Detect the effective SSH user without accepting an override.' },
      @{ Name = 'cpu'; Executable = 'nproc'; Arguments = @(); Effect = 'Read CPU count.' },
      @{ Name = 'memory'; Executable = 'free'; Arguments = @('-h'); Effect = 'Read memory capacity.' },
      @{ Name = 'disk'; Executable = 'df'; Arguments = @('-h', '/opt'); Effect = 'Read available deployment disk.' },
      @{ Name = 'node'; Executable = 'node'; Arguments = @('--version'); Effect = 'Read Node.js version if installed.' },
      @{ Name = 'npm'; Executable = 'npm'; Arguments = @('--version'); Effect = 'Read npm version if installed.' },
      @{ Name = 'docker'; Executable = 'docker'; Arguments = @('--version'); Effect = 'Read Docker version if installed.' },
      @{ Name = 'compose'; Executable = 'docker'; Arguments = @('compose', 'version'); Effect = 'Read Docker Compose version if installed.' },
      @{ Name = 'pm2'; Executable = 'pm2'; Arguments = @('--version'); Effect = 'Read PM2 version if installed.' },
      @{ Name = 'systemd'; Executable = 'systemctl'; Arguments = @('--version'); Effect = 'Read systemd version.' },
      @{ Name = 'nginx'; Executable = 'systemctl'; Arguments = @('is-active', 'nginx'); Effect = 'Inspect nginx without changing it.' },
      @{ Name = 'traefik'; Executable = 'systemctl'; Arguments = @('is-active', 'traefik'); Effect = 'Inspect Traefik without changing it.' },
      @{ Name = 'caddy'; Executable = 'systemctl'; Arguments = @('is-active', 'caddy'); Effect = 'Inspect Caddy without changing it.' },
      @{ Name = 'ports'; Executable = 'ss'; Arguments = @('-ltnp'); Effect = 'List listening TCP ports.' },
      @{ Name = 'crewly-service'; Executable = 'systemctl'; Arguments = @('status', $ServiceName, '--no-pager'); Effect = 'Inspect an existing Crewly service.' },
      @{ Name = 'crewly-path'; Executable = 'find'; Arguments = @('/opt/crewly', '-maxdepth', '2', '-mindepth', '1', '-type', 'd'); Effect = 'Inspect only the approved Crewly application path.' }
    )
    Invoke-InspectionSet -Checks $checks
  }

  'InspectCrewlyPrerequisites' {
    $checks = @(
      @{ Name = 'git'; Executable = 'git'; Arguments = @('--version'); Effect = 'Read Git version.' },
      @{ Name = 'tmux'; Executable = 'tmux'; Arguments = @('-V'); Effect = 'Read tmux version.' },
      @{ Name = 'curl'; Executable = 'curl'; Arguments = @('--version'); Effect = 'Read curl version.' },
      @{ Name = 'codex'; Executable = 'codex'; Arguments = @('--version'); Effect = 'Read Codex CLI availability.' },
      @{ Name = 'claude'; Executable = 'claude'; Arguments = @('--version'); Effect = 'Read Claude CLI availability without installing it.' },
      @{ Name = 'gemini'; Executable = 'gemini'; Arguments = @('--version'); Effect = 'Read Gemini CLI availability without installing it.' },
      @{ Name = 'crewly-home'; Executable = 'find'; Arguments = @('/opt/crewly/shared/crewly-home', '-maxdepth', '1', '-mindepth', '1'); Effect = 'Inspect the isolated Crewly home path.' }
    )
    Invoke-InspectionSet -Checks $checks
  }

  'PrepareDeploymentDryRun' {
    if (-not $DryRun) {
      Fail-Restricted 'DRY_RUN_REQUIRED' 'PrepareDeploymentDryRun never connects and requires -DryRun.'
    }
    $sha = Get-EffectiveReleaseSha
    $branch = (& git -C $RepoRoot branch --show-current).Trim()
    $status = & git -C $RepoRoot status --porcelain
    Write-Output 'DRY_RUN=true'
    Write-Output "OPERATION=$Operation"
    Write-Output "HOST=$AllowedHost"
    Write-Output "REPO_ROOT=$RepoRoot"
    Write-Output "BRANCH=$branch"
    Write-Output "RELEASE_SHA=$sha"
    Write-Output "WORKING_TREE_CLEAN=$([string]::IsNullOrWhiteSpace(($status -join '')))"
    Write-Output 'EXECUTABLE=git/npm/tar (local plan only)'
    Write-Output 'EXPECTED_EFFECT=Validate clean source, build Crewly, package one immutable release archive, and calculate SHA-256 without contacting the VPS.'
  }

  'UploadRelease' {
    $sha = Get-EffectiveReleaseSha
    $pathValue = if ($LocalPath) { $LocalPath } else { "dist/crewly-$sha.tgz" }
    $artifact = Resolve-AllowedLocalArtifact -PathValue $pathValue -AllowMissing:$DryRun
    $checksum = $ExpectedChecksum
    if (Test-Path -LiteralPath $artifact -PathType Leaf) {
      $actual = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($checksum) {
        $expected = Assert-Checksum $checksum
        if ($actual -ne $expected) { Fail-Restricted 'LOCAL_CHECKSUM_MISMATCH' 'The release artifact does not match its expected SHA-256.' }
      } else {
        $checksum = $actual
      }
    } elseif (-not $DryRun) {
      Fail-Restricted 'LOCAL_ARTIFACT_NOT_FOUND' 'The release artifact does not exist.'
    } else {
      $checksum = '<required-at-execution>'
    }
    $remoteArtifact = "/tmp/crewly-deploy/crewly-$sha.tgz"
    $scpArguments = @('-o', 'BatchMode=yes', '-o', "ConnectTimeout=$ConnectionTimeoutSeconds", $artifact, "$AllowedHost`:$remoteArtifact")
    if ($DryRun) {
      Write-DryRunInvocation -Executable 'scp' -Arguments $scpArguments -Effect "Upload one validated immutable release and verify SHA-256 $checksum locally and remotely." -RemotePath $remoteArtifact
      return
    }
    Invoke-RemoteProgram -RemoteExecutable 'mkdir' -RemoteArguments @('-p', '/tmp/crewly-deploy') -Effect 'Create the fixed staging directory.' -RemotePath '/tmp/crewly-deploy'
    Invoke-ProcessChecked -Executable 'scp' -Arguments $scpArguments -Seconds $TimeoutSeconds | Out-Null
    $remoteHashOutput = Invoke-RemoteProgram -RemoteExecutable 'sha256sum' -RemoteArguments @($remoteArtifact) -Effect 'Verify the uploaded release checksum.' -RemotePath $remoteArtifact
    $remoteHash = (($remoteHashOutput -split '\s+')[0]).ToLowerInvariant()
    if ($remoteHash -ne $checksum) { Fail-Restricted 'REMOTE_CHECKSUM_MISMATCH' 'The uploaded artifact checksum differs from the validated local checksum.' }
    Write-Output "CHECKSUM_VERIFIED=$checksum"
  }

  'InstallRelease' {
    $sha = Get-EffectiveReleaseSha
    $releasePath = "/opt/crewly/releases/$sha"
    $artifactPath = "/tmp/crewly-deploy/crewly-$sha.tgz"
    $backupValue = if ($BackupId) { Assert-BackupId $BackupId } elseif ($DryRun) { '<required-backup-id>' } else { Fail-Restricted 'BACKUP_REQUIRED' 'InstallRelease requires a validated backup id.' }
    if ($DryRun) {
      Invoke-RemoteProgram -RemoteExecutable 'test' -RemoteArguments @('-f', "/opt/crewly/shared/backups/$backupValue/manifest.sha256") -Effect 'Require a valid backup manifest before installation.' -RemotePath '/opt/crewly/shared/backups'
      Invoke-RemoteProgram -RemoteExecutable 'mkdir' -RemoteArguments @('-p', $releasePath) -Effect 'Create a new immutable release directory without overwriting prior releases.' -RemotePath $releasePath
      Invoke-RemoteProgram -RemoteExecutable 'tar' -RemoteArguments @('-xzf', $artifactPath, '-C', $releasePath, '--strip-components=1') -Effect 'Extract only the validated release archive.' -RemotePath $releasePath
      Invoke-RemoteProgram -RemoteExecutable 'ln' -RemoteArguments @('-sfn', $releasePath, '/opt/crewly/current.next') -Effect 'Prepare an atomic current-release link.' -RemotePath '/opt/crewly'
      Invoke-RemoteProgram -RemoteExecutable 'mv' -RemoteArguments @('-Tf', '/opt/crewly/current.next', '/opt/crewly/current') -Effect 'Atomically activate the versioned release.' -RemotePath '/opt/crewly'
      return
    }
    Invoke-RemoteProgram -RemoteExecutable 'test' -RemoteArguments @('-f', "/opt/crewly/shared/backups/$backupValue/manifest.sha256") -Effect 'Require a valid backup manifest.' -RemotePath '/opt/crewly/shared/backups'
    Invoke-RemoteProgram -RemoteExecutable 'test' -RemoteArguments @('!', '-e', $releasePath) -Effect 'Refuse to overwrite an existing release.' -RemotePath $releasePath
    Invoke-RemoteProgram -RemoteExecutable 'mkdir' -RemoteArguments @('-p', $releasePath) -Effect 'Create the versioned release directory.' -RemotePath $releasePath
    Invoke-RemoteProgram -RemoteExecutable 'tar' -RemoteArguments @('-xzf', $artifactPath, '-C', $releasePath, '--strip-components=1') -Effect 'Extract the validated release.' -RemotePath $releasePath
    Invoke-RemoteProgram -RemoteExecutable 'ln' -RemoteArguments @('-sfn', $releasePath, '/opt/crewly/current.next') -Effect 'Prepare the atomic release link.' -RemotePath '/opt/crewly'
    Invoke-RemoteProgram -RemoteExecutable 'mv' -RemoteArguments @('-Tf', '/opt/crewly/current.next', '/opt/crewly/current') -Effect 'Activate the release atomically.' -RemotePath '/opt/crewly'
  }

  'ConfigureService' {
    Fail-Restricted 'LIVE_INSPECTION_REQUIRED' 'Service configuration remains locked until InspectHost validates the process manager and exact service path.'
  }

  'Start' { Invoke-RemoteProgram -RemoteExecutable 'sudo' -RemoteArguments @('-n', 'systemctl', 'start', $ServiceName) -Effect 'Start only the approved Crewly service.' }
  'Stop' { Invoke-RemoteProgram -RemoteExecutable 'sudo' -RemoteArguments @('-n', 'systemctl', 'stop', $ServiceName) -Effect 'Stop only the approved Crewly service.' }
  'Restart' { Invoke-RemoteProgram -RemoteExecutable 'sudo' -RemoteArguments @('-n', 'systemctl', 'restart', $ServiceName) -Effect 'Restart only the approved Crewly service.' }
  'Status' { Invoke-RemoteProgram -RemoteExecutable 'systemctl' -RemoteArguments @('status', $ServiceName, '--no-pager') -Effect 'Read Crewly service status.' }
  'Health' { Invoke-RemoteProgram -RemoteExecutable 'curl' -RemoteArguments @('--fail', '--silent', '--show-error', "http://127.0.0.1:$InternalPort/health") -Effect 'Read the loopback-only Crewly health endpoint.' }
  'Logs' { Invoke-RemoteProgram -RemoteExecutable 'journalctl' -RemoteArguments @('-u', $ServiceName, '-n', "$LogLines", '--no-pager', '--output=short-iso') -Effect "Read at most $LogLines sanitized service log lines." }

  'Backup' {
    $sha = Get-EffectiveReleaseSha
    Invoke-RemoteProgram -RemoteExecutable '/opt/crewly/current/scripts/crewly-vps-backup.sh' -RemoteArguments @('backup', $sha) -Effect 'Create a timestamped Crewly-only archive and SHA-256 manifest under the fixed backup path.' -RemotePath '/opt/crewly/shared/backups'
  }

  'ListBackups' { Invoke-RemoteProgram -RemoteExecutable '/opt/crewly/current/scripts/crewly-vps-backup.sh' -RemoteArguments @('list') -Effect 'List Crewly backup artifacts without reading other paths.' -RemotePath '/opt/crewly/shared/backups' }

  'RestoreDryRun' {
    $backupValue = if ($BackupId) { Assert-BackupId $BackupId } elseif ($DryRun) { '<required-backup-id>' } else { Fail-Restricted 'BACKUP_REQUIRED' 'RestoreDryRun requires a backup id.' }
    Invoke-RemoteProgram -RemoteExecutable '/opt/crewly/current/scripts/crewly-vps-backup.sh' -RemoteArguments @('restore-dry-run', $backupValue) -Effect 'Verify the selected Crewly backup archive and checksum without applying it.' -RemotePath '/opt/crewly/shared/backups'
  }

  'RollbackDryRun' {
    $sha = if ($ReleaseSha) { Assert-ReleaseSha $ReleaseSha } elseif ($DryRun) { '<existing-release-sha>' } else { Fail-Restricted 'RELEASE_SHA_REQUIRED' 'RollbackDryRun requires an existing release SHA.' }
    Invoke-RemoteProgram -RemoteExecutable 'test' -RemoteArguments @('-d', "/opt/crewly/releases/$sha") -Effect 'Verify that the rollback release exists without changing current.' -RemotePath '/opt/crewly/releases'
  }

  'Rollback' {
    $sha = Assert-ReleaseSha $ReleaseSha
    $releasePath = "/opt/crewly/releases/$sha"
    Invoke-RemoteProgram -RemoteExecutable 'test' -RemoteArguments @('-d', $releasePath) -Effect 'Require an existing immutable release.' -RemotePath $releasePath
    Invoke-RemoteProgram -RemoteExecutable 'ln' -RemoteArguments @('-sfn', $releasePath, '/opt/crewly/current.next') -Effect 'Prepare the rollback link without deleting releases.' -RemotePath '/opt/crewly'
    Invoke-RemoteProgram -RemoteExecutable 'mv' -RemoteArguments @('-Tf', '/opt/crewly/current.next', '/opt/crewly/current') -Effect 'Atomically roll back current to the selected existing release.' -RemotePath '/opt/crewly'
    Invoke-RemoteProgram -RemoteExecutable 'sudo' -RemoteArguments @('-n', 'systemctl', 'restart', $ServiceName) -Effect 'Restart only Crewly after rollback.'
  }

  'RunFixture' {
    Invoke-RemoteProgram -RemoteExecutable '/opt/crewly/current/scripts/crewly-vps-fixture.sh' -RemoteArguments @('run') -Effect 'Create and run only the disposable Crewly fixture under the fixed fixture path.' -RemotePath $FixturePath
  }

  'CleanupFixture' {
    Invoke-RemoteProgram -RemoteExecutable '/opt/crewly/current/scripts/crewly-vps-fixture.sh' -RemoteArguments @('cleanup') -Effect 'Remove only the wrapper-created disposable fixture.' -RemotePath $FixturePath
  }
}
