# Android Studio 2025.1.3 "Narwhal 3 Feature Drop" — measured landmarks

Android Studio is IntelliJ IDEA with Google's Android plugins on top. The key
bindings, the in-editor find bar, the Replace in Files dialog and the shared
find/replace history are all IDEA's, so most of
[`../intellij/MEASUREMENTS.md`](../intellij/MEASUREMENTS.md) applies unchanged.
This file records what is different — which is block 1, every mouse coordinate,
and one thing that only shows up on the 10 MB file.

| | |
| - | - |
| `WM_CLASS` | `("jetbrains-studio", "jetbrains-studio")` — shared with the dialogs |
| Helper window | `Content window`, **1442x927** — larger than the 1440x900 frame |
| Frame title | `project – <file>` |
| Editor viewport | 36 lines, full width once the What's New panel is closed |
| Wheel scroll | 3 lines per click, 30 clicks → top line 99 |
| Page down | 35 lines |
| Autosave | **yes** |
| Trial tab | **none** — Google's build is free, unlike IDEA and PyCharm |
| Typing rate | 45 ms/char, the group default — the 2025.3 platform cannot take it |
| Worst RMSE on replay | **0.073** |

## The pin is a release, not the highest version that resolves

`ide-zips` serves release candidates alongside releases and nothing in the URL
says which is which. The highest version that answered a HEAD request was
2025.2.3.7 — it installs and runs perfectly well, as *"Otter 3 Feature Drop |
2025.2.3 RC 2"*. Every other editor in this group is pinned to a stable release,
so benchmarking a release candidate here would have been a difference between
the rows that had nothing to do with the editors.

The label is in the tarball and can be read without installing it:

```bash
tar -xzOf android-studio-<v>-linux.tar.gz android-studio/lib/resources.jar \
  | unzip -p /dev/stdin idea/AndroidStudioApplicationInfo.xml | grep '<version'
```

```text
2025.2.3.7  full="Otter 3 Feature Drop | {0}.{1}.{2} RC 2"   <- rejected
2025.1.3.7  full="Narwhal 3 Feature Drop | {0}.{1}.{2}"      <- this one
```

Worth re-running whenever the pin moves. The current stable line at the time of
writing is Quail (2026.1.x), which has no `ide-zips` build at all — a scan of
`2026.1.1.*` and `2026.1.3.*` returned 404 for every patch number.

## No SDK wizard, because the project is an argument

The thing that could have made Android Studio unbenchmarkable in an offline
container is its first-run Setup Wizard, which wants to download the Android SDK
before it will show you anything. It never appears here: the project directory is
passed on the command line, exactly as it is to IntelliJ and PyCharm, and Studio
opens it directly. Two dialogs stand in the way and both are answerable offline:

| | |
| - | - |
| "Help improve Android Studio" | Don't send · up within 10s of exec |
| "Trust and Open Project 'project'?" | Trust Project · up within 10s of the first click |

The IDE is pixel-stable 20 seconds after that. Block 1 is therefore two clicks,
against IntelliJ's four.

## The steps

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | Don't send · Trust Project |
| 2 | Open file | `Ctrl+Shift+N` · `price_calculator.py` · `Return` |
| 3 | Scroll to function | 30 x wheel-down at **720,450** |
| 4 | Find identifier | `Ctrl+F` · `tax_rate` → 2/4 |
| 5 | Select line | `Return` · `Escape` · `Home` · `Shift+End` |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` |
| 7 | Undo duplicate | `Ctrl+Z` **x2** |
| 8 | Replace all | `Ctrl+R` · `Ctrl+A` `tax_rate` · `Tab` · `Ctrl+A` `vat_rate` · Replace All at **806,143** |
| 9 | Undo replace | `Escape` · `Ctrl+Z` **x1** |
| 10 | Insert comment | `Ctrl+F` · `return subtotal + tax` · `Escape` · `Ctrl+Alt+Return` · text |
| 11 | Save file | `Ctrl+S` |
| 12 | Reopen file | tab ✕ at **820,60** · `Ctrl+Shift+N` · path · `Return` |
| 13 | Open large file | `Ctrl+Shift+N` · `component_library.py` · `Return` |
| 14 | Go to line | `Ctrl+G` · `120000` · `Return` |
| 15 | Page down | `Next` x10 → L120000 to L120350 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | the ten lines, each + `Return` |
| 18 | Global replace | `Ctrl+Shift+R` · `Ctrl+A` `LEGACY_SKU` · `Tab` · `Ctrl+A` `ARCHIVE_SKU` · `Alt+A` · `Return` |

## The What's New panel is closed in block 1, and that buys back the find bar

Studio opens with a **What's New in Narwhal** tool window filling the right third
of the window. The first recording kept it, on the group's "use the editor's
defaults" rule. That was the wrong call, and the reason is not cosmetic.

It left the editor about 400 px wide, and at that width the in-editor find and
replace bars have nowhere to draw their text **fields**:

```text
 v  ×  Cc  W  .*                     2/4    ↑ ↓ ▽ ⋮ ×
 ⌕     ⏎   AA          [Replace] [Replace All] [Exclude]
```

The buttons and the match counter were there. The two boxes you type into were
not — they rendered at zero width, so **nothing typed in blocks 4, 8 or 10
appeared in any reference screenshot.** In an IDE that shares one find/replace
history between the in-editor bar and the Replace in Files dialog, that is
exactly the combination that produced IntelliJ's `vat_rateARCHIVE_SKU`
corruption with all eighteen checks passing.

So block 1 now closes it: hover the tool-window header at `1377,61` — the Hide
button is only painted while the pointer is over it — and click. One recorded
click, costing real time in the measurement, rather than a setting written
behind the benchmark's back. With the panel gone:

- the find field shows `tax_rate` and the counter shows `1/4` in check 4
- both fields are legible in check 8, so the screenshot proves its own input
- the editor is full width, so the wheel, Replace All and the tab ✕ all sit
  where IntelliJ's do — `950,450`, `993,143`, `820,61`

`Ctrl+A` before each field stays anyway, because the shared history is still
shared, and [`../common/check-result.sh`](../common/check-result.sh) is still
the real verification of blocks 8, 10 and 18.

## Two more differences worth having in the table

**The 10 MB file gets a banner and no code insight.**

```text
⚠ The file size (10.01 MB) exceeds the configured limit...
```

That is IDEA's `idea.max.intellisense.filesize` cutoff. Highlighting, inspection
and indexing are switched off for the file, which is why block 13 settles faster
than the width of the file would suggest — measured pixel-stable at 40 s. The
banner is one row tall and pushes every line below it down, which is harmless
because it is in the reference image too.

**Android Studio autosaves.** The scenario types ten lines into the large file
and never asks for a save; the ground-truth check finds them on disk anyway —
337,547 lines against the seeded 337,537, both sentinel lines present. Eclipse,
VS Code, Sublime, Vim, Neovim, nano and Emacs all leave that buffer dirty. It is
a real difference and it is what makes Studio's "Save file" step cheap: by the
time `Ctrl+S` arrives there is often nothing left to write.
