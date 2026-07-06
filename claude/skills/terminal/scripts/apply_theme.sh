#!/usr/bin/env bash
# Applies a VS Code terminal color theme to the current project's .vscode/settings.json.
# Usage: apply_theme.sh <dark|light> [target-directory]
set -euo pipefail

THEME="${1:-}"
TARGET_DIR="${2:-$(pwd)}"

if [[ "$THEME" != "dark" && "$THEME" != "light" ]]; then
  echo "Error: theme argument must be 'dark' or 'light' (got: '${THEME}')" >&2
  exit 1
fi

VSCODE_DIR="${TARGET_DIR}/.vscode"
GITIGNORE_FILE="${VSCODE_DIR}/.gitignore"
SETTINGS_FILE="${VSCODE_DIR}/settings.json"

mkdir -p "$VSCODE_DIR"

# Ensure .vscode/.gitignore contains a line that is exactly "*"
if [[ -f "$GITIGNORE_FILE" ]]; then
  if ! grep -qxF '*' "$GITIGNORE_FILE"; then
    printf '%s\n' '*' >> "$GITIGNORE_FILE"
    echo "Appended '*' to existing ${GITIGNORE_FILE}"
  else
    echo "${GITIGNORE_FILE} already ignores everything, left untouched"
  fi
else
  printf '%s\n' '*' > "$GITIGNORE_FILE"
  echo "Created ${GITIGNORE_FILE}"
fi

# Write (or overwrite) settings.json with the requested theme's terminal colors
if [[ "$THEME" == "dark" ]]; then
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "workbench.colorCustomizations": {
    "terminal.background": "#1e1e1e",
    "terminal.foreground": "#d4d4d4",
    "terminalCursor.background": "#1e1e1e",
    "terminalCursor.foreground": "#d4d4d4",

    "terminal.ansiBlack": "#000000",
    "terminal.ansiRed": "#cd3131",
    "terminal.ansiGreen": "#0dbc79",
    "terminal.ansiYellow": "#e5e510",
    "terminal.ansiBlue": "#2472c8",
    "terminal.ansiMagenta": "#bc3fbc",
    "terminal.ansiCyan": "#11a8cd",
    "terminal.ansiWhite": "#e5e5e5",

    "terminal.ansiBrightBlack": "#666666",
    "terminal.ansiBrightRed": "#f14c4c",
    "terminal.ansiBrightGreen": "#23d18b",
    "terminal.ansiBrightYellow": "#f5f543",
    "terminal.ansiBrightBlue": "#3b8eea",
    "terminal.ansiBrightMagenta": "#d670d6",
    "terminal.ansiBrightCyan": "#29b8db",
    "terminal.ansiBrightWhite": "#ffffff"
  }
}
EOF
else
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "workbench.colorCustomizations": {
    "terminal.background": "#ffffff",
    "terminal.foreground": "#333333",
    "terminalCursor.background": "#ffffff",
    "terminalCursor.foreground": "#333333",

    "terminal.ansiBlack": "#000000",
    "terminal.ansiRed": "#d9534f",
    "terminal.ansiGreen": "#5cb85c",
    "terminal.ansiYellow": "#f0ad4e",
    "terminal.ansiBlue": "#0275d8",
    "terminal.ansiMagenta": "#d9534f",
    "terminal.ansiCyan": "#17a2b8",
    "terminal.ansiWhite": "#e9ecef",

    "terminal.ansiBrightBlack": "#6c757d",
    "terminal.ansiBrightRed": "#e06c75",
    "terminal.ansiBrightGreen": "#98c379",
    "terminal.ansiBrightYellow": "#e5c07b",
    "terminal.ansiBrightBlue": "#61afef",
    "terminal.ansiBrightMagenta": "#c678dd",
    "terminal.ansiBrightCyan": "#56b6c2",
    "terminal.ansiBrightWhite": "#ffffff"
  }
}
EOF
fi

echo "Wrote ${THEME} terminal theme to ${SETTINGS_FILE}"
