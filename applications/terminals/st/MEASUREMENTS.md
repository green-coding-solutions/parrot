# st — measured values

Read off a running window in `window-container`. st is the minimalism entrant:
roughly 2k lines against xterm's 65k, and the only one with no configuration
file of any kind.

| | |
| --- | --- |
| package | `stterm` 0.9-1 (Debian's st, **not** upstream st) |
| launcher | `/usr/local/bin/parrot-st` → `exec st -f "DejaVu Sans Mono:size=11"` |
| `WM_CLASS` | `"st-256color", "st-256color"` — both fields identical |
| pin string | `st-256color` — st names itself after its `TERM`, which is neither the binary name (`st`) nor the package name (`stterm`). Guessing `st` here matches nothing. |
| **window size** | **1435 × 897** |
| **grid** | **159 columns × 47 rows** |
| `TERM` | `st-256color` |
| locale inside | `en_US.UTF-8`, from `/etc/parrot-env` via the launcher |
| steady screen | yes, out of the box |
| background | **dark** (st's default palette; xterm's is light) |

## Identical geometry to xterm, and that is not a coincidence

st comes back at exactly the same 1435 × 897 and 159 × 47 as xterm. Both are raw
Xlib, both are rendering DejaVu Sans Mono at size 11, and both default to a 2 px
border, so they arrive at the same 9 × 19 cell by the same arithmetic. The two
minimal entrants are therefore directly comparable pixel for pixel — which is
worth knowing, because it is not going to be true of the toolkit and GPU
entrants.

## What cannot be configured, and stays at Debian's default

st's answer to configuration is "edit `config.h` and recompile", so the launcher
is st's *entire* configuration surface. Everything the other six get from a
config file is either a command-line flag here or left alone:

| | |
| --- | --- |
| font, size | ✅ `-f "DejaVu Sans Mono:size=11"` |
| scrollback length | ❌ compile-time — Debian's patched default |
| the sixteen ANSI colours | ❌ compile-time |
| cursor shape | ❌ compile-time |
| bell | n/a — st has no visual bell to turn off |

That is a real asymmetry with the other six rather than something to work
around, and it is why the package version matters more for this entrant than for
any other: **this is Debian's st, and Debian's scrollback patch is what makes
blocks 3 and 4 possible at all.** Upstream st has no scrollback, so the same
script against a self-built st would fail those two blocks. Verified working with
Shift+PageUp before st went on the list.

`size=11` and not `pixelsize=`: an Xft name accepts either, and the rest of the
group is configured in points, so points is what keeps the comparison
like-for-like.

## Not yet done

Only the launch path is verified — window, grid, locale, `TERM`, and that a
corpus block runs and logs itself. The eighteen blocks have not been hand-driven,
so there is no `drive-scenario.sh` and no recording.
