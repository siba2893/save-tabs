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
  recovers the last substantial session for that same stable name from a 15-minute
  snapshot database (see the companion `session-snapshot`, not included here).

**`restore-tabs`** — reads the JSON and reopens each session in a new iTerm2 tab, in order:
- Never double-resumes: a session already running is skipped (two Claude processes on
  one transcript corrupt each other).
- Names each reopened tab and verifies `claude` actually launched on its tty, re-issuing
  the command once if the AppleScript `write` fired before the shell prompt was ready.
- After a reboot it automatically picks the *pre-reboot* snapshot.

**`reboot-nudge`** — sourced from `~/.zshrc`; on the first interactive shell after a
reboot, prints a one-line reminder if tabs were open before it. Silent otherwise.

**`com.asif.save-tabs.plist`** — a user LaunchAgent that runs `save-tabs --auto` every
15 minutes, so even an *unplanned* reboot has a recent restore doc. It never overwrites
a good doc with an empty run, and preserves the pre-reboot list before any post-reboot
write can clobber it.

## Requirements

- macOS + iTerm2 (uses AppleScript for tab order; grant Automation permission).
- [Claude Code](https://claude.com/claude-code) (transcripts live in `~/.claude/projects/…`).
- Python 3. tmux is optional (only needed to map tmux-hosted tabs).

## Setup

```bash
chmod +x save-tabs restore-tabs reboot-nudge
# before a restart:
./save-tabs
# after:
./restore-tabs           # --dry-run to preview
```

Auto-save every 15 min (optional): edit the paths in `com.asif.save-tabs.plist`, then
`cp` it to `~/Library/LaunchAgents/` and `launchctl bootstrap gui/$(id -u) …`.

Post-reboot nudge (optional): add to `~/.zshrc`:
```sh
[[ -o interactive ]] && [ -x ~/path/to/reboot-nudge ] && ~/path/to/reboot-nudge 2>/dev/null
```

Paths assume `~/.claude/session-backups/`; adjust for your setup.
