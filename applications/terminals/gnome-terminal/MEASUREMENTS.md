# gnome-terminal — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `gnome-terminal 3.52.0-1ubuntu2` |
| architecture | VTE / GTK 3 |
| launcher | `/usr/local/bin/parrot-gnome-terminal` → `exec dbus-run-session -- gnome-terminal --wait` |
| `WM_CLASS` | `"gnome-terminal-server", "Gnome-terminal"` |
| pin string (fluxbox, res_name) | `gnome-terminal` |
| `TERM` | `xterm-256color` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

**refuses to start without a UTF-8 locale** — `Non UTF-8 locale (ANSI_X3.4-1968) is not supported!` and no window ever appears. The container image ships no locales, so `install-common.sh` must `locale-gen` — this entrant is the reason that is not optional.

**the window belongs to the server** — not to the `gnome-terminal` client that launched it, which is why the launcher uses `--wait`: without it the client exits immediately and `replay.py` supervises a dead process.

**scrollback** — one of only two entrants where `shift+Page Up` actually scrolls and returns exactly.

