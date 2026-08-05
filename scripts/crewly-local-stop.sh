#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
export CREWLY_HOME="/home/zytto/.crewly"

readonly RUNTIME_DIR="${CREWLY_HOME}/run"
readonly PID_FILE="${RUNTIME_DIR}/crewly-local.pid"
readonly DASHBOARD_URL="http://localhost:8787"
readonly HEALTH_URL="${DASHBOARD_URL}/health"
readonly CLI_PATH="${REPO_ROOT}/dist/cli/cli/src/index.js"
readonly BACKEND_PATH="${REPO_ROOT}/dist/backend/backend/src/index.js"

mkdir -p "${RUNTIME_DIR}"

health_ok() {
  curl --fail --silent --max-time 2 "${HEALTH_URL}" >/dev/null 2>&1
}

owned_process_kind() {
  local pid="${1:-}"
  local command_line
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  [[ -r "/proc/${pid}/cmdline" ]] || return 1
  command_line="$(tr '\0' ' ' < "/proc/${pid}/cmdline")"
  if [[ "${command_line}" == *"${CLI_PATH} start"* ]]; then
    printf 'supervisor\n'
    return 0
  fi
  if [[ "${command_line}" == *"${BACKEND_PATH}"* ]]; then
    printf 'backend\n'
    return 0
  fi
  return 1
}

discover_owned_pids() {
  local proc_dir pid
  for proc_dir in /proc/[0-9]*; do
    pid="${proc_dir##*/}"
    [[ "$(stat -c '%u' "${proc_dir}" 2>/dev/null || true)" == "$(id -u)" ]] || continue
    if owned_process_kind "${pid}" >/dev/null; then
      printf '%s\n' "${pid}"
    fi
  done
}

wait_for_exit() {
  local pid="$1"
  local seconds="$2"
  local _
  for _ in $(seq 1 "${seconds}"); do
    kill -0 "${pid}" 2>/dev/null || return 0
    sleep 1
  done
  return 1
}

declare -a targets=()
if [[ -f "${PID_FILE}" ]]; then
  pid="$(<"${PID_FILE}")"
  if owned_process_kind "${pid}" >/dev/null; then
    targets+=("${pid}")
  else
    rm -f "${PID_FILE}"
  fi
fi

while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  if [[ ! " ${targets[*]:-} " == *" ${pid} "* ]]; then
    targets+=("${pid}")
  fi
done < <(discover_owned_pids)

for pid in "${targets[@]}"; do
  if [[ "$(owned_process_kind "${pid}" 2>/dev/null || true)" == "supervisor" ]]; then
    echo "Stopping Crewly supervisor PID ${pid}."
    kill -TERM "${pid}" 2>/dev/null || true
  fi
done

for pid in "${targets[@]}"; do
  if ! wait_for_exit "${pid}" 20; then
    if owned_process_kind "${pid}" >/dev/null; then
      echo "Crewly process ${pid} did not stop cleanly; terminating it."
      kill -TERM "${pid}" 2>/dev/null || true
      wait_for_exit "${pid}" 8 || {
        owned_process_kind "${pid}" >/dev/null && kill -KILL "${pid}" 2>/dev/null || true
      }
    fi
  fi
done

# Remove only agent sessions that use Crewly's reserved tmux prefix.
if command -v tmux >/dev/null 2>&1; then
  while IFS= read -r session; do
    [[ "${session}" == crewly_* ]] || continue
    echo "Stopping orphaned Crewly agent session ${session}."
    tmux kill-session -t "${session}" 2>/dev/null || true
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
fi

# A backend can outlive its supervisor after an interrupted shutdown. Match the
# exact checkout path so unrelated Node.js and PTY processes are never touched.
while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  if owned_process_kind "${pid}" >/dev/null; then
    echo "Stopping orphaned Crewly process PID ${pid}."
    kill -TERM "${pid}" 2>/dev/null || true
    wait_for_exit "${pid}" 8 || {
      owned_process_kind "${pid}" >/dev/null && kill -KILL "${pid}" 2>/dev/null || true
    }
  fi
done < <(discover_owned_pids)

rm -f "${PID_FILE}"

if health_ok; then
  echo "ERROR: ${HEALTH_URL} is still responding, but no process owned by this checkout can be safely stopped." >&2
  exit 30
fi

echo "Crewly is stopped; no checkout-owned process or Crewly tmux session remains."
