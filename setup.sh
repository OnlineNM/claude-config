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

# === PREREQUISITES ===
configure_npm_prefix() {
  echo "→ Configuring npm global prefix..."
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global"

  if [[ "$(uname)" == "Darwin" ]]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi

  if ! grep -q "$HOME/.npm-global/bin" "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$SHELL_RC"
  fi

  export PATH="$HOME/.npm-global/bin:$PATH"
  echo "✓ npm prefix configured"
}

install_curl() {
  if ! command -v curl &>/dev/null; then
    echo "→ Installing curl..."
    if [[ "$(uname)" == "Darwin" ]]; then
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      brew install curl
    else
      apt-get install -y curl
    fi
  else
    echo "✓ curl $(curl --version | head -1 | cut -d' ' -f2) already installed"
  fi
}

# === GIT INSTALLATION ===
install_git() {
  if ! command -v git &>/dev/null; then
    echo "→ Installing git..."
    if [[ "$(uname)" == "Darwin" ]]; then
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      brew install git
    else
      apt-get install -y git
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
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs
    fi
  else
    echo "✓ Node.js $(node --version) already installed"
  fi
}

# === CLAUDE CODE INSTALLATION ===
install_claude_code() {
  echo "→ Reinstalling Claude Code..."
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  npm install -g @anthropic-ai/claude-code
}

# === BUN INSTALLATION ===
install_bun() {
  if ! command -v bun &>/dev/null; then
    echo "→ Installing Bun..."
    if [[ "$(uname)" == "Darwin" ]]; then
      curl -fsSL https://bun.sh/install | bash
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
    else
      curl -fsSL https://bun.sh/install | bash
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
    fi
  else
    echo "✓ Bun already installed"
  fi
}

# === CLAUDISH INSTALLATION ===
install_claudish() {
  echo "→ Reinstalling claudish..."
  npm uninstall -g claudish 2>/dev/null || true
  npm install -g claudish
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
  local npm_prefix="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
  local claude_bin="$npm_prefix/bin/claude"
  local claudish_bin="$npm_prefix/bin/claudish"
  local local_claude_bin="$HOME/.local/bin/claude"
  local local_claudish_bin="$HOME/.local/bin/claudish"
  local bun_claude_bin="$HOME/.bun/bin/claude"
  local bun_claudish_bin="$HOME/.bun/bin/claudish"

  echo "→ Removing existing Claude and claudish installation..."
  rm -f "$local_claude_bin" "$local_claudish_bin" "$claude_bin" "$claudish_bin" "$bun_claude_bin" "$bun_claudish_bin" 2>/dev/null || true
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  npm uninstall -g claudish 2>/dev/null || true

  if [[ -d ~/.claude ]]; then
    echo "→ Removing existing ~/.claude..."
    rm -rf ~/.claude
    echo "✓ Removed ~/.claude"
  fi

  if [[ -d ~/.claudish ]]; then
    echo "→ Removing existing ~/.claudish..."
    rm -rf ~/.claudish
    echo "✓ Removed ~/.claudish"
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
  configure_npm_prefix
  install_curl
  install_git
  install_nodejs
  install_claude_code
  install_bun
  setup_auth
  setup_hooks
  register_marketplaces
  install_marketplace_plugins
  initial_auth_session
  install_official_plugins
  install_claudish
  setup_claudish_files

  echo ""
  echo "=== Setup complete! ==="
}

main "$@"