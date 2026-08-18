# IntelliJ IDEA 2025.3 — measured landmarks

Everything here was read off a screenshot in a container brought up by
`common/verify-editor.sh intellij --setup`, which runs this editor's own
`usage_scenario.yml` setup-commands. Re-measure after any version bump.

IDEA runs on its **own defaults** — nothing is written to `config/options/`, no
consent is pre-accepted, no registry key is set. That is a deliberate reversal:
an earlier version of `install.sh` suppressed the agreement with
`-Djb.privacy.policy.text=<!--999.999-->`, seeded `trusted-paths.xml` and turned
off the completion popup, which produced a startup nobody who installs IDEA ever
sees and hid a real cost of using it.

## Windows

| | |
| - | - |
| Main window `WM_CLASS` | `"jetbrains-idea", "jetbrains-idea"` |
| Main window `WM_WINDOW_ROLE` | *(not set — no role discriminator available)* |
| Main window `_NET_WM_WINDOW_TYPE` | `_NET_WM_WINDOW_TYPE_NORMAL` |
| Second window | `Content window`, no window type, at -2,-46, **1442x927** |
| Pinned size | 1440x900 at 0,0 |

**The second window is the trap.** JetBrains maps a shaped "Content window" that
carries the same `WM_CLASS` as the frame and is *larger than the screen*. Both
`replay.py` and `check-image.sh` select the **largest** match, so a macro
recorded with `windowclass=jetbrains-idea` screenshots the 1442x927 helper
instead of the editor.

The fix is to match on title alone — an empty `windowclass` plus
`windowtitle=project`. IDEA titles its frame `<project> – <file>`, so the title
always contains `project` as the file changes, and the helper window is called
`Content window`, which does not. Empty is meaningful and is preserved end to end
(see "Deterministic Window Layout" in the top-level README).

## Startup: four clicks before the editor exists

| Screen | Action | At |
| ------ | ------ | -- |
| JETBRAINS USER AGREEMENT (full screen) | tick "I confirm that I have read and accept…" | 42, 831 |
| …same screen | **Continue** (disabled until the box is ticked) | 1379, 871 |
| DATA SHARING | **Don't Send** | 1163, 871 |
| Trust and Open Project 'project'? | **Trust Project** | 1076, 865 |

All four are ordinary X windows sharing the frame's `WM_CLASS`, so
`pin-windows.sh jetbrains-idea 1440 900` pins them full-screen at 0,0 too — which
is why these coordinates are stable rather than subject to fluxbox's cascade.
That is luck rather than design, and it is the one thing to re-check after an
upgrade.

## The settled load state

Project tree on the left, **two** editor tabs — `README.md`, which IDEA opens by
itself for a project that has one, and `Trial`, the licence page — plus a
persistent balloon in the bottom-right corner:

```text
Embedded Browser is suspended
The system restricts the embedded browser from running with the sandbox
enabled.  A corresponding...            Disable Sandbox   Learn more...
```

JCEF will not start sandboxed as root. The balloon **does not fade** — confirmed
still present 90 s later — so it is in every reference screenshot from block 1
onwards, identically. Left alone.

The README preview pane reads "The IDE is run under the superuser. Embedded
Browser is suspended" for the same reason.

## The scenario, step by step

| # | Step | Input |
| - | ---- | ----- |
| 1 | Load app | the four startup clicks above |
| 2 | Open file | `Ctrl+Shift+N` · `price_calculator.py` · `Return` |
| 3 | Scroll to function | 30 x wheel-down at 950,450 — **3 lines per click**, top line 91 |
| 4 | Find identifier | `Ctrl+F` · `tax_rate` → "1/4", Ln 110 Col 56 |
| 5 | Select line | `Return` · `Escape` · `Home` · `Shift+End` → 117:30 (25 chars) |
| 6 | Duplicate line | `Ctrl+C` · `End` · `Return` · `Ctrl+V` → 118:30 |
| 7 | Undo duplicate | `Ctrl+Z` **x2** |
| 8 | Replace all | `Ctrl+R` · `Ctrl+A` `tax_rate` · `Tab` · `Ctrl+A` `vat_rate` · click 996,135 |
| 9 | Undo replace | `Ctrl+Z` **x1** |
| 10 | Insert comment | `Ctrl+F` · `return subtotal + tax` · `Escape` · `Ctrl+Alt+Return` · `# benchmark complete` |
| 11 | Save file | `Ctrl+S` |
| 12 | Reopen file | click the tab's ✕ at **813,63** · `Ctrl+Shift+N` · `price_calculator.py` · `Return` |
| 13 | Open large file | `Ctrl+Shift+N` · `component_library.py` · `Return` |
| 14 | Go to line | **click the editor** · `Ctrl+G` · `120000` · `Return` |
| 15 | Page down | `Next` x10 |
| 16 | Go to start | `Ctrl+Home` |
| 17 | Type block | **click the editor** · `Ctrl+Home` · the 10 lines at **120 ms/char** |
| 18 | Global replace | `Ctrl+Shift+R` · `Ctrl+A` `LEGACY_SKU` · `Tab` · `Ctrl+A` `ARCHIVE_SKU` · `Alt+A` · `Return` |

### Four things that are not obvious

**`Ctrl+F4` closes the window, not the tab.** It is IDEA's documented "close
tab", and under fluxbox it closed the whole frame and left the IDE running with
no window at all — which looks exactly like a crash. Step 12 clicks the tab's ✕
instead.

**Replace in Files is 975 px tall on a 900 px screen.** Its buttons are below
the bottom edge and cannot be clicked, so step 18 has to reach "Replace All"
with `Alt+A`. `Return` then answers the "Replace 12 occurrences across 3 files?"
confirmation, which *is* the default button here — unlike VS Code's equivalent
modal, which never takes the input focus and has to be clicked.

**`Ctrl+A` before typing into every find or replace field.** IDEA shares its
find/replace history between the in-editor bar and the Replace in Files dialog,
pre-fills both from it, and selects the text only in the **search** field.
Without the explicit select-all, step 18's `ARCHIVE_SKU` was appended to step
8's leftover `vat_rate`, and the project-wide replace ran with a replacement
string of `vat_rateARCHIVE_SKU`, writing that into all three files.

All eighteen screenshot checks passed while it did so. The dialog looked
identical either way, and the damage was in three files no reference image
shows. Only the ground-truth diff caught it — which is the entire argument for
having one.

**Worst RMSE is ~0.083, against VS Code's ~0.025.** Still comfortably inside the
0.2 threshold, but a thinner margin, and worth watching after a version bump.

## Autosave

IDEA writes `src/component_library.py` to disk on its own — ten lines longer
than the seeded 337,537, both sentinel typed lines present — even though the
scenario
never asks it to save that buffer. VS Code does not. Neither is configured;
both are running as installed, and the ground-truth report prints which of the
two happened rather than insisting on one.

## What the network would have added

With the container still online, IDEA queries the JetBrains marketplace the first
time it opens a `.py` file and draws a **"Plugins supporting *.py files found"**
banner across the top of the editor — one row, so every line below it moves down
32 px. It appears only when the marketplace is reachable, which would make this
recording pass on a connected machine and fail on a disconnected one.

`common/go-offline.sh` runs as the last setup-command before `entrypoint.sh` for
exactly this reason. It is the only thing imposed on the editor from outside, and
it is imposed on all of them.

## The Trial tab, and the recording it destroyed

IDEA 2025.3 ships as one distribution with a licence trial, and it opens a
**Trial** tab — an embedded JCEF browser — in the editor area some time after the
project does. How long is not fixed, and when it finally loads it **takes
focus**.

One recording lost everything from block 2 onward to that. The tab arrived while
the Go to File popup was open, dismissed it mid-type, and `price_calculator.py`
was never opened at all. Checks 2 to 11 show a tab row reading `README.md |
Trial` and nothing else — eleven screenshots of an IDE that was not doing the
scenario — and every one of them passed on replay, because each was compared
against itself. What caught it was the ground-truth check:

```text
[FAIL] expected 129 lines, found 128
[FAIL] '# benchmark complete' found 0 times
```

Block 1 now closes the tab with a middle click at `700,63` once the IDE has
settled. Middle click closes a tab in IDEA, so it is one action, and once the
tab is gone it cannot steal focus again. Every tab coordinate in this file is
measured with it already closed — which is why block 12's ✕ is at 813 and not
the 898 an earlier version of this document recorded.

Android Studio has no equivalent: Google's build is free and never shows one.

## It cannot keep up with the keyboard

The other editors in this group take the ten lines of block 17 at 45 ms a
character and lose nothing. IDEA 2025.3 does not, and it fails in two different
ways depending on how it is driven — measured repeatedly, identical each time:

| Cadence | Result |
| - | - |
| 45 ms/char, 0.3 s between lines | six lines land, then it stops dead mid-seventh: `...PAGE`. Every `Return` still arrives, so the file ends with the right **line count** and three empty lines. |
| 45 ms/char, 1.5 s between lines | every character lands and the **Returns** are dropped instead: `RETRY_LIMIT = 3CACHE_SECONDS = 900` |
| 120 ms/char, 1.0 s between lines | clean |

Both failure modes leave a file whose line count is exactly right, which is the
number a human checks.

So block 17 is driven at 120 ms here, and **that cell of the results table is not
comparable with the other editors'** — it contains a rate chosen for the IDE
rather than by it. What *is* comparable, and is the actual finding, is that
everything else in the group accepts 45 ms/char into the same 337,537-line file
without dropping a keystroke. Android Studio, on the older 251 platform, is
still driven at 45 ms and is fine; the difference is the platform version, not
the vendor.

## Blocks 14 and 17 click into the editor first

Not decoration — without it neither block does anything at all. The cause is the
checkpoint immediately before them, and it is a property of the harness rather
than of this editor. See [../common/FOCUS.md](../common/FOCUS.md).
