#!/usr/bin/env bash
# Install save-tabs: copy scripts to ~/.local/share/save-tabs, CLI symlinks, 15-min
# LaunchAgent, post-reboot nudge in ~/.zshrc. Idempotent; re-run after editing a script.
# Undo with ./install.sh --uninstall.
# Scripts are copied (not run from this repo) because launchd jobs cannot read
# ~/Documents without Full Disk Access (TCC: "Operation not permitted").
# Tab groups need the `iterm2` Python package: it goes in a venv under the install dir,
# built here with uv on /usr/bin/python3 (the interpreter launchd already runs), so
# nothing resolves packages or the network at save/restore time.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
DEST="$HOME/.local/share/save-tabs"
LABEL="com.siba.save-tabs"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
NUDGE='[[ -o interactive ]] && [ -x ~/.local/bin/reboot-nudge ] && ~/.local/bin/reboot-nudge 2>/dev/null  # save-tabs'

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  for f in save-tabs restore-tabs reboot-nudge claude-sessions; do rm -f "$BIN/$f"; done
  rm -rf "$DEST"
  sed -i '' '/# save-tabs$/d' "$HOME/.zshrc"
  echo "save-tabs uninstalled (RESTORE files in ~/.claude/session-backups kept)."
  exit 0
fi

mkdir -p "$BIN" "$DEST"
for f in save-tabs restore-tabs reboot-nudge claude-sessions; do
  install -m 755 "$HERE/$f" "$DEST/$f"
  ln -sf "$DEST/$f" "$BIN/$f"
done
install -m 755 "$HERE/iterm-groups" "$DEST/iterm-groups"

if command -v uv >/dev/null; then
  [ -x "$DEST/.venv/bin/python" ] || uv venv -q --python /usr/bin/python3 "$DEST/.venv"
  uv pip install -q --python "$DEST/.venv/bin/python" iterm2==2.30
else
  echo "warning: uv not found — tab groups will not be saved or restored." >&2
fi

sed -e "s#__INSTALL_DIR__#$DEST#g" -e "s#__HOME__#$HOME#g" "$HERE/$LABEL.plist" > "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

grep -qF '# save-tabs' "$HOME/.zshrc" || printf '\n%s\n' "$NUDGE" >> "$HOME/.zshrc"
echo "save-tabs installed: CLIs in $BIN, LaunchAgent $LABEL (every 15 min), nudge in ~/.zshrc."
