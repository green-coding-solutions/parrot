# urxvt — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `rxvt-unicode 9.31-3build2` |
| architecture | raw Xlib |
| launcher | `/usr/local/bin/parrot-urxvt` → `xrdb -load /root/.Xresources; exec urxvt` |
| `WM_CLASS` | `"urxvt", "URxvt"` |
| pin string (fluxbox, res_name) | `urxvt` |
| `TERM` | `rxvt-unicode-256color` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

**24-bit colour** — **present**, against my expectation that Ubuntu's 9.31 lacked it — it renders `#119955` exactly. Had that been taken on trust the true-colour block would have been dropped from the whole group for no reason.

**scrollback gesture** — does **not** scroll on `shift+Page Up`, and does **not** scroll on the mouse wheel either. It was one of the two entrants that made the scrollback blocks impossible to share.

