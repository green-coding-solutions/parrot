# konsole — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `konsole 4:23.08.5-0ubuntu4` |
| architecture | Qt 5 / KDE |
| launcher | `/usr/local/bin/parrot-konsole` → `exec konsole --separate --hide-menubar --hide-tabbar` |
| `WM_CLASS` | `"konsole", "konsole"` |
| pin string (fluxbox, res_name) | `konsole` |
| `TERM` | `xterm-256color` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

****three to six times slower than the Xlib entrants**** — measured per block: `plain` 5,087 ms against xterm's 1,501 ms, `longlines` 3,750 ms against 1,471 ms, and `seq` **9,588 ms** against 1,487 ms. This is the headline result for this entrant, not a problem with the harness.

**needs `BLOCK_WAIT=25`** — its first recording warned that `seq` had not logged after the 8 s default, so that checkpoint was photographed mid-scroll. 25 s is 2.6x the worst measured block.

**`--separate`** — without it a relaunch attaches to the running instance and the new window is a tab of the old one — not the process `replay.py` supervises.

**scrollback** — `shift+Page Up` scrolls, but the down key does not return to the same screen, so a scroll-back/scroll-forward pair could not have been replay-verified.

