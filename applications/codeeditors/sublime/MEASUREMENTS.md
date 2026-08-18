# Sublime Text build 4200 — measured landmarks

Sublime is the only editor in this group that puts **nothing** in front of the
editor on first launch: no onboarding, no sign-in, no trust prompt, no balloon.
It opens on the sidebar, an empty untitled buffer and a status bar reading
`Line 1, Column 1`. Block 1 is the shortest here.

| | |
| - | - |
| `WM_CLASS` | `("sublime_text", "Sublime_text")` |
| Helper window | one, 10x10, same class — the main-window pin rule takes the larger |
| Editor viewport | 44 lines |
| Wheel scroll | 3 lines per click, 30 clicks to reach `calculate_total` |
| Autosave | no |
| Worst RMSE on replay | **0** on the last three checks |

Most keystrokes match VS Code's: `Ctrl+P` to open, `Ctrl+F`/`Ctrl+H` to find and
replace, `Ctrl+Shift+Enter` to insert a line above, `Ctrl+G` to go to a line, two
`Ctrl+Z` for the duplicate and one for the replace-all.

## Find in Files: what it does, and why block 18 does not use it

Sublime has a project-wide replace. **This recording does not use it**, and the
reason is worth writing down in full, because everything about it looks like it
should work.

Driven by hand, the sequence is:

1. `Ctrl+Shift+F` opens the panel with three fields: Find, Where, Replace.
2. **Where must be filled.** Its placeholder reads "Open files and folders", but
   that is placeholder text and not a default — with it empty, the Replace
   button and `Ctrl+Alt+Enter` both do nothing at all, silently.
3. Where **is** focusable by clicking, but only once the panel has settled.
   Clicking too soon after `Ctrl+Shift+F` leaves focus in Replace, and text
   typed for Where lands there instead — which is how `ARCHIVE_SKU` became
   `ARCHIVE_SKUfolders>` during measurement.
4. `Tab` does not reach it. The order is Find → Replace, skipping Where entirely.
5. Neither the Replace button nor `Ctrl+Alt+Enter` triggers the replacement.
   **Return** does — but only when the *button* already holds keyboard focus.
   Return with focus in the Replace field runs a Find instead and opens a
   "Find Results" tab.
6. And then the replacement is only in memory: Sublime opens each affected file
   as a **dirty tab** and writes nothing. Three explicit `Ctrl+S` are needed.
   VS Code's equivalent writes straight to disk.

All six were established by hand, and by hand it works — twelve occurrences
across three files, replaced and saved.

**It could not be made to replay.** Two recordings of that sequence looked
correct on screen and left the files untouched on disk; the ground-truth diff
was the only thing that noticed. A third left a combo dropdown open over the
editor, so `import -window` captured the obscured region as solid black and the
reference image for block 18 was a black rectangle with a sliver of tab bar
above it — the exact signature the project's notes describe.

So block 18 uses the file-by-file path the scenario explicitly allows for
("the rest open each file, replace within it and save"), with the in-file
replace panel that block 8 already verifies. **The number in the block table is
therefore Sublime's file-by-file cost, not its project-wide cost.** That is a
limitation of this harness rather than of the editor, and it is stated here so
the figure is not read as the other thing.

## The steps

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | nothing to dismiss |
| 2 | Open file | `Ctrl+P` · `src/price_calculator.py` · `Return` |
| 3 | Scroll to function | 30 x wheel-down at 740,450 |
| 4 | Find identifier | `Ctrl+F` · `tax_rate` → "1 of 4 matches" |
| 5 | Select line | `Return` · `Escape` · `Home` · `Shift+End` |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` |
| 7 | Undo duplicate | `Ctrl+Z` **x2** |
| 8 | Replace all | `Ctrl+H` · `Ctrl+A` `tax_rate` · `Tab` · `Ctrl+A` `vat_rate` · `Ctrl+Alt+Return` · `Escape` |
| 9 | Undo replace | `Ctrl+Z` **x1** |
| 10 | Insert comment | `Ctrl+F` · `return subtotal + tax` · `Escape` · `Ctrl+Shift+Return` · text |
| 11 | Save file | `Ctrl+S` |
| 12 | Reopen file | `Ctrl+W` · `Ctrl+P` · path · `Return` |
| 13 | Open large file | `Ctrl+P` · `src/component_library.py` · `Return` |
| 14 | Go to line | `Ctrl+G` · `120000` · `Return` |
| 15 | Page down | `Next` x10 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | the ten lines, each + `Return` |
| 18 | Global replace | file by file — see above |
