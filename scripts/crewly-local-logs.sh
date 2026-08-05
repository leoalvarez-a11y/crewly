#!/usr/bin/env bash
set -euo pipefail

export CREWLY_HOME="/home/zytto/.crewly"
readonly LOG_FILE="${CREWLY_HOME}/logs/crewly-local.log"
lines=100
follow_seconds=0

usage() {
  echo "Usage: crewly-local-logs.sh [--lines 1-500] [--follow] [--follow-seconds 1-300]"
}

while (( $# > 0 )); do
  case "$1" in
    -n|--lines)
      [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || { usage >&2; exit 40; }
      lines="$2"
      shift 2
      ;;
    -f|--follow)
      follow_seconds=120
      shift
      ;;
    --follow-seconds)
      [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || { usage >&2; exit 40; }
      follow_seconds="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unsupported argument: $1" >&2
      usage >&2
      exit 40
      ;;
  esac
done

if (( lines < 1 || lines > 500 || follow_seconds < 0 || follow_seconds > 300 )); then
  echo "ERROR: Requested log range is outside the allowed bounds." >&2
  exit 41
fi

if [[ ! -f "${LOG_FILE}" ]]; then
  echo "No Crewly local log exists yet at ${LOG_FILE}."
  exit 0
fi

if (( follow_seconds > 0 )); then
  echo "Showing the last ${lines} lines and following for at most ${follow_seconds} seconds."
  timeout --foreground "${follow_seconds}" tail -n "${lines}" -F "${LOG_FILE}" || status=$?
  if [[ "${status:-0}" -ne 0 && "${status:-0}" -ne 124 ]]; then
    exit "${status}"
  fi
else
  tail -n "${lines}" "${LOG_FILE}"
fi
