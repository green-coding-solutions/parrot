# alacritty — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `alacritty 0.13.2-1ubuntu1` |
| architecture | OpenGL, Rust |
| launcher | `/usr/local/bin/parrot-alacritty` → `exec alacritty` |
| `WM_CLASS` | `"Alacritty", "Alacritty"` |
| pin string (fluxbox, res_name) | `Alacritty` |
| `TERM` | `alacritty` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

****needs `libxkbcommon-x11-0`**, which `--no-install-recommends` drops** — without it the process panics with `Library libxkbcommon-x11.so could not be loaded` and exits before mapping a window. The symptom is simply that no window appears, which is indistinguishable from a slow start — and my first capability probe recorded it as starting fine.

**capital A in **both** `WM_CLASS` fields** — unlike every other entrant. fluxbox's match is case-sensitive, so the pin string must keep the capital; xdotool's is not.

**scrollback** — does not scroll on `shift+Page Up`; does scroll on the wheel.

