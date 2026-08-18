# PyCharm 2025.3 — measured landmarks

PyCharm shares IntelliJ IDEA's platform, so most of
[`../intellij/MEASUREMENTS.md`](../intellij/MEASUREMENTS.md) applies unchanged
and is not repeated here. This file records only what differs.

It is in the comparison *alongside* IntelliJ on purpose. The two are the same
editor with different language support: IDEA's free tier has no Python plugin
and treats `.py` as plain text, while PyCharm indexes, inspects and completes
it. Whatever that costs shows up as the difference between two otherwise
identical rows in the block table.

## Same as IntelliJ

| | |
| - | - |
| Startup dialogs | user agreement → data sharing → project trust, at **the same coordinates**: 42,831 · 1379,871 · 1163,871 · 1076,865 |
| Window matching | empty `windowclass` + `windowtitle=project`, for the same 1442x927 "Content window" reason |
| Tab close button | **813,63** |
| Replace-bar "Replace All" | 996,135 |
| Undo counts | 2 for the duplicate, 1 for the replace-all |
| Comment indentation | column 0 — PyCharm pulls a Python line comment out to the margin, as IDEA does |
| Autosave | yes — `src/component_library.py` is written to disk without being asked |

`WM_CLASS` is `("jetbrains-pycharm", "jetbrains-pycharm")`.

## What differs

**A fifth thing on screen at startup.** Where IntelliJ settles with one balloon,
PyCharm settles with two:

```text
Embedded Browser is suspended
The system restricts the embedded browser from running with the sandbox
enabled.  A corresponding...            Disable Sandbox   Learn more...

Python 3.12 has been configured as a project interpreter
Configure a Python interpreter...
```

The status bar reads `Python 3.12`, and the project tree shows Python icons on
the `.py` files where IDEA shows plain-text ones.

**Longer settles.** PyCharm indexes the 10 MB module with real Python support,
so the large-file blocks are given more room than IntelliJ's: 35 s after opening
it against IntelliJ's 28, and 12 s after the jump against 10.

**The "Replace All" button had to be re-measured, not inherited.** It sits to the
right of the match counter and therefore moves with its width: with the fields
empty the counter reads "0 results" and the button is at x=974; with `tax_rate`
in the search field it reads "1/4" and the button is at x=996. It has to be
measured in the state the driver actually clicks in — which happens to put
PyCharm and IntelliJ at the same place, but for a reason rather than by
inheritance.

## Result

18/18 checks on replay in a fresh container, worst RMSE **0.078** — the same
order as IntelliJ's 0.083 and comfortably inside the 0.2 threshold. Ground truth
OK. GMT: `MEASUREMENT SUCCESSFULLY COMPLETED`, 18 PASS, 0 FAIL.

## The Trial tab

PyCharm 2025.3 ships as one distribution with a licence trial and opens a
**Trial** tab — an embedded JCEF browser — in the editor area some time after the
project does. When it loads it takes focus, and if that lands while a popup is
open the popup is dismissed under it. IntelliJ, which is the same platform and
the same build number, lost a whole recording to exactly that: the tab arrived
during block 2, killed the Go to File popup mid-type, and the file was never
opened. See [../intellij/MEASUREMENTS.md](../intellij/MEASUREMENTS.md).

Block 1 closes it with a middle click at `700,63`. Every tab coordinate in this
file is measured with it already closed, which is why block 12's ✕ is at 813 and
not 898.

## It cannot keep up with the keyboard

Block 17 is driven at **120 ms a character** here against the group's 45 ms, and
with a full second between lines. That is the slowest cadence that was needed
and the fastest that works: at 45 ms the 2025.3 platform either stops six lines
in, or takes every character and drops the `Return`s so the lines weld together.
Both failures leave a file with the right line count.

**That cell of the results table is therefore not comparable with the other
editors'** — it contains a rate chosen for the IDE rather than by it. What is
comparable is that every other editor in the group takes 45 ms/char into the
same 337,537-line file without losing a keystroke, and that Android Studio, on
the older 251 platform, is one of them.

## Blocks 14 and 17 click into the editor first

Without it neither block does anything at all — `Ctrl+G`'s popup opens without
keyboard focus, and typed characters are dropped while `Return` still arrives.
The cause is the checkpoint immediately before them, and it is a property of the
harness rather than of this editor. See [../common/FOCUS.md](../common/FOCUS.md).
