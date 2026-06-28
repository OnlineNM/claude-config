#!/usr/bin/env bash
# Hook script: sends a Telegram notification when Claude Code needs user attention.
# Handles both Notification events (waiting for answer) and PermissionRequest events (approve action).
# Runs async so it never delays the UI prompt.

set -euo pipefail

# Load environment from current process or fallback file.
# shellcheck source=/dev/null
. "$HOME/.claude/scripts/load-env.sh"

# If credentials are still missing, skip notification without failing the hook.
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "Telegram credentials not set; skipping notification."
  exit 0
fi

HOOK_DATA=$(cat)

MSG=$(echo "$HOOK_DATA" | python3 -c "
import sys, json

data = json.load(sys.stdin)
tool_name = data.get('tool_name', '')

if tool_name:
    # PermissionRequest event
    tool_input = data.get('tool_input', {})
    lines = ['Claude needs your approval!', '', f'Tool: {tool_name}']

    if tool_name == 'Bash':
        cmd = tool_input.get('command', '')
        lines.append(f'Command: {cmd[:400]}')
    elif tool_name in ('Write', 'Edit', 'NotebookEdit'):
        path = tool_input.get('file_path', tool_input.get('notebook_path', ''))
        lines.append(f'File: {path}')
    elif tool_name == 'WebFetch':
        lines.append(f'URL: {tool_input.get(\"url\", \"\")}')
    elif tool_name == 'WebSearch':
        lines.append(f'Query: {tool_input.get(\"query\", \"\")}')
    else:
        for k, v in list(tool_input.items())[:3]:
            lines.append(f'{k}: {str(v)[:150]}')
else:
    # Notification event
    title = data.get('title', '')
    message = data.get('message', '')
    lines = ['Claude needs your attention!']
    if title:
        lines.append(f'Title: {title}')
    if message:
        lines.append('')
        lines.extend(message.strip().splitlines()[-5:])

print('\n'.join(lines))
" 2>/dev/null || echo "Claude needs your attention!")

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -o /dev/null || true

exit 0