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
DISPLAY_NAME="${CLAUDE_DISPLAY_NAME:-}"

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
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
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
        echo "→ Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
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

# === CLAUDISH INSTALLATION ===
install_claudish() {
  if ! command -v claudish &>/dev/null; then
    echo "→ Installing claudish..."
    if [[ "$(uname)" == "Darwin" ]]; then
      npm install -g claudish
    else
      sudo npm install -g claudish
    fi
  else
    echo "✓ claudish already installed"
  fi
}

setup_claudish_files() {
  echo "→ Configuring claudish files..."
  mkdir -p ~/.claudish
  cp "$SCRIPT_DIR/claudish/config.json" ~/.claudish/config.json
  cp "$SCRIPT_DIR/claudish/test_openrouter.sh" ~/.claudish/test_openrouter.sh
  chmod +x ~/.claudish/test_openrouter.sh
  echo "✓ claudish files installed"
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
    # Ensure Homebrew is in PATH for future shells
    if ! grep -q "homebrew/bin/brew shellenv" "$SHELL_RC" 2>/dev/null; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
    fi
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
    "organizationUuid": "$ORG_UUID",
    "displayName": "$DISPLAY_NAME"
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
install_marketplace_plugins() {
  echo "→ Installing marketplace plugins..."
  for plugin in "${PLUGINS_MARKETPLACE[@]}"; do
    echo "  → $plugin"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin install "$plugin" --scope user 2>/dev/null || \
      echo "  ⚠ Could not install $plugin"
  done
}

install_official_plugins() {
  echo "→ Installing official plugins..."
  for plugin in "${PLUGINS_OFFICIAL[@]}"; do
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
  if command -v claude &>/dev/null; then
    echo "→ Uninstalling Claude Code..."
    # Installed via claude.ai/install.sh (standalone binary)
    rm -f ~/.local/bin/claude
    # Installed via npm (user-level or system-level)
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    if [[ "$(uname)" != "Darwin" ]]; then
      sudo npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    fi
    echo "✓ Uninstalled Claude Code"
  fi
  if [[ -d ~/.claude ]]; then
    echo "→ Removing existing ~/.claude..."
    rm -rf ~/.claude
    echo "✓ Removed ~/.claude"
  fi
  if [[ -f ~/.claude.json ]]; then
    rm -f ~/.claude.json
    echo "✓ Removed ~/.claude.json"
  fi
}

# === MAIN ===
main() {
  echo "=== Claude Code Setup ==="
  echo ""

  # Ensure Homebrew is in PATH on macOS
  if [[ "$(uname)" == "Darwin" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  cleanup
  install_git
  install_nodejs
  install_claude_code
  install_claudish
  setup_claudish_files
  setup_auth
  setup_hooks
  register_marketplaces
  install_marketplace_plugins
  initial_auth_session
  install_official_plugins

  echo ""
  echo "=== Setup complete! ==="
}

main "$@"