#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
export CREWLY_HOME="/home/zytto/.crewly"

readonly PID_FILE="${CREWLY_HOME}/run/crewly-local.pid"
readonly LOG_FILE="${CREWLY_HOME}/logs/crewly-local.log"
readonly DASHBOARD_URL="http://localhost:8787"
readonly HEALTH_URL="${DASHBOARD_URL}/health"
readonly CLI_PATH="${REPO_ROOT}/dist/cli/cli/src/index.js"

pid="unknown"
running="stopped"
if [[ -f "${PID_FILE}" ]]; then
  candidate="$(<"${PID_FILE}")"
  if [[ "${candidate}" =~ ^[0-9]+$ ]] && kill -0 "${candidate}" 2>/dev/null && [[ -r "/proc/${candidate}/cmdline" ]]; then
    command_line="$(tr '\0' ' ' < "/proc/${candidate}/cmdline")"
    if [[ "${command_line}" == *"${CLI_PATH} start"* ]]; then
      pid="${candidate}"
      running="running"
    fi
  fi
fi

if curl --fail --silent --max-time 2 "${HEALTH_URL}" >/dev/null 2>&1; then
  health="PASS"
  running="running"
else
  health="FAIL"
fi

branch="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null || printf 'unknown')"
head="$(git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || printf 'unknown')"

printf 'status: %s\n' "${running}"
printf 'pid: %s\n' "${pid}"
printf 'health: %s\n' "${health}"
printf 'url: %s\n' "${DASHBOARD_URL}"
printf 'logs: %s\n' "${LOG_FILE}"
printf 'branch: %s\n' "${branch}"
printf 'head: %s\n' "${head}"
