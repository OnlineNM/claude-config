#!/bin/bash
# claude-code-setup.sh
# Claude Code provisioning script for Linux and macOS
# Run:     bash claude-code-setup.sh
# Upgrade: npm install -g @anthropic-ai/claude-code@latest

set -euo pipefail

# === LOAD .env ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
else
  echo "⚠ No .env file found at $ENV_FILE. Copy .env.sample to .env and fill in the values."
  exit 1
fi

# === CONFIGURATION ===
CLAUDE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
ACCOUNT_UUID="${CLAUDE_ACCOUNT_UUID:-}"
EMAIL="${CLAUDE_EMAIL:-}"
ORG_UUID="${CLAUDE_ORG_UUID:-}"

MARKETPLACES=(
  "https://github.com/mksglu/context-mode"
  "https://github.com/openai/codex-plugin-cc"
  "https://github.com/kepano/obsidian-skills"
  "https://github.com/bradautomates/claude-video"
  "https://github.com/forrestchang/andrej-karpathy-skills"
  "https://github.com/OnlineNM/claude-code-skills"
)

PLUGINS_OFFICIAL=(
  "context7@claude-plugins-official"
  "code-review@claude-plugins-official"
  "code-simplifier@claude-plugins-official"
  "feature-dev@claude-plugins-official"
  "firecrawl@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "remember@claude-plugins-official"
  "security-guidance@claude-plugins-official"
  "skill-creator@claude-plugins-official"
  "superpowers@claude-plugins-official"
)

PLUGINS_MARKETPLACE=(
  "codex@openai-codex"
  "context-mode@context-mode"
  "obsidian@obsidian-skills"
  "watch@claude-video"
  "andrej-karpathy-skills@karpathy-skills"
  "dbg@claude-skills-laur"
  "ppc@claude-skills-laur"
  "sdd@claude-skills-laur"
  "skill-check@claude-skills-laur"
  "telegram@claude-skills-laur"
  "wbs@claude-skills-laur"
  "pmpt@claude-skills-laur"
)

# === GIT INSTALLATION ===
install_git() {
  if ! command -v git &>/dev/null; then
    echo "→ Installing git..."
    if [[ "$(uname)" == "Darwin" ]]; then
      brew install git
    else
      sudo apt-get install -y git
    fi
  else
    echo "✓ git $(git --version | cut -d' ' -f3) already installed"
  fi
}

# === NODE.JS INSTALLATION ===
install_nodejs() {
  if ! command -v node &>/dev/null || [[ $(node --version | cut -d'v' -f2 | cut -d'.' -f1) -lt 18 ]]; then
    echo "→ Installing Node.js..."
    if [[ "$(uname)" == "Darwin" ]]; then
      if ! command -v brew &>/dev/null; then
        echo "✗ Homebrew is required to install Node.js on macOS. Install it from https://brew.sh"
        exit 1
      fi
      brew install node
    else
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
    fi
  else
    echo "✓ Node.js $(node --version) already installed"
  fi
}

# === CLAUDE CODE INSTALLATION ===
install_claude_code() {
  if ! command -v claude &>/dev/null; then
    echo "→ Installing Claude Code..."
    if [[ "$(uname)" == "Darwin" ]]; then
      npm install -g @anthropic-ai/claude-code
    else
      sudo npm install -g @anthropic-ai/claude-code
    fi
  else
    echo "✓ Claude Code $(claude --version) already installed"
  fi
}

# === AUTHENTICATION ===
setup_auth() {
  if [[ -z "$CLAUDE_OAUTH_TOKEN" ]]; then
    echo "⚠ CLAUDE_CODE_OAUTH_TOKEN is not set. Manual authentication will be required."
    return
  fi

  echo "→ Setting up authentication..."

  # Copy .env to ~/.claude/.env
  mkdir -p ~/.claude
  cp "$ENV_FILE" ~/.claude/.env
  chmod 600 ~/.claude/.env

  # Source ~/.claude/.env from shell config if not already present
  if [[ "$(uname)" == "Darwin" ]]; then
    SHELL_RC=~/.zshrc
  else
    SHELL_RC=~/.bashrc
  fi
  if ! grep -q "\.claude/\.env" "$SHELL_RC"; then
    echo '[ -f "$HOME/.claude/.env" ] && { set -a; source "$HOME/.claude/.env"; set +a; }' >> "$SHELL_RC"
  fi

  # Create ~/.claude.json to bypass onboarding
  CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "2.1.0")
  cat > ~/.claude.json << EOF
{
  "hasCompletedOnboarding": true,
  "lastOnboardingVersion": "$CLAUDE_VERSION",
  "oauthAccount": {
    "accountUuid": "$ACCOUNT_UUID",
    "emailAddress": "$EMAIL",
    "organizationUuid": "$ORG_UUID"
  }
}
EOF
  chmod 600 ~/.claude.json
  echo "✓ Authentication configured"
}

# === HOOKS & SCRIPTS SETUP ===
setup_hooks() {
  echo "→ Installing hooks and scripts..."
  mkdir -p ~/.claude/hooks ~/.claude/scripts

  cp "$SCRIPT_DIR/claude/hooks/context-mode-cache-heal.mjs" ~/.claude/hooks/
  chmod +x ~/.claude/hooks/context-mode-cache-heal.mjs

  cp "$SCRIPT_DIR/claude/ccstatusline-settings.json" ~/.claude/ccstatusline-settings.json

  cp "$SCRIPT_DIR/claude/scripts/job-done.sh" ~/.claude/scripts/
  cp "$SCRIPT_DIR/claude/scripts/notify-waiting.sh" ~/.claude/scripts/
  cp "$SCRIPT_DIR/claude/scripts/load-env.sh" ~/.claude/scripts/
  chmod +x ~/.claude/scripts/job-done.sh ~/.claude/scripts/notify-waiting.sh

  cp -r "$SCRIPT_DIR/claude/skills" ~/.claude/

  # Symlink settings.json so changes can be committed back to this repo
  ln -sf "$SCRIPT_DIR/claude/settings.json" ~/.claude/settings.json

  echo "✓ Hooks and scripts installed"
}

# === MARKETPLACE REGISTRATION ===
register_marketplaces() {
  echo "→ Registering marketplaces..."
  for url in "${MARKETPLACES[@]}"; do
    echo "  → $url"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin marketplace add "$url" 2>/dev/null || \
      echo "  ⚠ Could not register marketplace $url (may already exist)"
  done
}

# === PLUGINS INSTALLATION ===
install_plugins() {
  local -n plugins=$1
  local label=$2
  echo "→ Installing $label plugins..."
  for plugin in "${plugins[@]}"; do
    echo "  → $plugin"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin install "$plugin" --scope user 2>/dev/null || \
      echo "  ⚠ Could not install $plugin"
  done
}

# === INITIAL AUTH SESSION ===
initial_auth_session() {
  echo ""
  echo "→ Starting Claude for initial authentication..."
  echo "  Once Claude loads and you see you are logged in, type /quit to continue setup."
  echo ""
  CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude
  echo ""
  echo "→ Resuming setup..."
}

# === CLEANUP ===
cleanup() {
  if [[ -d ~/.claude ]]; then
    echo "→ Removing existing ~/.claude..."
    rm -rf ~/.claude
    echo "✓ Removed ~/.claude"
  fi
}

# === MAIN ===
main() {
  echo "=== Claude Code Setup ==="
  echo ""

  cleanup
  install_git
  install_nodejs
  install_claude_code
  setup_auth
  setup_hooks
  register_marketplaces
  install_plugins PLUGINS_MARKETPLACE "marketplace"
  initial_auth_session
  install_plugins PLUGINS_OFFICIAL "official"

  echo ""
  echo "=== Setup complete! ==="
}

main "$@"