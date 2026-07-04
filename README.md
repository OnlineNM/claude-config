# claude-config

Provisioning script and configuration files for Claude Code and Claudish on Linux and macOS.

## What this does

Runs a single script on a new server to get Claude Code fully configured:
- Installs prerequisites such as git, curl, jq, and Expect
- Installs Node.js on Linux via NodeSource and on macOS via Homebrew
- Installs Claude Code and configures npm to use a user-scoped global prefix
- Creates the Claude authentication and onboarding files automatically
- Copies hooks, scripts, and configuration files
- Registers plugin marketplaces and installs plugins
- Optionally syncs dotfiles from a git repo

## Repository structure

```
.
├── setup.sh                        # Provisioning script
├── .env.sample                     # Template for credentials
├── claude/
│   ├── settings.json               # Claude Code settings (plugins, hooks, status line)
│   ├── ccstatusline-settings.json  # Status bar layout configuration
│   ├── commands/                   # Custom slash commands (empty — add .md files here)
│   ├── hooks/
│   │   └── context-mode-cache-heal.mjs  # Fixes context-mode after Claude Code auto-updates
│   └── skills/                     # Custom Claude skills
├── claudish/
│   ├── config.json                 # Claudish configuration
│   └── test_openrouter.sh          # OpenRouter test helper
```

## Setup

### 1. Clone this repo

```bash
git clone <repo-url> ~/claude-config
cd ~/claude-config
```

### 2. Create your `.env`

```bash
cp .env.sample .env
```

Edit `.env` with your credentials. To find the Claude values, authenticate manually once with `claude` and inspect `~/.claude.json`.

```env
CLAUDE_CODE_OAUTH_TOKEN=    # from ~/.claude.json after first login
CLAUDE_ACCOUNT_UUID=        # oauthAccount.accountUuid
CLAUDE_EMAIL=               # oauthAccount.emailAddress
CLAUDE_ORG_UUID=            # oauthAccount.organizationUuid
CLAUDE_DOTFILES_REPO=       # optional: https://github.com/user/dotfiles.git

FIRECRAWL_API_KEY=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
OPENROUTER_API_KEY=
```

### 3. Run

```bash
bash setup.sh
source ~/.bashrc && claude   # Linux
source ~/.zshrc && claude    # macOS
```

On Linux, the script installs Node.js using NodeSource, configures npm for a user-scoped prefix under ~/.npm-global, and runs a short automated Claude session to establish authentication before continuing.

## Claudish

The setup script also installs and configures Claudish:
- installs the `claudish` npm package globally
- copies the local configuration from [claudish/config.json](claudish/config.json)
- installs the helper script [claudish/test_openrouter.sh](claudish/test_openrouter.sh) and makes it executable

You can use it alongside Claude Code for the OpenRouter-based workflow defined in the repository.

## Upgrade Claude Code

```bash
npm install -g @anthropic-ai/claude-code@latest
```

## Notes

- `setup.sh` deletes `~/.claude/` and `~/.claudish/` before installing — existing sessions, plugin cache, and claudish files will be lost
- Credentials are copied to `~/.claude/.env` and sourced from the shell config
- Hook scripts send Telegram notifications — requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env`
- Dotfiles repo is optional; if set, `setup.sh` clones it and symlinks `claude/settings.json` from it
