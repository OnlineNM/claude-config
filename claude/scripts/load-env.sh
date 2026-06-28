#!/usr/bin/env bash
# Shared environment loader for Claude hook scripts.
# Prefers already-exported environment variables and falls back to the Docker Compose .env file.

# Do not enable set -e/-u here; this file is meant to be sourced safely.

ENV_FILE="$HOME/.claude/.env"

# If required vars are already present, keep them.
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  return 0 2>/dev/null || exit 0
fi

# Fall back to the compose .env file if present.
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

return 0 2>/dev/null || exit 0