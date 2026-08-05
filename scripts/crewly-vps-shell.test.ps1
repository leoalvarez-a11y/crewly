$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "ASSERTION_FAILED $Message" }
}

$fixturePath = Join-Path $PSScriptRoot 'crewly-vps-fixture.sh'
$backupPath = Join-Path $PSScriptRoot 'crewly-vps-backup.sh'
$fixture = Get-Content -Raw -LiteralPath $fixturePath
$backup = Get-Content -Raw -LiteralPath $backupPath

Assert-True ($fixture -match 'FIXTURE_ROOT="/tmp/crewly-deploy/fixture"') 'Fixture root must be fixed.'
Assert-True ($fixture -match '/tmp/crewly-deploy/fixture\) rm -rf -- "\$FIXTURE_ROOT"') 'Fixture cleanup must be exact and scoped.'
Assert-True (-not ($fixture -match '(?m)\beval\b')) 'Fixture helper must not use eval.'
Assert-True ($backup -match 'BACKUP_ROOT="/opt/crewly/shared/backups"') 'Backup root must be fixed.'
Assert-True ($backup -match 'backup create --out "\$backup_path/crewly-workspace\.tar\.gz"') 'Backup helper must use Crewly native backup creation.'
Assert-True ($backup -match 'sha256sum "crewly-workspace\.tar\.gz" > "manifest\.sha256"') 'Backup helper must persist a checksum manifest.'
Assert-True ($backup -match 'sha256sum -c "manifest\.sha256"') 'Restore dry-run must verify the checksum.'
Assert-True ($backup -match 'backup restore "crewly-workspace\.tar\.gz"') 'Restore dry-run must use Crewly native preview mode.'
Assert-True (-not ($backup -match '(?m)\beval\b')) 'Backup helper must not use eval.'

Write-Output 'CREWLY_VPS_SHELL_HELPER_TESTS=PASS'
