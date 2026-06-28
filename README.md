# claude-config

Provisioning script and configuration files for Claude Code on Linux and macOS.

## What this does

Runs a single script on a new server to get Claude Code fully configured:
- Installs git, Node.js, and Claude Code
- Authenticates without manual onboarding
- Copies hooks, scripts, and configuration files
- Registers plugin marketplaces and installs plugins
- Optionally syncs dotfiles from a git repo

## Repository structure

```
.
├── setup.sh                        # Provisioning script
├── .env.sample                     # Template for credentials
└── claude/
    ├── settings.json               # Claude Code settings (plugins, hooks, status line)
    ├── ccstatusline-settings.json  # Status bar layout configuration
    ├── commands/                   # Custom slash commands (empty — add .md files here)
    ├── hooks/
    │   └── context-mode-cache-heal.mjs  # Fixes context-mode after Claude Code auto-updates
    └── scripts/
        ├── load-env.sh             # Shared env loader for hook scripts
        ├── job-done.sh             # Sends Telegram notification when task completes
        └── notify-waiting.sh       # Sends Telegram notification when Claude needs input
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

## Upgrade Claude Code

```bash
npm install -g @anthropic-ai/claude-code@latest
```

## Notes

- `setup.sh` deletes `~/.claude/` before installing — existing sessions and plugin cache will be lost
- Credentials are copied to `~/.claude/.env` and sourced from the shell config
- Hook scripts send Telegram notifications — requires `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env`
- Dotfiles repo is optional; if set, `setup.sh` clones it and symlinks `claude/settings.json` from it
