# Vim 9.1.697 in xterm — measured landmarks

Vim has no window of its own, so "the application" for window-matching purposes
is a full-screen xterm with a bash prompt in `/root/project`, and block 1 is
typing `vim` at that prompt. Everything after it is sent to the terminal.

Nothing is configured: no `.vimrc` is written, no `.Xresources` is read. Vim
runs on its compiled-in defaults plus Debian's
`/usr/share/vim/vim91/defaults.vim`, which is what you get from `apt install vim`
followed by `vim`.

## The terminal

| | |
| - | - |
| `WM_CLASS` | `"xterm", "XTerm"` — capital T, and fluxbox matches case-sensitively |
| Title | `vim-benchmark` |
| Font | DejaVu Sans Mono 11, named explicitly on the command line |
| Grid | **159 columns x 47 rows** |
| Window while measuring by hand | 1435x897 |
| Window while recording and replaying | **1440x900** |

The two sizes are the one thing to understand here. xterm rounds its own window
down to whole character cells, so fluxbox's `[Dimensions] {1440 900}` settles at
1435x897. But `record-macro.py` and `position-window.sh` both call
`xdotool windowsize`, which goes round the size hints, and xterm accepts the
five spare pixels as margin. So a hand-launched terminal is 1435x897 and every
recording and every replay is 1440x900 — the two paths that matter agree with
each other, which is what counts.

`+sb` removes the scrollbar; with it, a column-width strip on the left edge
shifts every coordinate in the window.

## The scenario, step by step

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | click for focus · `vim` · `Return` → the intro screen |
| 2 | Open file | `:e src/price_calculator.py` |
| 3 | Scroll to function | `Ctrl+F` x2 → top of window at ~line 92 |
| 4 | Find identifier | `/tax_rate` |
| 5 | Select line | `n` · `V` |
| 6 | Duplicate line | `y` · `p` |
| 7 | Undo duplicate | `u` **x1** |
| 8 | Replace all | `:%s/tax_rate/vat_rate/g` |
| 9 | Undo replace | `u` **x1** |
| 10 | Insert comment | `/return subtotal + tax` · `O` · `# benchmark complete` · `Escape` |
| 11 | Save file | `:w` |
| 12 | Reopen file | `:bd` · `:e src/price_calculator.py` → reopens at line 118 |
| 13 | Open large file | `:e src/component_library.py` → `337537L, 10006238B` |
| 14 | Go to line | `:120000` → `120000,5  63%` |
| 15 | Page down | `Ctrl+F` x10 → line 120423, **42 lines a screen** |
| 16 | Go to start | `gg` |
| 17 | Type block | `i` · the ten lines, each + `Return` · `Escape` |
| 18 | Global replace | `:set hidden` · `:args src/legacy/*.py` · `:argdo %s/LEGACY_SKU/ARCHIVE_SKU/g \| update` · `Return` |

### Where Vim differs from the GUI editors

**One undo, not two.** Blocks 6 and 8 are each a single change to Vim, so `u`
once is the whole of it — where VS Code and IntelliJ both need two `Ctrl+Z` for
the duplicate, because the Return that opens the line and the paste that fills
it are separate undo stops there.

**Two keystrokes to duplicate a line.** `y` on a linewise selection yanks a
*line*, so `p` knows to put it below rather than at the cursor. The GUI editors
need four keystrokes to say the same thing.

**`:set hidden` before `:args`.** The `component_library.py` buffer holds the ten
typed lines and has never been written, so `:args` refuses to abandon it with
E37. `| update` then writes each file only if the substitution changed it.

**The comment lands at four columns**, like VS Code and unlike IntelliJ: `O`
opens a line above with the indent of the line below it.

**Vim does not autosave.** `src/component_library.py` is byte-identical to what the
generator wrote after the run.

## The flake that a screenshot could not see

The first recording passed 18/18 with the worst check at **RMSE 0.126** — inside
the 0.2 threshold, but only just, and this project's rule is to read the RMSE
column rather than the pass count. It was right to.

Replaying block 14 on its own put the cursor at `120000,5`. Replaying blocks
1-14 in sequence produced a capture showing the *top* of the file with
`:120000` still on the command line — and then intermittently produced the
correct one. What had actually happened: the command ran, and xterm had not
repainted its 159x47 grid within the checkpoint's five-second settle. The
capture was a stale screen.

It passed anyway because **one screenful of fixed-width catalogue lines looks
very much like another**. Two completely different regions of a 337,537-line
file — line 37 against line 120000 — differ by 0.126 RMSE. Only the ruler in
the bottom-right corner really distinguishes them, and it is perhaps 60 pixels
of a 1,296,000-pixel image.

The fix was to give blocks 13-17 enough settle time for the repaint: 22 s after
opening the 10 MB file, 10 s after the jump, 8 s after the paging. Worst RMSE
went from 0.126 to **0.0049**.

Two things worth carrying to the other terminal editors:

- A uniform-looking buffer makes the screenshot check nearly blind. On the
  large-file blocks the ground truth and the ruler are what you are really
  relying on, so give the repaint room rather than trusting the check to notice.
- A check that passes at 0.126 is not a check that passed. It was a stale frame
  both times, and on a busier machine it would have been a failure.
