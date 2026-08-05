#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/opt/crewly/shared/backups"
CREWLY_HOME_PATH="/opt/crewly/shared/crewly-home"
CREWLY_CLI="/opt/crewly/current/dist/cli/cli/src/index.js"

assert_backup_id() {
  [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-fA-F]{8,40}$ ]] || {
    printf '%s\n' 'INVALID_BACKUP_ID' >&2
    exit 64
  }
}

case "${1:-}" in
  backup)
    release_sha="${2:-}"
    [[ "$release_sha" =~ ^[0-9a-fA-F]{40}$ ]] || { printf '%s\n' 'INVALID_RELEASE_SHA' >&2; exit 64; }
    backup_id="$(date -u +%Y%m%dT%H%M%SZ)-${release_sha:0:12}"
    backup_path="$BACKUP_ROOT/$backup_id"
    [[ ! -e "$backup_path" ]] || { printf '%s\n' 'BACKUP_ALREADY_EXISTS' >&2; exit 17; }
    mkdir -p "$backup_path"
    export CREWLY_HOME="$CREWLY_HOME_PATH"
    node "$CREWLY_CLI" backup create --out "$backup_path/crewly-workspace.tar.gz"
    (
      cd "$backup_path"
      sha256sum "crewly-workspace.tar.gz" > "manifest.sha256"
    )
    printf '%s\n' "BACKUP_ID=$backup_id" "BACKUP_PATH=$backup_path"
    ;;
  list)
    find "$BACKUP_ROOT" -maxdepth 2 -mindepth 1 -type f -print
    ;;
  restore-dry-run)
    backup_id="${2:-}"
    assert_backup_id "$backup_id"
    backup_path="$BACKUP_ROOT/$backup_id"
    [[ -f "$backup_path/crewly-workspace.tar.gz" && -f "$backup_path/manifest.sha256" ]] || {
      printf '%s\n' 'BACKUP_INCOMPLETE' >&2
      exit 66
    }
    (
      cd "$backup_path"
      sha256sum -c "manifest.sha256"
      export CREWLY_HOME="$CREWLY_HOME_PATH"
      node "$CREWLY_CLI" backup restore "crewly-workspace.tar.gz"
    )
    printf '%s\n' 'RESTORE_DRY_RUN=PASS'
    ;;
  *)
    printf '%s\n' 'USAGE: crewly-vps-backup.sh backup <sha>|list|restore-dry-run <backup-id>' >&2
    exit 64
    ;;
esac
