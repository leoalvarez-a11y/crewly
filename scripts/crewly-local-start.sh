#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
export CREWLY_HOME="/home/zytto/.crewly"

readonly RUNTIME_DIR="${CREWLY_HOME}/run"
readonly LOG_DIR="${CREWLY_HOME}/logs"
readonly PID_FILE="${RUNTIME_DIR}/crewly-local.pid"
readonly LOCK_DIR="${RUNTIME_DIR}/crewly-local-start.lock"
readonly LOG_FILE="${LOG_DIR}/crewly-local.log"
readonly SYSTEMD_UNIT="crewly-local.service"
readonly DASHBOARD_URL="http://localhost:8787"
readonly HEALTH_URL="${DASHBOARD_URL}/health"
readonly CLI_PATH="${REPO_ROOT}/dist/cli/cli/src/index.js"
readonly BACKEND_PATH="${REPO_ROOT}/dist/backend/backend/src/index.js"
readonly START_TIMEOUT_SECONDS=90

mkdir -p "${RUNTIME_DIR}" "${LOG_DIR}"

if [[ -s "/home/zytto/.nvm/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  source "/home/zytto/.nvm/nvm.sh"
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is not available for user zytto." >&2
  exit 20
fi

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ ! "${node_major}" =~ ^[0-9]+$ ]] || (( node_major < 22 )); then
  echo "ERROR: Crewly requires Node.js 22 or newer; found $(node -v)." >&2
  exit 21
fi

if [[ ! -f "${CLI_PATH}" || ! -f "${BACKEND_PATH}" || ! -f "${REPO_ROOT}/frontend/dist/index.html" ]]; then
  echo "ERROR: Crewly build is missing. Run npm run build in ${REPO_ROOT}." >&2
  exit 22
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "ERROR: The zytto systemd user manager is not available in Ubuntu WSL2." >&2
  exit 26
fi

health_ok() {
  curl --fail --silent --show-error --max-time 2 "${HEALTH_URL}" >/dev/null 2>&1
}

pid_matches_checkout() {
  local pid="${1:-}"
  local command_line
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  [[ -r "/proc/${pid}/cmdline" ]] || return 1
  command_line="$(tr '\0' ' ' < "/proc/${pid}/cmdline")"
  [[ "${command_line}" == *"${CLI_PATH} start"* ]]
}

discover_supervisor_pid() {
  local proc_dir pid command_line
  for proc_dir in /proc/[0-9]*; do
    pid="${proc_dir##*/}"
    [[ -r "${proc_dir}/cmdline" ]] || continue
    [[ "$(stat -c '%u' "${proc_dir}" 2>/dev/null || true)" == "$(id -u)" ]] || continue
    command_line="$(tr '\0' ' ' < "${proc_dir}/cmdline" 2>/dev/null || true)"
    if [[ "${command_line}" == *"${CLI_PATH} start"* ]]; then
      printf '%s\n' "${pid}"
      return 0
    fi
  done
  return 1
}

record_running_pid() {
  local pid
  if [[ -f "${PID_FILE}" ]] && pid_matches_checkout "$(<"${PID_FILE}")"; then
    return 0
  fi
  pid="$(systemctl --user show --property=MainPID --value "${SYSTEMD_UNIT}" 2>/dev/null || true)"
  if pid_matches_checkout "${pid}"; then
    printf '%s\n' "${pid}" > "${PID_FILE}"
  elif pid="$(discover_supervisor_pid)"; then
    printf '%s\n' "${pid}" > "${PID_FILE}"
  else
    rm -f "${PID_FILE}"
  fi
}

if health_ok; then
  record_running_pid
  echo "Crewly is already healthy at ${DASHBOARD_URL}."
  exit 0
fi

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(<"${PID_FILE}")"
  if pid_matches_checkout "${existing_pid}"; then
    echo "Crewly startup is already in progress (PID ${existing_pid})."
  else
    rm -f "${PID_FILE}"
  fi
fi

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  for _ in $(seq 1 15); do
    if health_ok; then
      record_running_pid
      echo "Crewly is healthy at ${DASHBOARD_URL}."
      exit 0
    fi
    sleep 1
  done
  echo "ERROR: Another Crewly startup is still in progress." >&2
  exit 23
fi
trap 'rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT

if [[ -f "${LOG_FILE}" ]] && (( $(stat -c '%s' "${LOG_FILE}") > 10485760 )); then
  mv -f "${LOG_FILE}" "${LOG_FILE}.1"
fi

cd "${REPO_ROOT}"
systemctl --user stop "${SYSTEMD_UNIT}" >/dev/null 2>&1 || true
systemctl --user reset-failed "${SYSTEMD_UNIT}" >/dev/null 2>&1 || true
systemd-run --user \
  --unit="${SYSTEMD_UNIT%.service}" \
  --collect \
  --working-directory="${REPO_ROOT}" \
  --setenv="CREWLY_HOME=${CREWLY_HOME}" \
  --setenv="WEB_PORT=8787" \
  --property=Restart=no \
  --property="StandardOutput=append:${LOG_FILE}" \
  --property="StandardError=append:${LOG_FILE}" \
  "$(command -v node)" "${CLI_PATH}" start --no-browser >/dev/null

crewly_pid=""
for _ in $(seq 1 10); do
  crewly_pid="$(systemctl --user show --property=MainPID --value "${SYSTEMD_UNIT}" 2>/dev/null || true)"
  [[ "${crewly_pid}" =~ ^[1-9][0-9]*$ ]] && break
  sleep 1
done
if ! pid_matches_checkout "${crewly_pid}"; then
  echo "ERROR: The Crewly systemd user service did not create a valid supervisor process." >&2
  systemctl --user status "${SYSTEMD_UNIT}" --no-pager >&2 || true
  exit 27
fi
printf '%s\n' "${crewly_pid}" > "${PID_FILE}"
echo "Starting Crewly (PID ${crewly_pid}); log: ${LOG_FILE}"

for _ in $(seq 1 "${START_TIMEOUT_SECONDS}"); do
  if health_ok; then
    echo "Crewly is healthy at ${DASHBOARD_URL}."
    exit 0
  fi
  if ! kill -0 "${crewly_pid}" 2>/dev/null; then
    rm -f "${PID_FILE}"
    echo "ERROR: Crewly exited before becoming healthy. Recent log output:" >&2
    tail -n 20 "${LOG_FILE}" >&2 || true
    exit 24
  fi
  sleep 1
done

systemctl --user stop "${SYSTEMD_UNIT}" >/dev/null 2>&1 || true
rm -f "${PID_FILE}"
echo "ERROR: Crewly did not become healthy within ${START_TIMEOUT_SECONDS} seconds. See ${LOG_FILE}." >&2
exit 25
