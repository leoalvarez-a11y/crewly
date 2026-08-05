#!/usr/bin/env bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${TEST_DIR}/.." && pwd)"

for script in crewly-local-start.sh crewly-local-stop.sh crewly-local-status.sh crewly-local-logs.sh; do
  bash -n "${REPO_ROOT}/scripts/${script}"
  grep -q '^set -euo pipefail$' "${REPO_ROOT}/scripts/${script}"
done

grep -q 'START_TIMEOUT_SECONDS=90' "${REPO_ROOT}/scripts/crewly-local-start.sh"
grep -q 'start --no-browser' "${REPO_ROOT}/scripts/crewly-local-start.sh"
grep -q 'crewly_\*' "${REPO_ROOT}/scripts/crewly-local-stop.sh"
grep -q 'branch:' "${REPO_ROOT}/scripts/crewly-local-status.sh"

if "${REPO_ROOT}/scripts/crewly-local-logs.sh" --lines '1;whoami' >/dev/null 2>&1; then
  echo "logs script accepted an unsafe line value" >&2
  exit 1
fi

if "${REPO_ROOT}/scripts/crewly-local-logs.sh" --unknown >/dev/null 2>&1; then
  echo "logs script accepted an arbitrary argument" >&2
  exit 1
fi

echo "Crewly local script checks passed."
