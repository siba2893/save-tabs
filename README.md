# save-tabs

Save your Claude Code tabs in iTerm2 before a restart, and get them back after.

A reboot closes every terminal. Claude Code keeps each conversation on disk, so
`claude --resume <id>` can bring it back. These scripts save that command for every tab,
and run it again after the restart.

## Credits

Original idea and code by **Asif Ahmed** ([@sifxtreme](https://github.com/sifxtreme)):
[save-tabs gist](https://gist.github.com/sifxtreme/fe334f486a2e9aea6f84232c0e1e5120).
This repository adapts that work.

## Original version (the gist)

- Saves every iTerm2 tab, in order, with its `claude --resume` command.
- Shows the last message of each tab, so you can tell them apart.
- Works with tmux and with `claude --remote-control` sessions.
- Recovers the real session when a remote-control session restarts empty.
- Restores the tabs in order, and skips sessions that are already open.
- Checks that Claude started in each tab, and retries once if not.
- After a reboot, uses the save from before the reboot.
- Reminds you to restore in the first terminal after a reboot.
- Saves automatically every 15 minutes.

## This version

New:

- Restores each tab in its original **window**.
- Restores **tab groups** (name and color). Needs iTerm2 3.7+.
- Restores **split panes** (layout and sizes).
- Keeps your Claude flags, for example `--dangerously-skip-permissions`.
- One-command install: `./install.sh`.

Changed:

- Includes `claude-sessions`, which the gist needed but did not include.
- Uses a small history file instead of a separate snapshot database.
- tmux is optional.

Fixed:

- After a reboot, restore now really uses the save from before the reboot.
- The cleanup of old saves no longer deletes the pre-reboot save.
- Restore works when iTerm has no window open, and reports tabs it could not open.

## Requirements

- macOS and iTerm2.
- [Claude Code](https://claude.com/claude-code).
- Python 3.
- For tab groups and split panes: iTerm2 3.7+, the iTerm2 Python API turned on
  (Settings > General > Magic > Enable Python API), and [uv](https://docs.astral.sh/uv/).

## Use

```bash
./install.sh        # install (once)
save-tabs           # save now (optional: it also saves every 15 minutes)
restore-tabs        # after a restart: reopen everything
restore-tabs --dry-run   # show what would open, open nothing
```

Remove: `./install.sh --uninstall`.

## Good to know

- Saves go to `~/.claude/session-backups/`. Open `RESTORE.md` there to see them.
- Only tabs with a Claude session come back. Other panes in a split tab come back empty,
  to keep the layout.
- If tab groups or split panes cannot be saved, the tabs still save and restore.
  `RESTORE.md` says why.
- After you change a script, run `./install.sh` again.

## Files

| File | What it does |
|---|---|
| `save-tabs` | Saves the tabs. |
| `restore-tabs` | Reopens the tabs. |
| `claude-sessions` | Lists the open Claude sessions. |
| `iterm-groups` | Reads and sets tab groups and pane sizes. |
| `reboot-nudge` | Prints the reminder after a reboot. |
| `com.siba.save-tabs.plist` | Runs the save every 15 minutes. |
| `install.sh` | Installs or removes everything. |
