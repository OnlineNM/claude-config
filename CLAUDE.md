# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo provisions Claude Code on new Linux/macOS servers. The single entry point is `setup.sh`, which installs dependencies, configures authentication, deploys config files, and installs plugins.

## Running the script

```bash
cp .env.sample .env   # fill in credentials first
bash setup.sh
```

There are no tests, build steps, or linters. Validate changes by running the script on a target machine or by dry-running individual functions.

## Architecture

`setup.sh` executes these steps in order:

1. **Load `.env`** from the script's directory — fails fast if missing
2. **`cleanup()`** — removes `~/.claude/` entirely before install
3. **`install_git()`** — apt-get or brew
4. **`install_nodejs()`** — nodesource (Linux) or brew (macOS); requires ≥ v18
5. **`install_claude_code()`** — `npm install -g`
6. **`setup_auth()`** — copies `.env` to `~/.claude/.env`, adds source line to shell RC, writes `~/.claude.json` to bypass onboarding
7. **`setup_hooks()`** — copies everything from `claude/` to `~/.claude/`
8. **`setup_dotfiles()`** — clones `CLAUDE_DOTFILES_REPO` and symlinks `claude/settings.json`
9. **`register_marketplaces()`** — registers each URL in `MARKETPLACES[]`
10. **`install_plugins()`** — installs each entry in `PLUGINS[]`

## Key files

- **`claude/settings.json`** — portable Claude Code settings: plugins, hooks, status line, marketplaces. This is what gets deployed to `~/.claude/settings.json`.
- **`claude/scripts/`** — hook scripts for Telegram notifications (`job-done.sh`, `notify-waiting.sh`). Both source `load-env.sh` which reads `~/.claude/.env`.
- **`claude/hooks/context-mode-cache-heal.mjs`** — runs at SessionStart to fix the `context-mode` plugin cache after Claude Code auto-updates.
- **`claude/ccstatusline-settings.json`** — layout config for the terminal status bar.
- **`claude/commands/`** — custom slash commands (currently empty).

## Adding plugins or marketplaces

Edit the arrays at the top of `setup.sh`:

```bash
MARKETPLACES=(
  "https://github.com/org/repo"
)

PLUGINS=(
  "plugin-name@marketplace-name"
)
```

Marketplace must be registered before its plugins — order matters.

## Credentials

All secrets live in `.env` (gitignored). The script copies it to `~/.claude/.env` on the target machine, which is sourced by the shell RC file and by hook scripts at runtime.
