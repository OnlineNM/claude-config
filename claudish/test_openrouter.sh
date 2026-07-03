#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.json}"
PROMPT="${1:-Spune doar OK}"
PROFILE_FILTER="${2:-${PROFILE:-}}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

have_timeout() {
  command -v timeout >/dev/null 2>&1
}

run_one() {
  local profile="$1"
  local role="$2"
  local model="$3"
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  echo -e "${YELLOW}Testing:${NC} [$profile/$role] $model"

  if have_timeout; then
    timeout "$TIMEOUT_SECONDS" \
      claudish --model "$model" --json "$PROMPT" \
      >"$stdout_file" 2>"$stderr_file"
  else
    claudish --model "$model" --json "$PROMPT" \
      >"$stdout_file" 2>"$stderr_file"
  fi

  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    local result
    result="$(jq -r '.result // "NO_RESULT"' "$stdout_file" 2>/dev/null)"
    local cost
    cost="$(jq -r '.total_cost_usd // "n/a"' "$stdout_file" 2>/dev/null)"
    echo -e "${GREEN}OK${NC}   [$profile/$role] $model | cost=$cost | result=${result:0:80}"
  else
    local err
    err="$(head -n 3 "$stderr_file" | tr '\n' ' ' | sed 's/  */ /g')"
    [[ -z "$err" ]] && err="$(head -c 200 "$stdout_file")"
    echo -e "${RED}FAIL${NC} [$profile/$role] $model | exit=$exit_code | $err"
  fi

  rm -f "$stdout_file" "$stderr_file"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but was not found in PATH." >&2
  exit 1
fi

if ! command -v claudish >/dev/null 2>&1; then
  echo "claudish is required but was not found in PATH." >&2
  exit 1
fi

if [[ -n "$PROFILE_FILTER" ]]; then
  mapfile -t MODEL_ROWS < <(jq -r --arg profile "$PROFILE_FILTER" '.profiles[$profile].models | to_entries[] | [$profile, .key, .value] | @tsv' "$CONFIG_FILE" 2>/dev/null)
else
  mapfile -t MODEL_ROWS < <(jq -r '.profiles | to_entries[] | .key as $profile | .value.models | to_entries[] | [$profile, .key, .value] | @tsv' "$CONFIG_FILE" 2>/dev/null)
fi

if [[ ${#MODEL_ROWS[@]} -eq 0 ]]; then
  echo "No models found in $CONFIG_FILE" >&2
  exit 1
fi

for row in "${MODEL_ROWS[@]}"; do
  IFS=$'\t' read -r profile role model <<< "$row"
  run_one "$profile" "$role" "$model"
done
