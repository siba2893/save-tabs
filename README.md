# save-tabs — bring your terminal back after a restart

You have 10 terminal tabs open, each a long-running AI coding session (Claude Code),
and your Mac needs to restart. A reboot kills your tmux server and every terminal
process — so how do you get *exactly* those sessions back?

These scripts capture every iTerm2 tab to a restore doc before a reboot, and reopen
them after. Each Claude Code conversation is written to disk as a transcript with a
UUID, so the real restore path is `claude --resume <uuid>` — the one thing that
survives a reboot (`tmux attach` does not: the tmux server is gone).

## Credits

The idea and the original `save-tabs`, `restore-tabs`, `reboot-nudge` and LaunchAgent
come from **Asif Ahmed** ([@sifxtreme](https://github.com/sifxtreme), [sifxtreme.com](https://sifxtreme.com)),
published in the gist
[save-tabs: bring your terminal back after a Mac restart](https://gist.github.com/sifxtreme/fe334f486a2e9aea6f84232c0e1e5120).
This repository adapts that work.

## Original version (the gist)

Features:

- **Save every iTerm2 tab** in tab-bar order, each with a `cd <cwd> && claude --resume <uuid>`
  command, to `~/.claude/session-backups/RESTORE.md` (+ a JSON copy).
- **Tell sessions apart:** per tab, the last-activity time, the last message and your
  last prompt.
- **tmux and remote-control bridges:** resolves Claude running inside tmux, and
  `claude --remote-control` bridge sessions, to the real transcript UUID.
- **Blank-bridge guard:** a bridge can restart on its own onto an empty session; the save
  recovers the last substantial session for that name from a snapshot database (a
  companion `session-snapshot` script, not in the gist).
- **Restore in order** into new iTerm2 tabs, and never resume a session that is already
  running (two Claude processes on one transcript corrupt each other).
- **Verify each restore:** names each tab and checks that `claude` started on its tty;
  re-sends the command once if it did not.
- **Pre-reboot snapshot:** after a reboot, restore picks the last save from before boot.
- **Post-reboot nudge:** the first shell after a reboot prints a one-line reminder.
- **Auto-save every 15 minutes** with a LaunchAgent; an empty run never overwrites a good
  restore doc.
- Depends on a `claude-sessions` script that the gist does not include.

## This version

Features added or changed:

- **Windows:** each tab records its iTerm window. Restore puts the first saved window's
  tabs in the current window and opens a new window for each other saved window.
- **Tab groups (iTerm2 3.7+):** each tab records its native tab group. Restore recreates
  each group with its name, color and collapsed state.
- **Split panes:** each split tab records its pane tree (split direction and pane sizes).
  Restore rebuilds the tab pane by pane and resizes the panes to the saved proportions. A
  pane that held no Claude session comes back as an empty shell, so the layout holds.
- **`claude-sessions` included:** it reads `~/.claude/sessions/<pid>.json`, which Claude
  Code writes for each live session.
- **Launch flags kept:** the restore command copies the original flags (for example
  `--dangerously-skip-permissions --verbose`) and appends `--resume <uuid>`.
- **No snapshot database:** each save records `name -> sessionId` in
  `~/.claude/session-backups/history.json`, and the blank-bridge guard reads that file.
  Sessions without a name get no recovery.
- **tmux optional:** a missing tmux binary no longer crashes the save.
- **`install.sh`:** one command installs the scripts, the LaunchAgent and the nudge
  (`./install.sh --uninstall` removes them).
- **Fixes:**
  - The pre-reboot snapshot is now actually picked after a reboot (its copy kept the old
    file time, so restore never chose it).
  - Archive cleanup no longer deletes `RESTORE-prereboot.md`.
  - Restore works when iTerm has no window open, reports each tab it could not open, and
    exits with code 1.

### How windows, groups and panes work

AppleScript cannot see tab groups or pane layout. The `iterm-groups` helper reads them
and applies groups and pane sizes through the iTerm2 Python API (the `iterm2` package, in
a venv that `install.sh` builds with uv). Windows, tabs and panes are still created with
AppleScript. If the helper is unavailable, every session still saves and restores as its
own tab, in its window, and `RESTORE.md` shows the reason on its
`_Groups and split panes:` line.

## Scripts

| File | Role |
|---|---|
| `save-tabs` | Writes `RESTORE.md` and `RESTORE.json` to `~/.claude/session-backups/`. |
| `restore-tabs` | Reopens the saved sessions, windows, groups and split panes. |
| `claude-sessions` | Lists the live Claude Code sessions (used by both scripts). |
| `iterm-groups` | Reads and applies tab groups and pane sizes through the iTerm2 Python API. |
| `reboot-nudge` | Prints the post-reboot reminder; run from `~/.zshrc`. |
| `com.siba.save-tabs.plist` | LaunchAgent: runs `save-tabs --auto` every 15 minutes. |
| `install.sh` | Installs or uninstalls everything. |

## Requirements

- macOS + iTerm2 (uses AppleScript for tab order; grant Automation permission).
- [Claude Code](https://claude.com/claude-code) (transcripts live in `~/.claude/projects/…`).
- Python 3. tmux is optional (only needed to map tmux-hosted tabs).
- For tab groups and split panes: iTerm2 3.7+, Settings > General > Magic > Enable
  Python API, and `uv` at install time.

## Setup

```bash
./install.sh             # CLIs, 15-min LaunchAgent, nudge line in ~/.zshrc
# before a restart (optional — the LaunchAgent saves every 15 min):
save-tabs
# after:
restore-tabs             # --dry-run to preview, --prereboot / --file PATH to override
```

`install.sh` copies the scripts to `~/.local/share/save-tabs`, because a launchd job
cannot read `~/Documents` (TCC). Re-run it after you edit a script.

Output lives in `~/.claude/session-backups/`. LaunchAgent logs:
`~/.local/share/save-tabs/launchd-save-tabs.{out,err}`.

## Notes

- If the LaunchAgent has no Automation permission for iTerm, `save-tabs --auto` still
  saves every live session, but in last-activity order instead of tab order (the
  `_Order:` line in `RESTORE.md` says which).
- `restore-tabs` reopens Claude sessions only; a tab with no Claude session in any pane is
  listed but not reopened.
- Pane sizes are restored as proportions: a new window of a different size keeps the
  ratios, not the exact column counts.
