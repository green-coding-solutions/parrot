# Apache OpenOffice Writer — landmarks

Every number here was read off a running container brought up through
[`usage_scenario.yml`](usage_scenario.yml)'s own setup-commands, at
`RESOLUTION=1440x900`, with the document window pinned to 1440x900 at 0,0 and
undecorated. Rebuild that state with:

```bash
bash applications/wordprocessors/common/setup-container.sh openoffice --measure
```

Read [`../libreoffice/MEASUREMENTS.md`](../libreoffice/MEASUREMENTS.md) as well —
several of its findings are properties of the harness rather than of
LibreOffice, and they all apply here.

**All 18 blocks measured, recorded and replay-verified**: 18 PASS / 0 FAIL,
worst RMSE **0.0081**, no identical consecutive checkpoints, ground truth PASS.
Fifteen of the eighteen checkpoints replay at RMSE exactly 0; the worst is block
6 (Zoom) at 0.0081, then block 1 (Load app) at 0.0041.

`tools/check_blocks.py` reports the same 18 blocks in the same order as
LibreOffice. AOO is slower on almost every block — 558 s against LibreOffice's
445 s over the same script, with the biggest gaps on the long cursor jumps
(`Jump to end` 23.3 s against 11.3 s) and `Insert image` (47.8 s against 29.0 s).

A full manual pass through the blocks also passes `check-result.sh`:

```text
ok   Shearwater x120 (want 120)          ok   pictures x13 (want 13)
ok   Cormorant x0 (want 0)               ok   tables x4 (want 4)
ok   typed: The kestrel circled abov...  ok   table cell Alpha / Beta / Gamma
ok   typed: Three technicians logge...   ok   paragraphs starting a new page x13
ok   typed: Nothing in the record e...   ok   pdf 100 pages, 1787 KiB (want 100)
ok   typed block carries a style (Heading_20_1)
RESULT PASS
```

Findings that cost a measuring pass each:

| | |
| --- | --- |
| **The pin rule matches a res_name the settled window does not report** | `VCLSalFrame.DocumentWindow` at map time, `VCLSalFrame` once settled. The inverse of the LibreOffice case, and it fails just as silently |
| **ODF Version Conflict** | the document declares ODF 1.3, AOO implements 1.2, so opening it raises a modal whose default button runs an online update check |
| **Ctrl+H is unbound** | AOO reaches Find *and* Replace through `Ctrl+F`. `Ctrl+H` does nothing whatsoever, silently |
| **One Escape does not leave the menu system** | it closes the dropdown and leaves the menu *bar* live, so the next `Ctrl+F` is read as the `F` accelerator and opens the File menu |
| **Context toolbars are separate floating X windows** | and `import -window` renders whatever they overlap as solid black — the exact signature `AGENTS.md` says to treat as a missed click |
| **Ctrl+End stops at the end of a table** | same as LibreOffice, so the page break needs two of them |
| **Document Recovery** | as in LibreOffice — and, unlike LibreOffice, no profile key turns it off |

---

## Startup state

`soffice -writer`, so the scenario opens the document itself in block 2 the way
`script.md` says. One window, and only one:

```text
[Untitled 1 - OpenOffice Writer]   X=0 Y=0 WIDTH=1440 HEIGHT=900
                                   WM_CLASS "VCLSalFrame", "OpenOffice 4.1.16"
                                   no WM_WINDOW_ROLE, no WM_TRANSIENT_FOR
```

Nothing has to be dismissed once [`install.sh`](install.sh)'s profile is in
place. The Properties **sidebar is open by default** down the right-hand side
(x≈1180–1400 plus a tab strip to 1435); that is what a user gets, so it is left
alone.

`xdotool search --onlyvisible --class openoffice` matches on the res_class
`OpenOffice 4.1.16` and returns exactly the document window, which is what
`record-session.sh` passes as `--windowclass`.

### Window pinning

`pin-windows.sh VCLSalFrame.DocumentWindow 1440 900`.

| fluxbox `[app]` pattern | result |
| --- | --- |
| `(name=VCLSalFrame.DocumentWindow)` | **pinned** — 0,0 1440x900, decorations gone |
| `(name=VCLSalFrame)` | no match — 260,166 920x630 |
| `(class=OpenOffice)` | no match — 260,166 920x630 |

This is the LibreOffice trap in reverse, and worse. There the res_name was
stable and the res_class was filled in late; here the **res_name itself
changes**: the window maps as `VCLSalFrame.DocumentWindow` and by the time
`xprop` can be pointed at it, it reports `VCLSalFrame`. So the property you read
off the settled window is precisely the one that does not work, and the one that
does work cannot be observed after the fact at all — it was found by trying the
value AOO reports *before* fluxbox has repositioned anything.

An unmatched rule is invisible: no error, just a 920x630 window and reference
screenshots at the wrong size. Always read the geometry back.

Dialogs are safe under this rule. They set `WM_TRANSIENT_FOR`, so fluxbox
centres them on the parent whatever `[Position]` says, and they are not resized:
`Find & Replace` stays 390x252 with the full-screen rule active.

### Document Recovery, and what does not turn it off

Kill soffice rather than quitting it — which is what happens between measuring
passes — and the next start opens `OpenOffice Document Recovery` (566x387,
`Untitled 1` listed as "Not recovered yet") instead of the document.

Both obvious keys were seeded, and both were verified present in the profile AOO
rewrote:

```text
/org.openoffice.Office.Recovery/RecoveryInfo  Enabled = false
/org.openoffice.Office.Recovery/AutoSave      Enabled = false
```

The dialog appeared anyway. `Recovery/AutoSave/Enabled` is the autosave *timer*;
session tracking is separate, and AOO writes an
`/org.openoffice.Office.Recovery/RecoveryList` node for every open document
regardless of that flag. The dialog is driven by that list being non-empty at
startup, and there is no seedable key that suppresses it.

**It cannot fire in a benchmark run** — `install.sh` seeds a fresh profile with
an empty `RecoveryList` and the app is launched exactly once — which is why this
is documented rather than worked around. It fires on nearly every measuring
restart, where `install.sh --profile-only` is the reset.

### fbsetbg

As in LibreOffice: `--measure` installs `x11-utils` for `xprop`, which pulls in
`xmessage`, which fluxbox's `fbsetbg` then calls to report that it cannot set the
wallpaper — leaving a dialog on screen for the whole session. `setup-container.sh
--measure` deletes `/usr/bin/xmessage` straight afterwards so the measuring
screen matches the benchmark screen.

---

## Chrome

```text
menu bar  y=9    File 15  Edit 45  View 78  Insert 116  Format 160
                 Table 204  Tools 242  Window 287  Help 330
formatting toolbar  y=59   style box 105,59   font name 250,59   size box 362,59
status bar          y=890  "Page N / M" at the left, modified flag "*" at 817,
                           zoom percentage at 1424
```

**Menus are drawn inside the main window**, not as their own X windows — they
never appear in a window list, and they cannot become a reference screenshot the
way AbiWord's do. Clicking entries works.

---

## Blocks

### 1. Load app

`soffice -writer` to first paint. Warm in this container it is a few seconds;
cold it is the figure that matters, and 45 s is used, the same as LibreOffice.

Nothing to dismiss.

### 2. Open document — Ctrl+O

AOO uses **its own file picker**, not GTK's:

```text
[Open]  X=447 Y=330 WIDTH=546 HEIGHT=308
  File name field   715,512   (has focus when the dialog opens)
  Open   930,512    Cancel 930,540    Help 930,571
```

The filename field has focus, so nothing has to be clicked: type
`/tmp/parrot-report.odt` and `Return`. About 45 s to render page 1.

The empty `Untitled 1` window is **reused**, not added to — the same X window id
is retitled `parrot-report.odt - OpenOffice Writer`. A window list taken during
the swap briefly shows both titles at 1440x900; afterwards there is exactly one
window.

Ground truth, off the status bar: **`Page 1 / 98`**, the same pagination
LibreOffice gives. (AbiWord gives 97.) The font box reads `Liberation Sans` and
the style box `Title`, which confirms `fonts-liberation` took and the document is
not being rendered in a substitute face.

AOO's status bar carries **no word count**, so the continuous ground truth
available during a run is the page number and the modified flag, not the
selection size LibreOffice offers.

#### ODF Version Conflict

The document declares `office:version="1.3"`; AOO 4.1 implements ODF 1.2. Opening
it therefore raises a modal in the middle of this block:

```text
[ODF Version Conflict]  X=507 Y=392 WIDTH=425 HEIGHT=159
  "This document uses an unsupported version of the Open Document Format.
   Some features may not be displayed correctly.
   Click 'Update Now' to run online update and see if there is a new
   version of OpenOffice available."
  Update Now... 768,507   (the DEFAULT button)   Later 870,507
```

The default button runs a **network** update check. That is not something to
leave to a click landing correctly inside a measured block, so it is turned off
in the profile instead:

```text
/org.openoffice.Office.Common/Load  ShowOfficeUpdateDialog = false
```

which was verified to remove the dialog entirely. `AutoCheckEnabled` under
`/org.openoffice.Office.Jobs/Jobs['UpdateCheck']/Arguments` is set false for the
same reason — nothing in a run should reach the network on a schedule derived
from the wall clock.

The shipped document was **not** changed to ODF 1.2 to avoid this. LibreOffice is
recorded and verified against those exact bytes, the digest is published in the
group README, and the premise of the group is one byte-identical document. That
AOO cannot read current ODF without complaining is a true fact about a suite
whose last feature release was 2014, and it belongs in the results rather than
being edited out of the input.

### 3. Page through — Page Down x10

`Page 7 / 98`. LibreOffice reaches "pages 6 and 7 of 98" with the same ten
presses — it spans two pages at 100 %, AOO shows one.

### 4. Jump to end — Ctrl+End

`Page 98 / 98`. Needs about 20 s to settle.

### 5. Jump to start — Ctrl+Home

`Page 1 / 98`.

### 6. Zoom

**Double-click the zoom percentage in the status bar at 1424,890.** That opens
`Zoom & View Layout` directly, exactly as in LibreOffice:

```text
[Zoom & View Layout]  X=484 Y=381 WIDTH=472 HEIGHT=182
  radio  Optimal              513,388
  radio  Fit width and height 513,409
  radio  Fit width            513,430
  radio  100 %                513,451
  radio  Variable             513,474    field 678,475
  OK 682,519    Cancel 786,519    Help 894,519
```

150 % is Variable → triple-click the field → `150%` → OK. 100 % is the radio at
513,451 → OK. The dialog came up at the identical position both times, and the
status bar read `150 %` then `100 %`.

### 7. Find word — Ctrl+F

`Ctrl+F` opens the **full Find & Replace dialog**. AOO has no find toolbar; the
`Find` box in the standard toolbar is a separate control and is not what the
shortcut reaches.

```text
[Find & Replace]  X=525 Y=346 WIDTH=390 HEIGHT=252
  Search for field    660,363   (has focus when the dialog opens)
  Replace with field  660,440
  Find 854,349    Find All 854,377
  Replace 854,425    Replace All 854,453
  Match case 554,494    Whole words only 554,515
  More Options 600,554    Help 744,553    Close 854,553
```

Type `Cormorant`, then click `Find` three times. `Find` and `Find All` are greyed
out until the field has text in it.

After the third: **`Page 3 / 98`**, with `Cormorant` selected and highlighted in
"The provisional conduit downstream of Cormorant was cleaned and refitted."
LibreOffice lands on page 3 of 98 too, which is a free cross-check that both apps
stepped through the same three matches.

`Escape` closes the dialog and leaves the match selected.

### 8. Replace all — Ctrl+F again

**`Ctrl+H` does nothing at all.** It is not bound in AOO 4.1: `Edit > Find &
Replace...` reads `Ctrl+F`, and that one dialog is both. `Ctrl+H` produces no
dialog, no message and no error — a clean silent no-op, and one that a driver
copied from LibreOffice walks straight into.

Reopening with `Ctrl+F` brings the dialog back at the identical position with
`Cormorant` still in the Search field **and selected**, so typing overwrites it.
Type it in full anyway rather than depending on that.

Then click the `Replace with` field at 660,440, type `Shearwater`, and click
**`Replace All` at 854,453** — 28 px below `Replace` at 854,425, so the click has
to be accurate.

```text
-> [OpenOffice 4.1.16 ]  X=615 Y=433 WIDTH=210 HEIGHT=78
   "Search key replaced 120 times."      OK 719,471
```

That count is itself ground truth: 120 is what
[`generate_document.py`](../generate_document.py) puts in the document, so any
other number means a different document or a different anchor. Afterwards the
status bar reads `Page 98 / 98` with the modified flag `*` set.

Dismiss with OK at 719,471, then `Close` at 854,553. The message box is a
**separate X window** carrying the application's own WM_CLASS, so no checkpoint
may be taken while it is up.

### One Escape is not enough to leave a menu

Found while recovering from the `Ctrl+H` no-op. `Escape` inside an open menu
closes the dropdown but leaves the **menu bar** live, and the menu bar consumes
plain letters as accelerators. The next `Ctrl+F` was therefore read as `F` and
opened the File menu — a second wrong window, from a keystroke that had nothing
to do with menus.

Any block that opens a menu and then abandons it needs **two** Escapes. This is
the same shape as the email group's "with a menu open, the menu bar is live".

---

### 9. Type paragraph

`Ctrl+End` — which needs about 12 s from page 98 — then **`Return` before
typing**, so the block is its own paragraph rather than being glued onto the end
of the last existing one. Then the three lines, one keystroke at a time.

Ends on `Page 98 / 98`. Autocorrect is on and rewrites none of it, which is what
the text was built for.

### 10. Bold a line — Shift+Home, Ctrl+B

The third line goes bold. AOO's status bar has no selection word count, so
unlike LibreOffice there is no "9 words, 53 characters" to confirm the selection
with — the screenshot is the check here, and `check-result.sh` is the real one.

### 11. Resize the text — font size box at 362,59

Triple-click, type `18`, `Return`. The box and the sidebar both read 18.

Focus returns to the document afterwards, but **the selection is still live** —
exactly as in LibreOffice. A printable character sent next would replace the
whole line. Block 12 only touches the style box, so it is safe here.

### 12. Apply heading — style box at 105,59

Triple-click, type `Heading 1`, `Return`. Ends with **`Outline Numbering : Level
1`** in the status bar (LibreOffice says `Heading Numbering : Level 1` for the
same state), the style box reading `Heading 1`, and the font switched to
Liberation Sans 22.

This overrides the 18 pt from block 11, identically to every other app in the
group, which is what `script.md` asks for.

### 13. Insert image

`Ctrl+End`, `Return`, then the menu — **Picture is a submenu**, unlike
LibreOffice's single `Insert > Image`:

```text
Insert menu     116,9
  Picture       152,477   -> submenu
    From File...  300,477
                          -> [Insert picture] X=447 Y=330 WIDTH=756 HEIGHT=308
                             File name field 715,512 (has focus)
                             Open 930,512   Cancel 930,540
```

Type `/tmp/parrot.png` and `Return`. Afterwards `Page 99 / 99`.

The Insert menu also shows `Table... Ctrl+F12` at 152,435, which is block 14's
route, and confirms AOO uses the same accelerator LibreOffice does.

#### The block must end with Escape

Inserting the image leaves it selected, and that raises a **floating Picture
toolbar as its own X window** — `[] X=0 Y=44 WIDTH=387 HEIGHT=51`, carrying the
application's own `WM_CLASS`, drawn over the menu bar.

It does not become the captured window: it is created later than the document
window, so it sorts *after* it in `xdotool search --onlyvisible --class
openoffice` and `head -n1` still returns the document. What it does instead is
worse and quieter. `import -window` on the document window returns everything the
toolbar covers as **solid black**, so the reference screenshot for this block
would be the whole menu bar replaced by a black rectangle — the signature
`AGENTS.md` teaches you to read as a click that missed.

`Escape` deselects the image, the toolbar goes, and the capture is clean. Checked
by capturing the document window both ways rather than by reasoning about it.

### 14. Insert table

```text
Ctrl+End, Return, Ctrl+F12   -> [Insert Table] X=447 Y=337 WIDTH=546 HEIGHT=270
  Name field   703,334   (reads "Table4" - the document ships 3 tables)
  Columns      570,377   (defaults to 2, NOT to LibreOffice's default)
  Rows         570,402   (defaults to 2)
  OK 931,335   Cancel 931,362   Help 931,395
```

Triple-click each spin field, type `3` and `4`, then OK. Then `Alpha` Tab `Beta`
Tab `Gamma`. Ends with `Table4:C1` in the status bar.

The default name `Table4` is free ground truth: it proves the document arrived
with exactly three tables.

`Ctrl+F12` only works because `pin-windows.sh` writes a fluxbox keys file with no
keyboard bindings — see the LibreOffice notes.

#### This block's checkpoint has a black rectangle in it, and that is expected

The cursor is inside the table when the block ends, which raises the **floating
Table toolbar**, `[] X=22 Y=66 WIDTH=307 HEIGHT=77`. Unlike block 13 there is
nothing to dismiss: leaving the table is block 15's job, and the script says this
block ends with `Gamma` typed into the first row.

So the captured window carries a 307x77 black rectangle over the style and font
boxes. It is deterministic — the toolbar appears with the table and stays while
the cursor is in it, and fluxbox's `CascadePlacement` puts it in the same place
for the same sequence of windows every run — so reference and replay agree and
the check passes. It is recorded here so that the next person to open
`openoffice-check-014.png` does not go looking for a bug.

Two alternatives were tried and rejected:

* **Docking it** (double-click its caption at 150,55) works, and AOO would
  persist it — but a docked context toolbar adds a third toolbar row and moves
  the whole document area down 28 px *while the run is in progress*. Trading a
  stable black rectangle for a layout that shifts under the driver is the wrong
  way round.
* **Turning the context toolbars off** in the profile would be cleanest for the
  screenshots and is a change to what the application draws, for the benefit of
  the measuring harness rather than the measurement. The group's rule is to
  leave defaults alone unless leaving them breaks a measurement, and this one
  does not.

#### The image floats over the table

AOO anchors the inserted image to its paragraph and draws it **on top of** the
table that follows, so the table is invisible on screen even though it is
present and correct in the file. LibreOffice lays the same two objects out the
other way round — `libreoffice-check-014.png` shows the table above the image.

This was worth chasing down rather than assuming: the screen said nothing had
happened. The saved file said otherwise — 4 tables named `Table1`…`Table4`,
`Alpha`/`Beta`/`Gamma` present, 13 pictures — which is the whole argument for
checking ground truth while measuring rather than after recording.

### 15. Insert page break — Ctrl+End **twice**, then Ctrl+Return

Exactly the LibreOffice finding, in the same place. The cursor is in the last
table cell after block 14, and the first `Ctrl+End` only reaches the end of the
**table**: the status bar goes `Table4:C1` → `Table4:C4` and the page count does
not move. `Ctrl+Return` there would be a silent no-op.

The second `Ctrl+End` clears the table-cell indicator from the status bar and
reaches the end of the document; the break then takes and the count goes
`Page 99 / 99` → **`Page 100 / 100`**.

### 16. Undo and redo — Ctrl+Z, Ctrl+Y

`100 / 100` → `99 / 99` → `100 / 100`. Redo is `Ctrl+Y`, confirmed off the Edit
menu, which shows `Can't Restore Ctrl+Y` when there is nothing to redo.

### 17. Save — Ctrl+S

No dialog: ODT is native, so nothing asks about keeping the format. The file goes
from 9,167,202 to about 9,939,000 bytes, the growth being the inserted PNG.

### 18. Export PDF

One level, no submenu — simpler than LibreOffice's `Export As` →
`Export as PDF...`:

```text
File menu           15,9
Export as PDF...    78,315   -> [PDF Options] X=369 Y=285 WIDTH=702 HEIGHT=373
  Range: All is already selected
  Export 879,618   Cancel 954,618   Help 1029,618
                             -> [Export]  X=447 Y=330 WIDTH=546 HEIGHT=308
  File name field 715,512, pre-filled "parrot-report", already in /tmp,
  File format already "PDF - Portable Document Format (.pdf)"
  triple-click it, type /tmp/parrot-report.pdf, Return
```

Takes about 35 s and produces a 1.79 MiB, **100-page** PDF.

The path is typed in full even though the dialog would already write the right
file, because "already in the right directory" is a property of this run rather
than of the scenario.

The whole File menu, read while recovering from the Escape finding:

```text
Open... Ctrl+O 55   Save Ctrl+S 163   Save As... Ctrl+Shift+S 187
Export... 291       Export as PDF... 315   Print... Ctrl+P 491
```

#### Block 18's screenshot carries no information

As in LibreOffice: exporting a PDF does not change the document view, so this
block's screenshot cannot tell a successful export from nothing happening.
`check-result.sh` is what covers it, by asserting the PDF exists with 100 pages.

`openoffice-check-018.png` is not *byte*-identical to `017` the way
`libreoffice-check-018.png` is, but the difference is 412 pixels out of
1,296,000 — 0.03 % of the image, RMSE about 0.004 — and it is the blinking text
caret at x=255..256 plus a handful of sidebar pixels. So the duplicate-screenshot
detector in `verify-app.sh` stays quiet here while the block is just as
uninformative as LibreOffice's. Worth knowing in both directions: a *missing*
duplicate warning is not evidence that a block did something.

### There is no "close app" block

The script ends at Export PDF, 18 blocks, for the reason given in the group
README: a checkpoint is a screenshot of the application window, so a block whose
action destroys that window has nothing to photograph.

---

## Ground truth

The status bar is the cheap continuous check — `Page N / M`, the modified flag,
and the table cell reference. It is thinner than LibreOffice's, which also
carries a word count and a selection size, so blocks 7, 10 and 11 have no
numeric confirmation here and rest on `check-result.sh` instead.

What it did catch: the swallowed first `Ctrl+End` in block 15 (`Table4:C4`, page
count unchanged), the replacement count in block 8, and `Table4` as the default
table name in block 14.
