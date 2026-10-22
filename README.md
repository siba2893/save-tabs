# save-tabs — bring your terminal back after a restart

Adapted from https://gist.github.com/sifxtreme/fe334f486a2e9aea6f84232c0e1e5120.

## Local changes vs. the gist

- **`claude-sessions` is included.** The gist depends on it but does not ship it. This
  version reads `~/.claude/sessions/<pid>.json`, which Claude Code writes per live session.
- **The restore command keeps your launch flags.** It copies the original process argv
  (for example the `clauded` alias: `--dangerously-skip-permissions --verbose`) and appends
  `--resume <uuid>`.
- **No snapshot DB.** Each save records `name -> sessionId` in
  `~/.claude/session-backups/history.json`; the blank-bridge fallback reads that file.
- **tmux is optional.** A missing binary returns empty output instead of a crash.
- **Windows and tab groups.** Each row records its iTerm window and its native tab group
  (iTerm2 3.7+). `restore-tabs` puts the first saved window's tabs in the current window,
  opens a new window for each other saved window, and recreates each group (name, color,
  collapsed). AppleScript has no group API, so the `iterm-groups` helper reads and
  creates groups through the iTerm2 Python API (`iterm2` package, in a venv that
  `install.sh` builds with uv). If the helper is unavailable, tabs and windows still save
  and restore, and RESTORE.md shows the reason on its `_Groups:` line.
- **Install:** run `./install.sh` (undo: `./install.sh --uninstall`). It copies the scripts to
  `~/.local/share/save-tabs`, because a launchd job cannot read `~/Documents` (TCC). Re-run it
  after you edit a script here.

You have 10 terminal tabs open, each a long-running AI coding session (Claude Code),
and your Mac needs to restart. A reboot kills your tmux server and every terminal
process — so how do you get *exactly* those sessions back?

These three small scripts capture every iTerm2 tab to a restore doc before a reboot,
and reopen them after. Each Claude Code conversation is written to disk as a transcript
with a UUID, so the real restore path is `claude --resume <uuid>` — the one thing that
survives a reboot (`tmux attach` does not: the tmux server is gone).

## What it does (factually)

**`save-tabs`** — writes `~/.claude/session-backups/RESTORE.md` (+ a JSON copy):
- Every iTerm2 tab, in tab-bar order, with a `cd <cwd> && claude --resume <uuid>` command.
- Per tab: last-activity timestamp, and the last message (both the assistant's and your
  last prompt), so you can tell sessions apart.
- Handles tabs where Claude runs *inside* tmux, and `claude --remote-control` bridge
  sessions — resolving each to its real transcript UUID, not the tmux name.
- Guard against a known failure mode: a remote-control bridge can restart on its own
  and momentarily sit on a fresh empty session. If the live session looks blank, it
  recovers the last substantial session (≥ 1 MB transcript) recorded under that same
  stable name in `history.json`. Sessions without a name get no recovery.

**`restore-tabs`** — reads the JSON and reopens each session in a new iTerm2 tab, in order:
- Never double-resumes: a session already running is skipped (two Claude processes on
  one transcript corrupt each other).
- Opens a new window if iTerm has none, and reports any tab it could not open
  (non-zero exit).
- Names each reopened tab and verifies `claude` actually launched on its tty, re-issuing
  the command once if the AppleScript `write` fired before the shell prompt was ready.
- After a reboot it automatically picks the *pre-reboot* snapshot.

**`reboot-nudge`** — sourced from `~/.zshrc`; on the first interactive shell after a
reboot, prints a one-line reminder if tabs were open before it. Silent otherwise.

**`com.siba.save-tabs.plist`** — a user LaunchAgent that runs `save-tabs --auto` every
15 minutes, so even an *unplanned* reboot has a recent restore doc. It never overwrites
a good doc with an empty run, and preserves the pre-reboot list before any post-reboot
write can clobber it.

## Requirements

- macOS + iTerm2 (uses AppleScript for tab order; grant Automation permission).
- [Claude Code](https://claude.com/claude-code) (transcripts live in `~/.claude/projects/…`).
- Python 3. tmux is optional (only needed to map tmux-hosted tabs).
- For tab groups: iTerm2 3.7+, Settings > General > Magic > Enable Python API, and `uv`
  at install time.

## Setup

```bash
./install.sh             # CLIs, 15-min LaunchAgent, nudge line in ~/.zshrc
# before a restart (optional — the LaunchAgent saves every 15 min):
save-tabs
# after:
restore-tabs             # --dry-run to preview, --prereboot / --file PATH to override
```

Output lives in `~/.claude/session-backups/`. LaunchAgent logs:
`~/.local/share/save-tabs/launchd-save-tabs.{out,err}`.

If the LaunchAgent has no Automation permission for iTerm, `save-tabs --auto` still
saves every live session, but in last-activity order instead of tab order (the
`_Order:` line in `RESTORE.md` says which).

`restore-tabs` reopens Claude tabs only; plain shell tabs are listed but not reopened.
Split panes come back as separate tabs (in the same window and group).
