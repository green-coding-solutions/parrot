# Calligra Sheets — measured, then dropped from the group

**Status: SKIPPED. Not recorded, and it should not be recorded as the script
stands.**

Calligra Sheets **has no freeze-panes feature**. Block 4 — *"freeze the top row
so the column headings stay on screen while scrolling"* — is not something the
application can do, and `check-result.sh` asserts the frozen split in the saved
file.

Everything else that was checked works, including the two things the group
README predicted might not, so this is a single missing feature rather than a
poor fit. If block 4 is ever made optional, Calligra Sheets goes back in.

Calligra 26.04.3 (Flathub `org.kde.calligra`, Qt 6, `org.kde.Platform//6.10`),
Ubuntu 24.04 container, 1440x900.

```bash
bash applications/spreadsheets/common/setup-container.sh calligra --measure
docker exec -e DISPLAY=:99 window-container \
    flatpak-session flatpak run --command=calligrasheets org.kde.calligra
```

## No freeze, established from the action list rather than from the menus

Menus checked, in full: **View** (New View, Page Outline, Zoom Out, Zoom In,
100% — that is the whole menu), **Format**, **Format ▸ Sheet** (Hide Sheet, Show
Sheet, Sheet Properties), **Tools**, **Settings**. Nothing.

That is an argument from absence, so it was settled the other way too — with
**Settings ▸ Configure Keyboard Shortcuts**, which lists *every action the
application has* whether or not it is bound or in a menu:

| searched | matches |
| --- | --- |
| `freeze` | **none** |
| `pane` | **none** |
| `split` | `Split Cells` — the merge-cells inverse, not panes |
| `fix` | `Permute fixation` (F4) — absolute/relative references in formulas |
| `lock` | none |
| `filter` | `Auto-Filter` ✅ |
| `chart` | `Chart editing` — the shape tool, see below |
| `pdf` | `Export as PDF...` ✅ |

Five spellings of the feature, zero actions. This is the cheapest decisive check
in the whole group and it is worth doing first on any new entrant: the shortcut
editor is ground truth about what an application can do, where a menu walk is
ground truth only about where you have looked.

### Why one missing block ends the run

`check-result.sh` asserts `Readings carries a frozen split
(settings.xml VerticalSplitMode=2)`. Skipping block 4 fails that assertion, and
dropping the block leaves a hole in the block table — at which point
`tools/check_blocks.py` stops reporting *"all files define the same blocks in
the same order"*, which is the check that makes the timing columns comparable at
all.

Making block 4 optional is a change to what the group measures, so it is not
mine to make. Note it would also let **FreeOffice PlanMaker** back in only if the
ODS-write problem were solved separately — the two blockers are unrelated.

## What was confirmed before the blocker

### Launching it, and the two-window trap

The Flatpak entrants do **not** start with a bare `flatpak run`. As root, bwrap
takes its privileged path and dies:

```text
bwrap: Creating new namespace failed: Operation not permitted
```

The startcommand is `flatpak-session flatpak run --command=calligrasheets
org.kde.calligra`, which creates the buses and drops to uid 1001 so bwrap takes
its unprivileged path. This is the same wrapper the word processor group uses;
`error: Could not connect: No such file or directory` from a bare `flatpak run`
is the same problem wearing a different message.

**Three X windows exist and only one is the application:**

```text
6291461  Qt Selection Owner for calligrasheets   3x3     no WM_CLASS
6291465  Calligra Sheets                         1x1     no WM_CLASS
6291463  Calligra Sheets    1440x900 at 0,0   WM_CLASS "calligrasheets","calligrasheets"
                                              WM_WINDOW_ROLE "MainWindow#1"
```

Two of them are named `Calligra Sheets`, so a title match returns the wrong one
and a 1x1 capture. `xdotool search --onlyvisible --class calligrasheets` returns
exactly the real window — the `--onlyvisible` is doing the work, because the 1x1
is never mapped. `pin-windows.sh calligrasheets 1440 900` matches and pins;
read back as `X=0 Y=0 WIDTH=1440 HEIGHT=900`.

### The startup template chooser

Calligra Sheets opens on a template gallery (General ▸ Student ID Card / **Blank
Worksheet**), not on a grid. **Use This Template** at `1370,882` with Blank
Worksheet already selected. Same shape as Calligra Words'. About 70 s from
launch to the gallery, which is the slowest start in the group by a wide margin.

Portal warnings on startup are expected and harmless — there is no
`org.freedesktop.portal.Desktop` in the container, so Qt falls back to its own
file dialog, which is what makes block 2 typeable:

```text
Call to org.freedesktop.portal.Settings.ReadAll failed
  QDBusError("org.freedesktop.DBus.Error.ServiceUnknown", ...)
```

### Fixed landmarks

| | |
| - | - |
| Menu bar, y=9 | File 20, Edit 56, View 96, Go 133, Insert 174, Format 227, Data 277, Tools 320, Settings 375 |
| Name Box | `40,80` |
| Sheet tabs, y=843 | Readings 113, Sites 202, Summary 292 |
| Grid | row 1 at y≈131 |
| Status bar | `Sum:` at bottom left, y≈864 |
| Cell formatting docker | open down the right from x≈1110 |

### The blocks that were reached

* **2. Open workbook.** `Ctrl+O` → Qt's own `Open Document` dialog (632x412 at
  394,226), `File name` pre-filled `Documents` **and selected**, so a typed path
  replaces it. `/tmp` is reachable because `install-flatpak.sh` grants
  `--filesystem=/tmp` — a Flatpak does not otherwise see the host `/tmp`. About
  80 s, the slowest open in the group.

* **3. Jump to end.** `Ctrl+End` lands on **I20002**, not H20001 — one row and
  one column past the last used cell, where every other entrant lands exactly on
  it. Not a failure of the block (the jump happens and the grid redraws) but the
  reference screenshot differs from the others for a real reason, so do not read
  it as a missed keystroke.

* **11. Recalculate.** Tools ▸ **Recalculate Document** `F9`; Recalculate Sheet
  is `Shift+F9`. Both present, both bound.

* **12. Filter.** `Auto-Filter` exists as an action and in Data ▸ Filter ▸.

* **14. Format numbers.** Cell Format is **`Ctrl+Alt+F`**, not `Ctrl+1` — the
  only entrant that does not answer `Ctrl+1`.

* **16. Insert chart.** The action list has `Chart editing` and no chart wizard,
  which confirms the README's prediction: charts go through the **shape tool**,
  the way images did in Calligra Words. Expect a drag-to-place step and no
  defaults dialog.

* **18. Export PDF.** `Export as PDF...` exists.

## If this app is ever brought back

1. Decide block 4 for the whole group, not for this app. Calligra Sheets cannot
   freeze, so either the block is optional and the frozen-split assertion becomes
   conditional, or Calligra stays out.
2. Everything above is measured. What is left to measure is blocks 5–10, 13, 15,
   17 and the chart's shape-tool drag.
