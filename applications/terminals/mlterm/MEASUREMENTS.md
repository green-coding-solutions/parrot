# mlterm — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `mlterm 3.9.3-1build2` |
| architecture | own renderer over Xft |
| launcher | `/usr/local/bin/parrot-mlterm` → `exec mlterm` |
| `WM_CLASS` | `"xterm", "mlterm"` |
| pin string (fluxbox, res_name) | `xterm` |
| natural window size | 1435 x 888 |
| grid | **159 columns x 52 rows** |
| `TERM` | `xterm-256color` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

****`fontsize` is in pixels, not points**** — the one setting in this group whose number means something different from everywhere else. At 11 — what every other entrant is configured with — mlterm came up with a **205 x 68** grid against xterm's 159 x 47, rendering a completely different amount of text per screen. At 15 it lands on 159 columns, matching xterm exactly.

****the pin string is `xterm`, not `mlterm`**** — its `WM_CLASS` res_name really is `xterm` — mlterm still identifies itself that way for the benefit of old resource files. fluxbox matches res_name, so pinning `mlterm` matches nothing and leaves the window at its own size. This is the widest split between the two `WM_CLASS` fields of any entrant.

