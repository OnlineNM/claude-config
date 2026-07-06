---
name: terminal
description: Sets a per-project VS Code integrated terminal color theme (dark or light) by writing .vscode/settings.json in the current working directory, and makes sure that folder stays out of git via .vscode/.gitignore. Use this whenever the user asks to change/set the terminal color, terminal theme, terminal background, or says something like "make the terminal dark/light for this project", "set terminal colors", or "/terminal dark" / "/terminal light".
---

# Terminal Theme

Applies a VS Code terminal color scheme (`dark` or `light`) scoped to the current project, by writing local editor settings that are never committed to git.

## Why this exists

VS Code terminal colors are normally a global user preference, but sometimes a project needs its own look (e.g., to visually distinguish a specific repo or environment at a glance). The cleanest way to do that is a workspace-level `.vscode/settings.json` — but that file shouldn't leak into version control, since it's a personal/local preference, not project config. This skill keeps both concerns handled together: the theme gets applied, and `.vscode/` is guaranteed to be gitignored.

## When invoked

The skill takes exactly one argument: `dark` or `light`. If the user didn't specify which one, ask before proceeding — don't guess.

## Steps

1. Determine the current working directory — this is the project root the theme applies to.
2. Run the bundled script, passing the theme and the target directory:

   ```bash
   bash <skill-dir>/scripts/apply_theme.sh <dark|light> "$(pwd)"
   ```

   The script is idempotent and handles everything in one pass:
   - Creates `.vscode/` in the target directory if it doesn't exist.
   - Ensures `.vscode/.gitignore` contains a line that is exactly `*`:
     - Missing file → creates it with that line.
     - Existing file without the line → appends it.
     - Existing file that already has it → leaves the file untouched.
   - Writes `.vscode/settings.json` with the full color set for the requested theme, always overwriting any prior content (this file is meant to fully reflect the current theme choice, not merge with whatever was there before).

3. Report back which files were created, appended to, or left untouched, and confirm the theme that's now active (the script's own output already says this — just relay it).

## Notes

- The two themes' exact color values live only in `scripts/apply_theme.sh` — don't hand-transcribe them elsewhere; always invoke the script so the source of truth stays single.
- If `.vscode/settings.json` already exists with unrelated custom settings, applying a theme replaces the whole file per the spec above — mention this to the user if you notice pre-existing content being discarded.
