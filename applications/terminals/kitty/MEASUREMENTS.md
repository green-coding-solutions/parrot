# kitty — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `kitty 0.32.2-1ubuntu0.4` |
| architecture | OpenGL, C/Python |
| launcher | `/usr/local/bin/parrot-kitty` → `exec kitty` |
| `WM_CLASS` | `"kitty", "kitty"` |
| pin string (fluxbox, res_name) | `kitty` |
| `TERM` | `xterm-kitty` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

****its cursor blinks by default, and that alone would have made it unrecordable**** — two screenshots of an idle window 1.5 s apart are not identical, so every checkpoint after the first fails on replay. `cursor_blink_interval 0` fixes it. This is the single cheapest test to run on any new entrant and it is what ruled out cool-retro-term entirely.

**takes the command directly** — not behind `-e`. Assuming `-e` is what made an early truecolour probe report nonsense for this entrant.

**no `--single-instance`** — deliberately — it would make a relaunch attach to the running process as a new OS window owned by the first.

**scrollback** — does not scroll on `shift+Page Up` — its own binding is `ctrl+shift+page_up` — but does scroll on the wheel.

