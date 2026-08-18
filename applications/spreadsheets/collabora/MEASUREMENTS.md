# Collabora Office — measured, then dropped from the group

**Status: SKIPPED. Not recorded.**

**No modal dialog opens.** Not the Sort dialog, not Format Cells. The ribbon
works, the grid works, the keyboard works, autofilter is a direct action — but
every step of the script that needs a dialog cannot be driven, and three of the
eighteen blocks need one:

| block | needs |
| - | --- |
| 7 Sort | the Sort dialog, to choose the Reading column |
| 14 Format numbers | Format Cells, to set two decimals |
| 18 Export PDF | the PDF options dialog |

Collabora 26.04.2.4-2 (Flathub `com.collaboraoffice.Office`, OSTree commit
`54dc072b…`), `org.kde.Platform//6.10`, Ubuntu 24.04 container, 1440x900.

## The blocker

```text
Data ▸ Sort ▾ ▸ Sort...      waited 20 s, then 45 s more   -> nothing
same, on a 3-cell selection  waited 25 s                   -> nothing
Ctrl+1 (Format Cells)        waited 20 s                   -> nothing
```

Nothing appears in the document window, **no second X window is created**
(`xdotool search --onlyvisible` returns exactly one window throughout), and
nothing is logged. The application stays fully responsive the whole time — after
each attempt a click still selects a cell, the Name Box still updates, `Ctrl+End`
still works.

The small-selection test is the one that settles it: at 20,001 rows a slow
dialog would have been a plausible explanation, and at three cells it is not.

Collabora's dialogs are **JSDialogs** — LibreOffice dialogs serialised to JSON
and re-drawn by the web UI, not real windows. Something in that path does not
work in this container. The most likely candidate is in the log and is not an
error the application treats as fatal:

```text
ERROR:context_group.cc(151)] ContextResult::kFatalFailure: WebGL2 blocklisted
ERROR:bus.cc(408)] Failed to connect to the bus: /run/dbus/system_bus_socket
Call to org.freedesktop.portal.Settings.ReadAll failed  (no portal)
```

This was **not** chased further. The word processor group drove Collabora
through all eighteen of *its* blocks in the same harness and the same container
image, so whatever this is, it is specific to the spreadsheet component's
dialogs rather than to Collabora or to the container — and finding out which
would be a debugging project, not a measurement.

## What works, and is worth keeping

Everything up to block 6 was measured and correct, and the values match the
other entrants exactly.

### Two strings for one window, again

```text
WM_CLASS(STRING) = "coda-qt", "Collabora Office"
```

* fluxbox matches **`res_name`** → `pin-windows.sh coda-qt 1440 900` ✅
* xdotool matches **`res_class`** → `xdotool search --class collabora` ✅

**`xdotool search --class coda-qt` returns nothing**, which cost a capture here
before it was spotted. Same shape as Apache OpenOffice's
`VCLSalFrame.DocumentWindow` / `OpenOffice 4.1.16` split. Read back after
pinning: `X=0 Y=0 WIDTH=1440 HEIGHT=900`.

Two other X windows exist and neither is the application: a 3x3 `Qt Selection
Owner for coda-qt` and a 1x1 `Collabora Office`. `--onlyvisible` filters both.

### Launching it

```bash
flatpak-session flatpak run com.collaboraoffice.Office
```

**Not `--calc`.** The `--calc` switch tries to create a new document from a
template and dies before any window appears:

```text
ERR  Failed to copy template from /app/share/coolwsd/browser/dist/templates/Spreadsheet.ods
     to /home/parrot/Documents/Spreadsheet.ods|WebView.cpp:879
ERR  Failed to create new document|DBusService.cpp:89
```

Same cause the word processor group documented for `--writer`: flatpak resolves
`xdg-documents` through `~/.config/user-dirs.dirs`, this image has no
`xdg-user-dirs`, so the binding is **skipped silently** and `$HOME/Documents`
does not exist inside the sandbox. Creating the directory is not enough on its
own; `XDG_DOCUMENTS_DIR` has to be written too.

### Block 1 ends on the start screen

As in the word processor group. Collabora opens a purple start screen with a
left rail — `Home 79,110`, `New 79,207`, `Open 79,300` — and a template gallery,
not a grid. That is a documented deviation from `script.md` and it is the honest
one: the start screen *is* this application's launch state.

### Block 2 — open, then switch out of Viewing mode

`Open` at `79,300` raises the Qt fallback `Open File` dialog (632x412 at
394,226) — this one *does* appear, because it is a real Qt window rather than a
JSDialog, which is itself a useful datum about where the failure is.

```text
File name field   708,562     click, Ctrl+A, type the path, Return
```

About 100 s to open — the slowest in the group by a wide margin.

**It opens in Viewing mode**, with only File / Edit / View / Help and no ribbon:

```text
mode selector arrow   1421,17
"Editing Mode"        1381,73
```

The switch belongs to block 2, not block 3, for the reason the word processor
group gives: block 2's job is to leave the document usable.

### Fixed landmarks, Editing mode

| | |
| - | - |
| Ribbon tabs, y=17 | File 98, Home 163, Insert 236, Page Layout 331, Formulas 439, Data 519, Review 593, Format 675, View 748, Help 812 |
| Name Box | `55,138` — **appends**, needs a TRIPLE-click |
| Sheet tabs, y=850 | Readings 231, Sites 305, Summary 377 |
| Grid | row 1 at y≈186 |
| Status bar, y=885 | `Sheet n of 3 | Selected: … | Average: …; Sum: …` |

The Name Box joins Gnumeric and Apache OpenOffice: a single click and a typed
address gave `A381A1:H20001`. Triple-clicked, the status bar confirms

```text
Selected: 20,001 rows, 8 columns   Sum: 998310608.349896
```

— the same figure to the last digit as Gnumeric, AOO and LibreOffice.

### Block 3 — Ctrl+End → H20001

Correct, and about 25 s.

### Block 4 — Freeze works, but its popup does not close

View `748,17` → **Freeze** `185,62` opens a panel with *Freeze Rows and
Columns* `272,169`, *Freeze First Column*, *Freeze First Row*.

The freeze **does** apply — paging down afterwards keeps row 1 pinned while the
body shows rows 345+ — but the panel **stays on screen after activating**, and
it swallows every keystroke while it is up: ten `Page Down`s sent with it open
moved the cursor nowhere at all. `Escape` closes it.

That is the same web-view input problem the word processor group warns about,
and here it is worse than a missed click: the click *worked* and the UI did not
say so, so the natural response is to click again.

### Block 5 — Page Down ×10 → A381

38 rows a press.

### Block 6 — sheet tabs work

`305,850` (Sites), `377,850` (Summary), `231,850` (Readings).

## If this app is ever brought back

1. Find out why JSDialogs do not appear. Start with `WebGL2 blocklisted` and
   with running the container with a GPU or a different software-rendering
   setting; the word processor component works in the same image, so compare the
   two rather than debugging this one alone.
2. Blocks 1–6 are measured and in this file. Blocks 7, 14 and 18 are the ones
   that need dialogs; 8–13 and 15–17 are unknown.
3. Note it **autosaves**, so the saved file is not by itself evidence that block
   17 ran — `check-result.sh` asks whether the work was done, not which keystroke
   did it, so that does not weaken the ground truth.
