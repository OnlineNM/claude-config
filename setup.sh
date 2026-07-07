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
  "https://github.com/adrianR84/browserless-claude-plugin"
  "https://github.com/adrianR84/claude-code-protective-hooks"
  "https://github.com/zilliztech/memsearch"
  "https://github.com/stevesolun/micro-skills"
  "https://github.com/AgriciDaniel/banana-claude"
  "https://github.com/mvanhorn/last30days-skill"
  "https://github.com/StarTrail-org/PixelRAG"
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
  "browserless@browserless-claude-plugin"
  "protective-hooks@claude-code-protective-hooks"
  "memsearch"
  "micro-skill-pipeline"
  "banana-claude@banana-claude-marketplace"
  "last30days"
  "pixelbrowse@pixelrag-plugins"
)

prerequisites() {
  echo "Installing prerequisites..."
  if [[ "$(uname)" == "Darwin" ]]; then
    macos
  else
    linux
  fi

  configure_npm_prefix

  # Install bun
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"

  echo
}

linux() {
  run_as_root apt-get update
  run_as_root apt-get install -y curl git jq ca-certificates gnupg expect

  if [[ "$(id -u)" -eq 0 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  else
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
  fi
  run_as_root apt-get update
  run_as_root apt-get install -y nodejs
}

macos() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  # Ensure Homebrew is in PATH for future shells
  SHELL_RC=~/.zshrc
  if ! grep -q "homebrew/bin/brew shellenv" "$SHELL_RC" 2>/dev/null; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
  fi
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

  brew install curl git jq node npm expect
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Root privileges are required and sudo is not available. Please run the script as root." >&2
    exit 1
  fi
}

configure_npm_prefix() {
  echo "Configuring npm global prefix..."
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
  echo "npm prefix configured"
}

cleanup() {
  echo "Cleaning up existing installations..."

  local npm_prefix="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
  local claude_bin="$npm_prefix/bin/claude"
  local claudish_bin="$npm_prefix/bin/claudish"
  local local_claude_bin="$HOME/.local/bin/claude"
  local local_claudish_bin="$HOME/.local/bin/claudish"
  local bun_claude_bin="$HOME/.bun/bin/claude"
  local bun_claudish_bin="$HOME/.bun/bin/claudish"

  echo "Removing existing Claude and claudish installation..."
  rm -f "$local_claude_bin" "$local_claudish_bin" "$claude_bin" "$claudish_bin" "$bun_claude_bin" "$bun_claudish_bin" 2>/dev/null || true

  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  if [[ -d ~/.claude ]]; then
    echo "Removing existing ~/.claude..."
    rm -rf ~/.claude
    echo "Removed ~/.claude"
  fi

  if [[ -f ~/.claude.json ]]; then
    rm -f ~/.claude.json
    echo "Removed ~/.claude.json"
  fi

  npm uninstall -g claudish 2>/dev/null || true
  if [[ -d ~/.claudish ]]; then
    echo "Removing existing ~/.claudish..."
    rm -rf ~/.claudish
    echo "Removed ~/.claudish"
  fi

  echo
}

install_claude_code() {
  echo "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
  echo
}

claude_code_auth() {
  if [[ -z "$CLAUDE_OAUTH_TOKEN" ]]; then
    echo "CLAUDE_OAUTH_TOKEN is not set. Manual authentication will be required."
    return
  fi

  echo "Setting up authentication..."

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
    "organizationUuid": "$ORG_UUID",
    "displayName": "$DISPLAY_NAME"
  }
}
EOF
  chmod 600 ~/.claude.json
  echo "Authentication configured"
  echo
}

setup_hooks() {
  echo "Installing hooks and scripts..."
  mkdir -p ~/.claude/hooks ~/.claude/scripts

  cp "$SCRIPT_DIR/claude/hooks/context-mode-cache-heal.mjs" ~/.claude/hooks/
  chmod +x ~/.claude/hooks/context-mode-cache-heal.mjs

  cp "$SCRIPT_DIR/claude/ccstatusline-settings.json" ~/.claude/ccstatusline-settings.json
  cp -r "$SCRIPT_DIR/claude/skills" ~/.claude/
  
  # # Symlink settings.json so changes can be committed back to this repo
  # ln -sf "$SCRIPT_DIR/claude/settings.json" ~/.claude/settings.json
  cp "$SCRIPT_DIR/claude/settings.json" ~/.claude/settings.json

  echo "Hooks and scripts installed"
  echo
}

register_marketplaces() {
  echo "Registering marketplaces..."
  for url in "${MARKETPLACES[@]}"; do
    echo "$url"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin marketplace add "$url" 2>/dev/null || \
      echo "Could not register marketplace $url (may already exist)"
  done
  echo "Marketplaces registered"
  echo
}

install_marketplace_plugins() {
  echo "Installing marketplace plugins..."
  for plugin in "${PLUGINS_MARKETPLACE[@]}"; do
    echo "$plugin"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin install "$plugin" --scope user 2>/dev/null || \
      echo "Could not install $plugin"
  done
  echo "Marketplace plugins installed"
  echo
}

initial_auth_session() {
  echo "Starting Claude for initial authentication..."

  if ! command -v expect >/dev/null 2>&1; then
    echo "expect is not installed; skipping the initial authentication session."
    echo "Resuming setup..."
    echo
    return 0
  fi

  expect <<EOF
set timeout 45
log_user 0
spawn env CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude
sleep 10
send "\r"
sleep 30
send "/quit\r"
expect eof
EOF

  echo "Resuming setup..."
  echo
}

install_official_plugins() {
  echo "Installing official plugins..."
  for plugin in "${PLUGINS_OFFICIAL[@]}"; do
    echo "$plugin"
    CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_OAUTH_TOKEN" claude plugin install "$plugin" --scope user 2>/dev/null || \
      echo "Could not install $plugin"
  done
  echo "Official plugins installed"
  echo
}

install_claudish() {
  echo "Installing claudish..."
  npm install -g claudish
  echo
}

setup_claudish() {
  echo "Configuring claudish files..."
  mkdir -p ~/.claudish
  cp "$SCRIPT_DIR/claudish/patch.js" ~/.claudish/patch.js
  cp "$SCRIPT_DIR/claudish/config.json" ~/.claudish/config.json
  cp "$SCRIPT_DIR/claudish/cloudflare-env.sh" ~/.claudish/cloudflare-env.sh
  cp "$SCRIPT_DIR/claudish/test_openrouter.sh" ~/.claudish/test_openrouter.sh
  chmod +x ~/.claudish/test_openrouter.sh

  node "$SCRIPT_DIR/claudish/patch.js"
  echo
}

main() {
  echo "=== Claude Code /Claudish Setup ==="
  echo ""

  prerequisites
  cleanup
  install_claude_code
  claude_code_auth
  setup_hooks
  register_marketplaces
  install_marketplace_plugins
  initial_auth_session
  install_official_plugins
  install_claudish
  setup_claudish

  echo ""
  echo "=== Setup complete! ==="
}

main "$@"