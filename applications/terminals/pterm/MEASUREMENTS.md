# pterm — measured values

Read off a running window in `window-container`, not taken from documentation.

| | |
| --- | --- |
| package | `pterm 0.81-1 (PuTTY)` |
| architecture | GTK 3, PuTTY's own terminal core |
| launcher | `/usr/local/bin/parrot-pterm` → `exec pterm -fn "DejaVu Sans Mono 11" -sl 20000 -e /bin/bash -l` |
| `WM_CLASS` | `"pterm", "Pterm"` |
| pin string (fluxbox, res_name) | `pterm` |
| natural window size | 1438 x 884 |
| grid | **158 columns x 49 rows** |
| `TERM` | `xterm` |
| steady idle screen | yes |
| recording | 16 checkpoints, 16 reference screenshots, ground truth `RESULT PASS` |

The window is **1440 x 900** under the harness whatever the emulator would
choose: `record-macro.py` resizes it to the display size before recording and
`replay.py` resizes it to the reference image's size on replay. A terminal left
alone rounds to whole character cells and lands a few pixels short.

## What this entrant needed, and what it revealed

****it was running the wrong shell**** — left alone pterm starts the shell named in `/etc/passwd`, which is dash in this image. It came up as `-sh` with the working directory at `/`, so `/root/.bashrc` never ran, the prompt was not `parrot$ ` and `corpus/boxes.sh` was simply not found. That breaks the premise the whole group rests on — every entrant running the *same* bash, `less` and corpus — so it is launched with `-e /bin/bash -l`.

****the slowest entrant in the group by a wide margin**** — `seq` took **18,726 ms** against xterm's 1,487 ms — roughly twelve times slower — and `plain` 8,286 ms against 1,501 ms. Its `BLOCK_WAIT` is 47 s, computed as 2.5x its worst measured block.

**`-fn` takes a **Pango** font name** — not an Xft one. `DejaVu Sans Mono:size=11`, which works for st and mlterm, makes pterm exit with `unable to load font` before mapping a window.

**`TERM` is `xterm`** — not `xterm-256color` — the only entrant that does not advertise 256 colours in its terminfo name, though it renders them.

