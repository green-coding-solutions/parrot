# xterm — measured values

Everything here was read off a running window in `window-container`, not taken
from documentation. xterm is the reference entrant: no widget toolkit, straight
Xlib, and the behaviour every other emulator is bug-compatible with.

| | |
| --- | --- |
| package | `xterm` 390-1ubuntu3 (Ubuntu 24.04) |
| launcher | `/usr/local/bin/parrot-xterm` → `xrdb -load /root/.Xresources; exec xterm` |
| `WM_CLASS` | `"xterm", "XTerm"` — res_name `xterm`, res_class `XTerm` |
| pin string | `xterm` (fluxbox matches res_name) |
| **window size** | **1435 × 897**, at 0,0 — *not* the 1440 × 900 requested |
| **grid** | **159 columns × 47 rows** |
| cell size | 9 × 19 px |
| `TERM` | `xterm-256color` |
| `tput colors` | 256 |
| steady screen | yes, out of the box — no configuration needed |
| scrollback | 20,000 lines (`XTerm*saveLines`) |

## Two different window sizes, and which one the driver asserts

Left to itself, xterm is **1435 × 897**, because it sizes itself to whole
character cells and then adds its border:

    159 cols x  9 px = 1431, + 2 x 2 px internalBorder = 1435
     47 rows x 19 px =  893, + 2 x 2 px internalBorder =  897

Measured six times across six relaunches, identical every time — stable, not
racy.

**Under the harness it is 1440 × 900.** `record-macro.py` resizes the window to
the display size before recording, and `replay.py` reads the first reference
image's dimensions and forces the replay window to match, so both ends agree on
1440 × 900 and the extra five and three pixels become padding. The driver
asserts **1440 × 900** for that reason, and all eighteen reference screenshots
are 1440 × 900.

The natural size is recorded here anyway because it is what determines the grid,
and the grid is what determines how the corpus wraps.

## Font and locale

DejaVu Sans Mono at `faceSize: 11`, which is what produces the 9 × 19 cell. The
group is configured in points rather than pixels so that st — whose only
configuration surface is a command-line Xft name — can be given the same size.

The locale arrives twice, and it is load-bearing rather than cosmetic: launched
without `LANG`, xterm renders every box-drawing and CJK glyph as Latin-1
mojibake (`â` where `│` belongs). Both `XTerm*utf8: 1` in the resources and
`/etc/parrot-env` in the launcher say so independently. See the README.

## Block timings

Measured from the shell inside the window, scaled corpus, one run:

| block | ms | block | ms |
| --- | --- | --- | --- |
| 02 plain | 1,501 | 09 boxes | 1,472 |
| 05 attributes | 1,414 | 10 redraw | 1,407 |
| 06 colours-256 | 1,429 | 11 longlines | 1,471 |
| 07 colours-true | 1,467 | 12 seq | 1,487 |
| 08 unicode | 1,428 | 13 ls-tree | 1,480 |

14,556 ms of command work in total. These are *writer* times — the shell's view
of how long the command took — and they do not include the time the emulator
spends settling afterwards, which is what the driver actually has to wait for.

## Ground truth

`corpus/verify.sh` re-reads `/tmp/parrot-term.log` and the X PRIMARY selection.
Confirmed to discriminate in both directions: it reports `RESULT FAIL` naming
exactly the missing block when one has not run, and `RESULT PASS` when all ten
log lines and a selection are present.

## The keystroke and mouse blocks

Hand-driven against a live window, with an image hash taken after every
keystroke, so that a press which did nothing is visible as a repeated hash
rather than as a checkpoint that quietly passes.

| block | what was measured |
| --- | --- |
| 1 load | prompt on screen and steady within ~4 s; nothing to dismiss |
| 3 scroll back | `shift+Prior` ×10 → **ten distinct screens** |
| 4 scroll to end | `shift+Next` ×10 → the same ten hashes **in reverse**, and the final screen is byte-identical to where block 2 ended |
| 14 pager | `less corpus/plain.txt`, first screen in <2 s, `Next` ×10 → ten distinct screens |
| 15 search | `/beacon` + Return → match drawn in reverse video at lines 00461 and 00503; `n` ×3 advances; `q` returns to the shell |
| 16 select | drag (72,190) → (700,300) leaves **200 chars** in X PRIMARY, and the screen stays steady with the selection on it |
| 17 clear | `clear` empties the screen — and the PRIMARY selection **survives it**, which is why block 18 can check for it |

Block 4's symmetry is the useful one: it is a real assertion about the emulator.
A terminal whose scrollback is lossy, or that clamps differently at the bottom,
lands somewhere else and fails against the reference.

## Two defects found by looking at the first recording

Both passed every automated check and were only visible in the artefacts.

**Block 8 was rendering tofu.** `日本語のテキスト` and the entire kana row drew as
empty boxes — DejaVu Sans Mono has no CJK coverage and the image had no fallback
font. `verify.sh` passed, all eighteen checkpoints were written, the log was
complete. Fixed by adding `fonts-wqy-microhei` to `install-common.sh`; the whole
recording was redone, because the block-8 reference image was wrong.

**The driver never stopped the recorder.** `record-macro.py` stops on `Pause`
and the first driver did not send it, so all eighteen checkpoints and
screenshots landed on disk and `record-session.sh` then waited forever with
nothing in its output saying why.

## Recording

| | |
| --- | --- |
| events | 643 |
| checkpoints | 18 |
| reference screenshots | 18 |
| driver wall time | 4m03s |
| ground truth | `RESULT PASS` — all ten blocks logged, 200-char selection |

The final reference image, `xterm-check-018.png`, is a screenshot of
`verify.sh`'s own output, so the ground truth is baked into the last frame of
the recording.

