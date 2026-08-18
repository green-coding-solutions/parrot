# VS Code 1.132.0 — measured landmarks

Every number here was read off a screenshot or off the file on disk in a
container brought up by `common/verify-editor.sh vscode --setup`, which runs
this client's own `usage_scenario.yml` setup-commands. Re-measure after any
version bump.

## Windows

| | |
| - | - |
| Main window `WM_CLASS` | `"code", "code"` — **both lowercase** |
| Main window `WM_WINDOW_ROLE` | `browser-window` |
| Dialog `WM_CLASS` | `"code", "Code"` — res_class capitalised |
| Dialog `WM_WINDOW_ROLE` | *(not set)* |
| Pinned size | 1440x900 at 0,0, no decorations |

The capitalisation is the trap. Every reference to VS Code outside the running
process — the `.desktop` file, the binary path, the docs — spells it `Code`, and
`pin-windows.sh code 1440 900 Code` therefore selects the **dialogs** and leaves
the editor unpinned at 1439x899. The role is what confines the rule to the
editor window; without it the same rule also drags every modal to 0,0 and stacks
it under the editor.

## Geometry

| Landmark | Position |
| -------- | -------- |
| Editor text area, safe click point | 740, 450 |
| Park position — blank space in the explorer | 200, 600 |
| Editor viewport | 41 lines |
| "Replace All" confirm dialog | client at 1,45 — 525x81 |
| ...its **Replace** button | 395, 87 |

The confirm dialog is placed by fluxbox's CascadePlacement, not by a rule of its
own: `pin-windows.sh`'s catch-all `[app] (title=.*)` / `[Position] (CENTER)`
block does **not** move it, which was confirmed by watching three different VS
Code dialogs — the clean-exit prompt, the unsaved-changes prompt and the replace
confirmation — all land at exactly 1,45 across two separate containers. It is
the first cascade slot, and it is reproducible here only because this scenario
never has a second extra window mapped at the same time. If a future step opens
one, this click is the thing that breaks: the symptom is the same RMSE on every
run of one check, and a black rectangle in the captured image.

## The scenario, step by step

Keystrokes only unless a coordinate is given.

VS Code runs on its own defaults — nothing is written to `settings.json`. That
means a fresh profile shows a three-page onboarding flow before the workbench is
usable, and the macro clicks through it:

| Page | Button | At |
| ---- | ------ | -- |
| "Welcome to VS Code — Sign in to use GitHub Copilot" | Continue without Signing In | 1064, 700 |
| "Make It Yours" — colour theme, **Dark 2026** preselected | Continue | 1125, 700 |
| "Build with AI Agents" | Get Started | 1117, 700 |

All three are drawn *inside* the editor window rather than as X windows, so
their coordinates follow the pinned 1440x900 geometry and do not depend on
fluxbox placement. What is left afterwards is the real default state: a
Restricted Mode banner across the top, a Welcome tab, and the chat panel open on
the right — which is why the editor text area is narrower here than in a
configured VS Code.

| # | Step | Input | End state, verified by |
| - | ---- | ----- | ---------------------- |
| 1 | Load app | `vscode /root/project`, then the three clicks above | Restricted Mode banner, Welcome tab, chat panel |
| 2 | Open file | click 740,450 · `Ctrl+P` · `src/price_calculator.py` · `Return` | Ln 1, Col 1 |
| 3 | Scroll to function | 35 x wheel-down at 740,450 | `def calculate_total` visible, cursor still Ln 1 |
| 4 | Find identifier | `Ctrl+F` · `tax_rate` | "1 of 4", Ln 110 Col 56 (8 selected) |
| 5 | Select line | `Return` · `Escape` · `Home` · `Shift+End` | Ln 117 Col 30 (25 selected) |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` | line 118 duplicates 117, Ln 118 Col 30 |
| 7 | Undo duplicate | `Ctrl+Z` **x2** | Ln 117 Col 30, tab not dirty |
| 8 | Replace all | `Ctrl+H` · `tax_rate` · `Tab` · `vat_rate` · `Ctrl+Alt+Return` · `Escape` | `vat_rate` on 110/117/121/123 |
| 9 | Undo replace | `Ctrl+Z` **x1** | `tax_rate` restored, tab not dirty |
| 10 | Insert comment | `Ctrl+F` · `return subtotal + tax` · `Escape` · `Ctrl+Shift+Return` · `# benchmark complete` | Ln 118 Col 25 |
| 11 | Save file | `Ctrl+S` | file on disk is 129 lines |
| 12 | Reopen file | `Ctrl+W` · `Ctrl+P` · `src/price_calculator.py` · `Return` | reopens at Ln 118 Col 25 |
| 13 | Open large file | `Ctrl+P` · `src/component_library.py` · `Return` | Ln 1 Col 1, 337,537 lines |
| 14 | Go to line | `Ctrl+G` · `120000` · `Return` | Ln 120000 Col 1 |
| 15 | Page down | `Next` x10 | Ln 120390 Col 1 — **39 lines per page** |
| 16 | Go to start | `Ctrl+Home` | Ln 1 Col 1 |
| 17 | Type block | the 10 lines of `constants_block.txt`, each + `Return` | Ln 11 Col 1, docstring starts at 11 |
| 18 | Global replace | `Ctrl+Shift+H` · `LEGACY_SKU` · `Tab` · `ARCHIVE_SKU` · `Ctrl+Alt+Return` · click 395,87 | "12 results in 3 files", then all 3 written |

### The four things that are not obvious

**Undo granularity differs per step.** Step 6 is two edits — the `Return` that
opens the line and the paste that fills it — so undoing it takes two `Ctrl+Z`.
Step 8's replace-all is one edit and takes one. Neither count is guessable;
both were read back off the buffer. The dirty marker on the tab is the cheap
way to tell you have gone far enough and not too far.

**Search direction makes step 4 land where it does.** VS Code's find starts at
the cursor, and step 3 scrolls with the wheel — which does not move the cursor,
so it is still at Ln 1 and the first hit is the one inside `calculate_total`.
Had step 3 used `PageDown`, the cursor would sit at ~Ln 121 and the first hit
would be in `apply_tax`, one function too far down. That is why the scroll is a
scroll and not a paging keystroke.

**`Return` does not answer the replace confirmation.** `xdotool getwindowfocus`
reports the *editor* while that modal is up — fluxbox never gives it the input
focus — so the keystroke goes to the window behind it and the dialog just sits
there. It has to be clicked.

**Step 12 reopens at line 118, not line 1.** VS Code restores per-file view
state, so the inserted line is on screen without navigating to it. Editors that
do not restore it need an extra step to satisfy "verify that the inserted line
is present"; this one does not.

**The park position is not in the editor.** With defaults, `editor.hover` is on,
so a pointer left over code raises a hover card a few hundred milliseconds
later — into whichever reference screenshot is being taken at the time. Blank
space in the explorer has nothing to hover.

**Autocomplete is on, and it does not corrupt the typed block.** This was worth
checking rather than assuming, because `editor.acceptSuggestionOnEnter` defaults
to on and the ten typed lines are identifiers in a 337,537-line buffer. Measured
result: the suggest widget never takes the Enter, and all ten lines land
verbatim. That is why nothing needed switching off.

**VS Code does not autosave.** After the typing step `src/component_library.py` is
byte-identical to what the generator wrote, so the "Save file" step measures a
real write. Contrast IntelliJ, which writes on a timer of its own — the
ground-truth report prints which of the two happened rather than insisting on
one.

## The one configured setting in the whole group

```json
{ "editor.largeFileOptimizations": false }
```

VS Code turns syntax highlighting off for a file it considers large, and "large"
is not only about bytes: `isTooLargeForTokenization()` trips at 20 MB **or
300,000 lines**, whichever comes first. `src/component_library.py` is 10 MB but
**337,537 lines**, so it crosses the line-count limit — and from block 13 to the
end of the run VS Code rendered it as an undifferentiated grey wall, while
IntelliJ, PyCharm, Android Studio, Eclipse, Sublime, Emacs, Vim and Neovim all
still coloured the same file.

It is a genuine default and there is a real argument for keeping it: not
tokenising 337,000 lines is exactly how VS Code stays responsive on a file this
size. It was turned off anyway, so that one editor in the group is not the only
one showing grey text and so that checks 13 to 17 can be read against everyone
else's.

The cost is recorded rather than hidden: **blocks 13 to 18 now include work the
default avoids**, and VS Code's large-file numbers are not comparable with the
first recording's. Nothing else about VS Code is configured — the sign-in modal,
the theme picker and the agents page all still appear in block 1.
