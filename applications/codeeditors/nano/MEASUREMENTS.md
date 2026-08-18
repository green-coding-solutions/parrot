# GNU nano 7.2 in xterm — measured landmarks

nano shares Vim's terminal setup — see [`../vim/MEASUREMENTS.md`](../vim/MEASUREMENTS.md)
for the xterm geometry, the 159x47 grid and the 1435x897-vs-1440x900 window
question, all of which are identical.

Everything else is different. nano has no modal command line, no linewise
registers and no project-wide replace, so this is the most hand-written driver
in the group.

| | |
| - | - |
| `WM_CLASS` | `"xterm", "XTerm"` — nano has no window of its own |
| Title | `nano-benchmark` |
| Text area | 43 lines, between the title bar and the two-line help bar |
| Autosave | no |
| Worst RMSE on replay | **0.000034** — the closest to pixel-perfect in the group |

## Meta shortcuts are ESC, not Alt

`xdotool key alt+f` does **not** reach nano as `M-F`. xterm's `metaSendsEscape`
is off by default, so the keystroke arrives as a bare `f` — and, in the first
attempt, a stray space with it:

```text
[ File " src/price_calculator.py" not found ]
```

The toggle never fired and the space landed in the filename. Every Meta binding
in the driver is therefore sent as `Escape` followed by the key, which is what a
terminal actually carries. That applies to `M-F` (new buffer), `M-W` (repeat
search), `M-6` (copy) and `M-U` (undo).

## The scenario, step by step

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | click for focus · `nano` · `Return` |
| 2 | Open file | `^R` · `ESC f` · `src/price_calculator.py` · `Return` |
| 3 | Scroll to function | `^V` x2 → top at ~line 83 |
| 4 | Find identifier | `^W` · `tax_rate` · `Return` |
| 5 | Select line | `ESC w` · `Home` · `^6` · `End` |
| 6 | Duplicate line | `ESC 6` · `End` · `Return` · `^U` |
| 7 | Undo duplicate | `ESC u` **x2** |
| 8 | Replace all | `^\` · `tax_rate` · `Return` · `vat_rate` · `Return` · `a` |
| 9 | Undo replace | `ESC u` **x4** |
| 10 | Insert comment | `^W` · `return subtotal + tax` · `Home` · `    # benchmark complete` · `Return` |
| 11 | Save file | `^O` · `Return` |
| 12 | Reopen file | `^X` · `^R` · `ESC f` · `src/price_calculator.py` · `Return` |
| 13 | Open large file | `^R` · `ESC f` · `src/component_library.py` · `Return` |
| 14 | Go to line | `^/` · `120000` · `Return` |
| 15 | Page down | `^V` x10 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | the ten lines, each + `Return` |
| 18 | Global replace | **three times**: open, `^\`, replace, `a`, `^O`, `Return` |

## Four undos for one replace-all

This is the sharpest difference in the comparison. Every other editor here
treats a replace-all as a single undoable operation. nano treats it as one undo
per occurrence:

- after `^\ tax_rate → vat_rate → a`, the status line reads
  `[ Replaced 4 occurrences ]`
- after **one** `ESC u` it reads `[ Undid replacement ]` — and searching for
  `vat_rate` still finds one, reporting `[ Search Wrapped ]`
- only after the **fourth** does the search report `[ "vat_rate" not found ]`

Measured, not guessed, and it is the kind of thing that would have produced a
screenshot-perfect recording with three stray `vat_rate` below the fold. The
ground-truth check counts all four occurrences for exactly this reason.

## No project-wide replace at all

Block 18 is the file-by-file path the scenario explicitly allows for: open the
file into its own buffer, replace within it, write it out — three times over.
Twenty-one keystrokes and three prompts, against Vim's single `:argdo` and VS
Code's one dialog. That is not a deficiency in the driver; it is the measurement.

## Two smaller things

**`^R` alone would splice, not open.** Without the `M-F` toggle nano reads the
file into the *current* buffer, which leaves it unnamed — and `^O` would then
prompt for a filename that the recorded keystrokes do not supply.

**`Home` goes to column 0, not to the first non-blank.** So the selection in
block 5 includes the four spaces of indent, which is what makes the paste land
correctly indented in an editor that has no autoindent to fall back on.
