# GNU Emacs 29.3 — measured landmarks

Emacs has a real X11 window, so it is driven as a windowed application rather
than inside an xterm — unlike Vim, Neovim and nano, which have no window of
their own. Its Meta bindings arrive as **Alt** directly: a GUI Emacs receives
the modifier, where a terminal application only ever sees an ESC prefix (see
[`../nano/MEASUREMENTS.md`](../nano/MEASUREMENTS.md) for the other side of that).

Nothing is configured: no `init.el`, no `.emacs`. Emacs runs on its defaults,
which is why block 1 is the splash screen and why the run leaves `~` backup
files behind.

| | |
| - | - |
| `WM_CLASS` | `("emacs", "Emacs")` |
| Frame title | `*GNU Emacs* - GNU Emacs at <hostname>` — the container ID, **different every run** |
| Text area | 43 lines a screen |
| Autosave | no |
| Worst RMSE on replay | **0.066** |

The changing hostname in the frame title never reaches a screenshot:
`pin-windows.sh` sets `[Deco] {NONE}`, so there is no title bar to capture. It
would be a moving pixel in any run that kept decorations.

## The steps

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | splash screen, nothing to dismiss |
| 2 | Open file | `C-x C-f` · `src/price_calculator.py` · `RET` |
| 3 | Scroll to function | `C-v` x2 |
| 4 | Find identifier | `C-s` · `tax_rate` · `RET` |
| 5 | Select line | `C-s` `C-s` · `RET` · `C-a` · `C-SPC` · `C-n` |
| 6 | Duplicate line | `M-w` · `C-y` |
| 7 | Undo duplicate | `C-/` **x1** |
| 8 | Replace all | `M-<` · `M-%` · `tax_rate` `RET` · `vat_rate` `RET` · `!` |
| 9 | Undo replace | `C-/` **x1** |
| 10 | Insert comment | `C-s` · `return subtotal + tax` `RET` · `C-a` · `C-o` · text |
| 11 | Save file | `C-x C-s` |
| 12 | Reopen file | `C-x k` `RET` · `C-x C-f` · path · `RET` |
| 13 | Open large file | `C-x C-f` · path · `RET` · **`y`** |
| 14 | Go to line | `M-g g` · `120000` · `RET` |
| 15 | Page down | `C-v` x10 → L120000 to L120427 |
| 16 | Go to start | `M-<` |
| 17 | Type block | the ten lines, each + `RET` |
| 18 | Global replace | file by file, with **absolute** paths |

## Four things, three of them found the hard way

**Emacs is the only editor here that refuses the file until you agree.**

```text
File component_library.py is large (9.5 MiB), really open?
    (yes, no, literally, ?)
```

`large-file-warning-threshold` defaults to 10,000,000 bytes and the generated
module is 10,006,238 — six thousand bytes over the line. `y` answers it. Nothing
else in the group asks.

**isearch does not survive a checkpoint.** Block 4 originally left isearch
active so the match would still be highlighted in the reference image. The
checkpoint sends `Scroll_Lock`, which ends isearch — so block 5's `C-s` started
a *fresh* search instead of repeating the previous one, point never advanced,
and the recording duplicated line 110 instead of 117. Every block after it was
wrong, and all eighteen screenshots were taken quite happily. Each search is now
self-contained: `RET` closes it inside the block that opened it, and `C-s C-s`
repeats the term in the next.

**`find-file` offers the current buffer's directory.** By block 18 the current
buffer is `src/component_library.py`, so a relative `src/legacy/orders.py`
resolves to `~/project/src/src/legacy/orders.py`. Emacs cheerfully opens an
empty buffer under that name, the query-replace finds nothing, and `C-x C-s`
writes an empty file where nobody looks. Block 18 uses absolute paths.

**Emacs leaves `~` backups.** `make-backup-files` is on by default, so the first
save of each legacy file writes `orders.py~`, `pricing.py~`, `shipping.py~`
holding the *pre-replace* text. An unscoped `grep -r LEGACY_SKU src/legacy/`
therefore reports twelve occurrences still present while all three real files
are correct. `common/check-result.sh` scopes that assertion to `*.py` and lists
the leftovers as information — no other editor in the group leaves any.

## Where Emacs is shortest

**One undo for the duplicate**, against two everywhere except Vim and Neovim.
The region selected in block 5 ends in a newline, so `C-y` reinserts a whole
line in one change — there is no separate "open a line" step to undo, and no
auto-indent to fight. `C-o` in block 10 is the same idea: it opens a line
without running electric-indent, so the four spaces are typed rather than
inherited and then doubled.

## `find-file` resolves relative to the *current buffer*, and block 13 lost a run to it

This is written up under block 18 in `drive-scenario.sh`, and block 13 fell into
it anyway.

`C-x C-f` offers the current buffer's directory as its default. After block 12
the current buffer is `src/price_calculator.py`, so its directory is
`~/project/src/` — and typing the relative `src/component_library.py` there
resolves to:

```text
/root/project/src/src/component_library.py
```

which does not exist. Emacs does not complain. It opens an **empty buffer** under
that name, the large-file prompt never appears because there is no large file,
and the `y` that was meant to answer that prompt is typed *into the buffer*.

Everything after it then ran against a one-character scratch buffer. `M-g g
120000` stayed on line 1, both page-downs did nothing, and the ten lines of
block 17 were typed into a file Emacs could not even auto-save. Check 17 of that
recording is a `*Warnings*` window reading:

```text
Error (auto-save): Auto-saving component_library.py: Opening output file:
No such file or directory, /root/project/src/src/#component_library.py#
```

All eighteen screenshots passed. Checks 13 and 15 were byte-identical, which is
what [`../common/check-screens.sh`](../common/check-screens.sh) now exists to
catch. Block 13 uses an absolute path, like block 18.

## The frame is 1440x900 — but check it every time

Emacs sizes its frame in whole character rows, so it does not always land on the
height fluxbox asks for. One recording came out **1440x933** on a 900 px screen,
which pushes the **mode line off the bottom edge** — and the mode line is the
only place Emacs shows a line number, so checks 14, 15 and 16 lost the one piece
of evidence that they had done anything.

It still replayed 18/18, because replay clips to the screen the same way the
reference did. It cost accuracy rather than correctness: worst RMSE was
**0.139** against **0.026** for the run at the right size, the difference being
a band at the bottom of every image where the two disagreed.

`drive-scenario.sh`'s `CP()` prints a warning when the geometry is not
1440x900. It is not decoration — if the recording log has any of these, throw
the recording away:

```text
WARNING: 'Load app' would capture WIDTH=1440 HEIGHT=933
```

## `Scroll_Lock` is not inert here

The checkpoint key is `Scroll_Lock`, and Emacs binds it: every checkpoint
toggles `scroll-lock-mode` in the current buffer, which the mode line reports as
`ScrLck` and announces in the echo area. It alternates on and off down the whole
recording. The ground-truth check confirms the scenario's edits are unaffected,
but it is visible in every screenshot and it is the harness, not the editor.
