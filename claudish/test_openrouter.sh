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

load_model_rows() {
  if command -v jq >/dev/null 2>&1; then
    if [[ -n "$PROFILE_FILTER" ]]; then
      jq -r --arg profile "$PROFILE_FILTER" '.profiles[$profile].models | to_entries[] | [$profile, .key, .value] | @tsv' "$CONFIG_FILE" 2>/dev/null
    else
      jq -r '.profiles | to_entries[] | .key as $profile | .value.models | to_entries[] | [$profile, .key, .value] | @tsv' "$CONFIG_FILE" 2>/dev/null
    fi
  elif [[ "$(uname)" == "Darwin" ]] && command -v python3 >/dev/null 2>&1; then
    if [[ -n "$PROFILE_FILTER" ]]; then
      python3 - "$CONFIG_FILE" "$PROFILE_FILTER" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)

profile = sys.argv[2]
models = data.get('profiles', {}).get(profile, {}).get('models', {})
for role, model in models.items():
    print(f"{profile}\t{role}\t{model}")
PY
    else
      python3 - "$CONFIG_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)

for profile, payload in data.get('profiles', {}).items():
    for role, model in payload.get('models', {}).items():
        print(f"{profile}\t{role}\t{model}")
PY
    fi
  else
    echo "jq is required but was not found in PATH." >&2
    exit 1
  fi
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

if ! command -v claudish >/dev/null 2>&1; then
  echo "claudish is required but was not found in PATH." >&2
  exit 1
fi

MODEL_ROWS=()
while IFS=$'\t' read -r profile role model; do
  [[ -z "$profile" && -z "$role" && -z "$model" ]] && continue
  MODEL_ROWS+=("$profile"$'\t'"$role"$'\t'"$model")
done < <(load_model_rows)

if [[ ${#MODEL_ROWS[@]} -eq 0 ]]; then
  echo "No models found in $CONFIG_FILE" >&2
  exit 1
fi

for index in "${!MODEL_ROWS[@]}"; do
  row="${MODEL_ROWS[$index]}"
  IFS=$'\t' read -r profile role model <<< "$row"
  run_one "$profile" "$role" "$model"
  if [[ $index -lt $(( ${#MODEL_ROWS[@]} - 1 )) ]]; then
    echo ""
  fi
done
