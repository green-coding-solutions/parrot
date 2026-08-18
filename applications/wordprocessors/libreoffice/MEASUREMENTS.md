# LibreOffice Writer — landmarks

Every number here was read off a running container brought up through
[`usage_scenario.yml`](usage_scenario.yml)'s own setup-commands, at
`RESOLUTION=1440x900`, with the document window pinned to 1440x900 at 0,0 and
undecorated. Rebuild that state with:

```bash
bash applications/wordprocessors/common/setup-container.sh libreoffice --measure
```

**All 18 blocks measured**, and a full manual pass through them passes
`check-result.sh`.

Five findings cost a measuring pass each. Four are properties of this
application, one is a property of the harness and applies to every app in the
group:

| | |
| --- | --- |
| **Ctrl+F12 never reaches the app** | fluxbox grabs Control+F1..F12 for workspace switching. Looks exactly like a crash. Fixed in `pin-windows.sh` — affects the whole group |
| **Alt+A is Find All, not Replace All** | reports a count, selects 120 words, replaces nothing |
| **Ctrl+End stops at the end of a table** | so the page break was a silent no-op, with the page count unchanged either side |
| **A selected image disables text commands** | Insert Table greys out; Escape first |
| **Document Recovery** | any unclean exit replaces the document with a recovery window on the next start |

---

## Startup state

`soffice --writer` with no file argument, so the scenario opens the document
itself in step 2 the way `script.md` says. One window, and only one:

```text
[Untitled 1 — LibreOffice Writer]        X=0 Y=0 WIDTH=1440 HEIGHT=900
```

Four things had to be turned off in the seeded profile before that was true.
Each is in [`install.sh`](install.sh) with the same reasoning:

| What appeared | What it did |
| --- | --- |
| `Tip of the Day: 1/225` | 535x215 modal, centred over the document, every start |
| "running version 24.2 for the first time" infobar | blue bar under the toolbar, pushed the document down 30 px |
| `LibreOffice 24.2 Document Recovery` | replaced the document entirely after any unclean exit |
| AutoSave | a write landing inside whichever block was running |

### Document Recovery is the one that bites

Kill Writer rather than quitting it — which is what happens between measuring
passes, and what a timed-out replay does — and the *next* start opens a recovery
window instead of the document. It reports `WM_CLASS "libreoffice",
"LibreOffice 24.2"`, a different res_class from the document window, so it is not
even caught by the pin rule: it comes up 576x352, centred, and the driver types
into nothing.

Two measuring passes were lost to this before it was understood. Recovery and the
crash reporter are now off in the profile, so the next start is identical
whatever ended the last one.

### fbsetbg is a measuring artefact, not a real one

Installing `x11-utils` for `xprop` pulls in `xmessage`. fluxbox's `fbsetbg`
cannot set the wallpaper in this image, and *if xmessage exists* it pops a
1017x107 dialog saying so, which then sits on the display for the whole session.
The stock image has no `xmessage`, so the failure is silent and the benchmark
never sees it.

`setup-container.sh --measure` deletes `/usr/bin/xmessage` right after installing
x11-utils, so the measuring screen matches the benchmark screen.

---

## Window pinning

`pin-windows.sh libreoffice 1440 900` — the res_name, and **nothing else**.

Adding the res_class that a settled window reports makes the rule match nothing,
silently:

| fluxbox `[app]` pattern | result |
| --- | --- |
| `(name=libreoffice)` | **pinned** — 0,0 1440x900, decorations gone |
| `(class=libreoffice-writer)` | no match — 0,44 1440x875 |
| `(class=libreoffice)` | no match — 0,44 1440x875 |
| `(name=libreoffice-writer)` | no match — 0,44 1440x875 |
| `(title=.*Writer)` | no match — 0,44 1440x875 |

fluxbox evaluates the rule when the window is **mapped**, and at that moment
Writer has set its res_name but not its final res_class or title — it fills those
in once it knows which module owns the document. A rule written against the
properties `xprop` shows you on a settled window therefore matches nothing.

An unmatched rule is invisible: no error, no warning, just an unpinned window and
reference screenshots taken at the wrong size. Always read the geometry back.

Writer's dialogs share the res_name, so the rule matches them too. That is safe
here for two reasons, both of which have to be re-checked for every other app in
this group:

* they set `WM_TRANSIENT_FOR`, and fluxbox centres a transient on its parent
  whatever `[Position]` says;
* they carry a program-specified maximum size, so `[Dimensions] {1440 900}` is
  clamped. `Find and Replace` stays 574x403 with the full-screen rule active.

---

## Blocks

### 1. Load app

Nothing to drive. `soffice --writer` to first paint of an empty document is
about 25 s cold in this container; 45 s was used while measuring and is the
figure to start the driver from.

### 2. Open document

Pure keyboard, no coordinates:

```sh
K ctrl+o          # -> [Open] X=376 Y=272 WIDTH=687 HEIGHT=399
T '/tmp/parrot-report.odt'
K Return          # ~35 s to render page 1
```

The filename field has focus when the dialog opens, so nothing has to be clicked.

The empty `Untitled 1` window is **replaced**, not added to — LibreOffice reuses
an unmodified blank document. After this block there is again exactly one window,
now titled `parrot-report.odt — LibreOffice Writer`.

Ground truth, off the status bar: `Page 1 of 98`, `54,607 words, 361,913
characters`. Both match [`generate_document.py`](../generate_document.py)
exactly, which is what makes the status bar usable as an assertion for the rest
of the run.

### 3. Page through — Page Down x10

`Pages 6 and 7 of 98`. Ten presses move six pages because the view spans two
pages at 100%.

### 4. Jump to end — Ctrl+End

`Page 98 of 98`.

### 5. Jump to start — Ctrl+Home

`Page 1 of 98`.

### 6. Zoom

**Double-click the zoom percentage in the status bar at 1418,889.** That opens
`Zoom & View Layout` directly:

```text
[Zoom & View Layout]  X=541 Y=381 WIDTH=357 HEIGHT=181
  radio  Optimal              568,392
  radio  Fit width and height 568,411
  radio  Fit width            568,430
  radio  100%                 568,449
  radio  Custom               568,472     field 679,472
  Help    596,512   Cancel  750,512   OK  841,512
```

Two routes that do **not** work, both tried first:

* *Hovering the View menu.* `xdotool mousemove` to the `Zoom` entry at 115,517
  leaves `Normal` highlighted at the top — the menu does not react to a warped
  pointer. The menu itself is drawn inside the main window, not as its own X
  window, so it never shows up in a window list either.
* *Alt+V, Up, Return.* `Zoom` is the last entry and `Up` should wrap onto it.
  No dialog opens.

### 7. Find word — Ctrl+F

The find toolbar appears at the foot of the document area; it is not a separate
X window. Type `Cormorant`, then `Return` three times to step through the first
three matches.

After the third: `Page 3 of 98`, `Selected: 1 word, 9 characters` — nine
characters is `Cormorant`, so the status bar confirms the match landed on the
anchor rather than somewhere plausible-looking.

`Escape` closes the bar and leaves the match selected.

### 8. Replace all — Ctrl+H

```text
[Find and Replace]  X=433 Y=270 WIDTH=574 HEIGHT=403
  Find field      754,273     (pre-filled from the find bar, and SELECTED)
  Replace field   754,368
  Find All 499,414   Find Previous 609,414   Find Next 719,414
  Replace 829,414    Replace All 938,414
  Close 949,623
```

The Find field carries `Cormorant` over from block 7 and it arrives selected, so
typing overwrites it. Type it in full anyway rather than depending on that. The
Replace field does **not** follow the Find field in the tab order — Match case
and Whole words come first — so click it at 754,368.

### Alt+A is Find All, not Replace All

The obvious mnemonic is wrong, and it fails in the worst possible way: it looks
like it worked.

```text
Alt+A    ->  infobar "Search key found 120 times."
             status  "Selected: 120 words, 1,080 characters"
             document unchanged, every Cormorant still there
```

An infobar, a plausible count, and a selection — and nothing was replaced. This
is the shape of failure `AGENTS.md` is about: a green-looking signal over an
action that did not happen. `Replace All` is the **click at 938,414**:

```text
click 938,414  ->  infobar "Search key replaced 120 times."
```

That count is itself a ground-truth check. 120 is what
[`generate_document.py`](../generate_document.py) puts in the document, so a run
that reports any other number has found a different document or a different
anchor. `1,080 characters / 120 = 9`, which is `Cormorant`, so even the Find All
misfire confirmed the anchor before it was thrown away.

Close the dialog afterwards with the button at 949,623.

---

### 9. Type paragraph

`Ctrl+End`, then **`Return` before typing**. Without it the first line is glued
onto the end of the last existing paragraph — measured, and the reason
`script.md` now says to press Enter first.

### 10. Bold a line — Shift+Home, Ctrl+B

`Selected: 9 words, 53 characters`, which is exactly the third typed line.

### 11. Resize the text — font size box at 430,60

Triple-click, type `18`, `Return`.

Focus **does** return to the document afterwards — but **the selection is still
live**. A printable character sent next replaces the whole selected line. This
was found by probing with a single `Z`, which ate the line. The block that
follows only touches the style box, so it is safe here; anything that types
after a toolbar box is not.

### 12. Apply heading — style box at 80,60

Triple-click, type `Heading 1`, `Return`. Ends with `Heading Numbering : Level 1`
in the status bar, and the box itself reads `Heading 1`.

This overrides the 18 pt from block 11. That is what the script asks for and it
happens identically in every application, so it is left alone.

### 13. Insert image

`Ctrl+End`, `Return`, then the menu:

```text
Insert menu   123,9
Image...      155,71     -> [Insert Image] X=275 Y=275 WIDTH=889 HEIGHT=393
```

Type `/tmp/parrot.png` and `Return`; the filename field has focus. Afterwards
`Page 99 of 99`, `54,632 words`.

The menu is drawn **inside** the main window, not as its own X window, so it
never appears in a window list. Clicking entries works; hovering them does not —
`xdotool mousemove` onto an entry leaves the first item highlighted.

### 14. Insert table

**`Escape` first.** The image is still selected after block 13, and while a
drawing object is selected every text-insertion command is greyed out. `Ctrl+F12`
then does nothing whatsoever — the Table menu shows `Insert Table... Ctrl+F12`
disabled along with everything else in it.

```text
Ctrl+F12      -> [Insert Table] X=479 Y=270 WIDTH=482 HEIGHT=404
  Name field     624,285   (reads "Table4" — the document ships 3 tables)
  Columns        624,312
  Rows           879,312
  Cancel 809,624    Insert 906,624
```

Then `Alpha` Tab `Beta` Tab `Gamma`. Ends with `Table4:C1` in the status bar.

The default name `Table4` is free ground truth: it proves the document arrived
with exactly three tables.

#### Ctrl+F12 is grabbed by the window manager

This one looks exactly like a crash. fluxbox's default keys file binds
`Control F1..F12` to workspace switching and grabs them at the X server, so
Writer never receives `Ctrl+F12`. The display jumps to workspace 12, which is
empty:

```text
xdotool search        -> nothing
import -window root   -> a fully transparent image
ps aux | grep soffice -> still running
```

Nothing in any log mentions it. `Ctrl+F1` brings the document back.

It would happen identically on replay, so it cannot be worked around in the
driver. `pin-windows.sh` now writes a fluxbox keys file with **no keyboard
bindings at all** — mouse bindings only. Nothing in a recording uses a
window-manager keybinding; every keystroke belongs to the application.

### 15. Insert page break — Ctrl+End **twice**, then Ctrl+Return

The cursor is in the last table cell after block 14, and in Writer the first
`Ctrl+End` only reaches the end of the **table**: the status bar still reads
`Table4:C4`, and `Ctrl+Return` there is a silent no-op. The page count is
`99 of 99` before and after, so nothing in the screenshots would show it.

The second `Ctrl+End` reaches the end of the document, and the break then takes:
`Page 100 of 100`.

### 16. Undo and redo — Ctrl+Z, Ctrl+Y

`100 of 100` → `99 of 99` → `100 of 100`.

### 17. Save — Ctrl+S

No dialog: ODT is native. The file goes from 9,167,202 to 9,941,804 bytes, the
growth being the inserted PNG.

### 18. Export PDF

```text
File menu           15,9
Export As           60,324
Export as PDF...    285,318  -> [PDF Options] X=379 Y=274 WIDTH=681 HEIGHT=395
  Range: All is already selected
  Cancel 913,619   Export 1004,619
                             -> [Export]      X=376 Y=272 WIDTH=687 HEIGHT=399
Ctrl+A, type /tmp/parrot-report.pdf, Return
```

Takes about 25 s and produces a 2.0 MB, **100-page** PDF.

`Export Directly as PDF` at 341 skips the options dialog. It is not used: seeing
the options dialog is the ordinary route and `script.md` allows either.

#### Block 18's screenshot carries no information

`libreoffice-check-018.png` is byte-identical to `check-017`. That is correct
rather than broken — exporting a PDF does not change the document view — but it
means the screenshot check for this block cannot tell a successful export from
nothing happening at all. A replay in which the export silently failed would
still report PASS on that checkpoint.

`check-result.sh` is what covers it, by asserting the PDF exists with 100 pages.
`verify-app.sh` runs that; a plain GMT run does not, so a broken export there
would show up only as a run that finished suspiciously early.

Two identical images in a row is under the threshold worth failing a recording
over — three consecutive is the signal that a run stopped doing anything — but
it is worth knowing which block is not really being checked by its picture.

### There is no "close app" block

Neither the PDF viewer nor the email client group ends its script by quitting,
and for a good reason here: the checkpoint is a screenshot of the application
window, so a block whose action removes that window has nothing left to
photograph. The script ends at Export PDF, 18 blocks.

## Ground truth

The status bar is the cheap continuous check — page number, word count, selection
size, table cell — and it caught the find landing on the anchor in block 7 and
the swallowed page break in block 15.

The real assertion is
[`common/check-result.sh`](../common/check-result.sh), which reads the files the
run left behind. Validated against a full manual pass:

```text
ok   Shearwater x120 (want 120)
ok   Cormorant x0 (want 0)
ok   typed: The kestrel circled above the reservoir befo...
ok   typed: Three technicians logged the reading and fil...
ok   typed: Nothing in the record explained the drop in ...
ok   typed block carries a style (Heading_20_1)
ok   pictures x13 (want 13)
ok   tables x4 (want 4)
ok   table cell Alpha / Beta / Gamma
ok   paragraphs starting a new page x13, from 3 break style(s)
ok   pdf 100 pages, 1966 KiB (want 100)
RESULT PASS
```

Counting `fo:break-before="page"` directly does **not** work and was the first
attempt: the shipped document defines one automatic style carrying the attribute
and references it from all twelve chapter headings, so the attribute appears
once — and Writer rewrites the automatic styles on save into some other number
again. What means something is how many paragraphs *reference* a break-carrying
style.
