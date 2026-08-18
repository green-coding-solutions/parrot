# Eclipse IDE 4.36 (2025-06) — measured landmarks

The package is **Eclipse IDE for Java Developers**, which is what the download
page offers first and what most people mean by "Eclipse". It has no Python
tooling and none was added: no PyDev, no language server. What it does have is
the platform's bundled **tm4e** TextMate grammars, so `price_calculator.py`
opens fully syntax-coloured with working folding regions — just with no symbol
index, no completion and no inspections behind it. The Problems view stays at
one warning all run, and that warning is about the project's encoding.

| | |
| - | - |
| `WM_CLASS` | `("Eclipse", "Eclipse")` — **shared with every dialog** |
| Window title | `eclipse-workspace - Eclipse IDE`, rewritten to include the open file's path |
| Text area | **33 lines a screen** — the smallest in the group |
| Wheel scroll | 3 lines per click, clamped at end of file |
| Autosave | no |
| Worst RMSE on replay | **0.0066** |

Thirty-three lines is the number to keep in mind when reading Eclipse's block
times. The default Java perspective spends the window on a Package Explorer, a
Task List, an Outline and a Problems view, and the editor gets what is left —
against Vim's 47 lines in the same 1440x900.

## Eclipse is the only editor here whose main window needs a title to find it

Every other editor in this group is picked out of the window tree by `WM_CLASS`.
Eclipse cannot be:

```text
23069709 1440x900  class=('Eclipse','Eclipse')  name='eclipse-workspace - Eclipse IDE'
23068707  690x290  class=('Eclipse','Eclipse')  name='Eclipse IDE Launcher'
23068687  200x200  class=('Eclipse','Eclipse')  name='Eclipse'
23069705  200x200  class=('Eclipse','Eclipse')  name="PartRenderingEngine's limbo"
```

All four report `_NET_WM_WINDOW_TYPE_NORMAL` and none carries a `WM_WINDOW_ROLE`,
so the res-name/res-class/role terms `pin-windows.sh` already had cannot separate
them. Without a further term the main-window rule matches the launcher too, and
fluxbox blows a 690x290 dialog up to a full-screen undecorated 1440x900 — which
is not a dialog anyone has ever clicked Launch in.

`common/pin-windows.sh` therefore grew an optional **title** pattern, and the
scenario passes `eclipse-workspace.*`. It is matched once, when the window is
first mapped, so it does not matter that Eclipse rewrites its own title the
moment block 2 opens a file.

The dash in that setup-command — `pin-windows.sh Eclipse 1440 900 Eclipse -
eclipse-workspace.*` — is "no role", and it is a dash rather than `''` because
GMT builds argv with `shlex.split(cmd, posix=False)`: quote characters survive
as literal parts of the argument, so an empty `''` would arrive as a
two-character string and match nothing.

## The steps

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | Launch · close Welcome · File > Open Projects from File System · `/root/project` · Finish |
| 2 | Open file | click Package Explorer · `Ctrl+Shift+R` · `price_calculator.py` · `Return` |
| 3 | Scroll to function | 30 x wheel-down at 760,400 |
| 4 | Find identifier | `Ctrl+F` · `Escape` · `Ctrl+F` · `Ctrl+A` · `tax_rate` |
| 5 | Select line | `Return` · `Escape` · `Home` · `Shift+End` |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` |
| 7 | Undo duplicate | `Ctrl+Z` **x2** |
| 8 | Replace all | `Ctrl+Home` · `Ctrl+F` · `Ctrl+A` `tax_rate` · chevron · `Ctrl+A` `vat_rate` · Replace All |
| 9 | Undo replace | `Escape` · `Ctrl+Z` **x1** |
| 10 | Insert comment | `Ctrl+F` · `return subtotal + tax` · `Escape` · `Home` · text · `Return` |
| 11 | Save file | `Ctrl+S` |
| 12 | Reopen file | `Ctrl+W` · click Package Explorer · `Ctrl+Shift+R` · path · `Return` |
| 13 | Open large file | `Ctrl+Shift+R` · `component_library.py` · `Return` |
| 14 | Go to line | `Ctrl+L` · `120000` · `Return` |
| 15 | Page down | `Next` x10 → L120000 to L120330 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | the ten lines, each + `Return` |
| 18 | Global replace | `Ctrl+H` · `LEGACY_SKU` · Replace... · `ARCHIVE_SKU` · OK |

## Block 1 imports the project, and that is a deliberate call

Eclipse has no "open this folder" argument. VS Code, IntelliJ and PyCharm are
all handed `/root/project` on the command line and arrive at block 2 with the
project open; Eclipse arrives at an empty workspace. Its equivalent action is
**File > Open Projects from File System**, so that is where the same cost is
paid — inside block 1, exactly where IntelliJ's project-open and indexing cost
already sits.

This is not tidiness. With no project in the workspace, Eclipse's workspace-wide
File Search has nothing to search, and block 18 would have to fall back to the
file-by-file path that nano, Emacs and Sublime take. Importing is what makes
Eclipse's global replace comparable to VS Code's rather than to nano's.

The import leaves a `.project` file in the project directory. Nothing else in
the tree is touched.

## Three things that make a screenshot lie

**The first `Ctrl+F` of a fresh workspace cannot be typed into.** It opens the
inline Find/Replace overlay *and* a one-time notification:

```text
New Find/Replace Overlay
Find and replace can now be done using an overlay embedded inside the editor.
If you prefer the dialog, you can disable the overlay in the preferences or
disable it now.
```

The notification takes the keyboard focus and **never times out** — it was still
up 27 seconds later. Everything typed while it is showing goes nowhere: the
first attempt at block 4 typed `tax_rate` into a void, left the find field
showing its placeholder, and checkpointed a screenshot that looked entirely
correct because the editor was untouched and the overlay was open.

`Escape` dismisses it. `Escape` also closes the overlay and hands focus back to
the editor, which is why block 4 presses `Ctrl+F` twice. Clicking the
notification's ✕ works too, but the click reaches the editor underneath and
moves the caret — measured landing at line 115, column 36, end of line — and the
very first attempt at this then typed `tax_rate` straight into the source file.

**Key bindings need a focused workbench part.** When the import wizard closes,
or when `Ctrl+W` closes the last editor, no part in the workbench holds focus —
and Eclipse resolves key bindings against the focused part, so `Ctrl+Shift+R`
does nothing at all. Not an error, not a beep: nothing. A recording lost block 2
to this and carried on for sixteen more blocks against an editor that had never
opened. Blocks 2 and 12 each click the Package Explorer first.

**`Tab` does not move between the overlay's fields.** It leaves the overlay
altogether. The `Ctrl+A` that follows then reaches the *editor* and selects all
337,538 lines, and the next keystroke would have replaced the file with one
word. Block 8 clicks each field instead — and clicks each one's `Ctrl+A` before
typing, because the overlay retains the previous term and pre-selects it in the
find field but **not** in the replace field.

## Where Eclipse is at its best

**The project-wide replace writes to disk.** `Ctrl+H` opens the Search dialog
already on its File Search tab, with the scope already `Workspace` and the file
pattern already `*`. `Replace...` states the scope before acting — *"Replacing
12 matches in 3 files:"* — and `OK` applies it. All three files are written by
Eclipse itself, with no dirty editors left behind. That is precisely the trap
that cost Sublime its project-wide path, and Eclipse walks past it.

**One undo for the replace-all**, and the caret lands where you would want it
after every search. `Home` is smart-home — first non-whitespace, not column 0 —
so block 5's `Shift+End` selects the statement without its indent, and block 6's
`Return` auto-indents the pasted copy back to column 5 without any of it being
copied.
