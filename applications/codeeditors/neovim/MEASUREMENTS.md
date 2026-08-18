# Neovim 0.9.5 in xterm — measured landmarks

Neovim reuses [`../vim/MEASUREMENTS.md`](../vim/MEASUREMENTS.md) wholesale. The
driver is Vim's with one keystroke changed — block 1 types `nvim` instead of
`vim` — and it recorded first time, 18/18, with no warnings and the ground truth
clean.

That is itself the finding worth writing down: every keystroke of this
eighteen-step session is identical between the two editors, including the undo
counts, `:argdo`, and the `Press ENTER` that follows it.

| | |
| - | - |
| `WM_CLASS` | `"xterm", "XTerm"` — Neovim has no window of its own |
| Title | `nvim-benchmark` |
| Grid | 159 columns x 47 rows, same font and size as Vim's |
| Autosave | no — `src/component_library.py` is untouched on disk |
| Worst RMSE on replay | **0.0049**, the same as Vim's |

## The one real difference

`:set hidden` is **redundant** here and load-bearing in Vim. Neovim has had
`'hidden'` on by default since 0.6, so the buffer holding the ten typed lines can
be abandoned without complaint; Vim refuses with `E37` and needs the option set
first.

The keystroke is sent anyway, so block 18 is the same sequence in both editors
and the two rows in the block table stay comparable. Sending a redundant
keystroke is cheaper than explaining why one editor's block has one fewer.

## Result

18/18 on replay in a fresh container, worst RMSE 0.0049, ground truth OK.
GMT: `MEASUREMENT SUCCESSFULLY COMPLETED`, 18 PASS, 0 FAIL.
