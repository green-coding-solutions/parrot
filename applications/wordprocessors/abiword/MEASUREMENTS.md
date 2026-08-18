# AbiWord — landmarks

Read off a running container brought up through
[`usage_scenario.yml`](usage_scenario.yml)'s own setup-commands, at
`RESOLUTION=1440x900`, with the document window pinned to 1440x900 at 0,0 and
undecorated:

```bash
bash applications/wordprocessors/common/setup-container.sh abiword --measure
```

**All 18 blocks measured.**

Read [`../libreoffice/MEASUREMENTS.md`](../libreoffice/MEASUREMENTS.md) first —
the fluxbox key-grab finding there applies to every app in this group — and
[`../openoffice/MEASUREMENTS.md`](../openoffice/MEASUREMENTS.md) for the two
window-matching traps, which AbiWord has in a worse form.

Findings that cost a measuring pass each. Every one of them produced a plausible
screen and no error anywhere:

| | |
| --- | --- |
| **Find and Replace windows never go away** | they stay `IsViewable` after being closed and sort *ahead* of the document, so every later checkpoint would photograph a 478x254 dead window. This app needs an **empty `windowclass`** |
| **Replace All does not wrap** | it runs from the cursor to the end of the document. Started from block 7's match it replaced **118 of 120** and reported "118 replacements" as if that were the answer |
| **Ctrl+R is Align Right** | not Replace. It silently right-aligns a paragraph. Replace is `Ctrl+H` |
| **The font size combo ignores typing** | type `18`, press Return, and the box reads 18 while the text stays 12 pt. Neither `Return` nor `KP_Enter` commits it |
| **The style combo repositions** | it puts the *selected* entry under the pointer, so `Heading 1` is scrolled out of reach |
| **Save Copy will not infer PDF from the extension** | it asks "The given file extension does not match the chosen file type!" and, if answered Yes, writes an AbiWord file called `.pdf` |
| **The first Zoom dialog of a session has two geometries** | it usually comes up 178x259 at 1,45, but sometimes 162x259 at 0,0 — and the second form covers the menu bar. See [Zoom](#6-zoom); block 6 opens one and throws it away before the real sequence |

---

## Startup state

`abiword` with no file argument. One window, no dialogs, nothing to dismiss —
the cleanest start of anything in this group, and no profile seeding is needed
at all.

```text
[Untitled1]  X=0 Y=0 WIDTH=1440 HEIGHT=900
             WM_CLASS "abiword", "Abiword"   WM_WINDOW_ROLE "topLevelWindow"
```

`pin-windows.sh abiword 1440 900` matched on the first try — unlike LibreOffice
and OpenOffice, the obvious res_name is the right one.

About 20 s to first paint.

### Chrome

```text
menu bar y=12   File 19  Edit 59  View 103  Insert 154  Format 211
                Tools 266  Table 316  RDF 362  Documents 430  Help 497
style box    92,87 (entry ~5..155)   font box 270,87   size box 385,87
zoom combo   575,45
status bar   bottom left, "Page: N/M", then the font at the cursor
```

**The default zoom is `Page Width`, not 100 %.** Blocks 3–5 are therefore
measured at Page Width and blocks 7–18 at 100 %, because block 6 ends by setting
100 %.

---

## Window matching: this app needs an empty `windowclass`

This is the finding that matters most, and it is not visible until block 8.

AbiWord's Find dialog, Replace dialog and message boxes are separate X windows
carrying the application's own `WM_CLASS`. That much is ordinary — LibreOffice
and OpenOffice do it too. What AbiWord does differently is that **it never
destroys them.** After the Replace dialog has been closed and is no longer drawn
anywhere on screen:

```text
xwininfo -id <replace>   Map State: IsViewable      Corners: +0+0
xdotool search --onlyvisible --class abiword | head -n1   -> the REPLACE window
import -window <that>    -> 478x254, 2 colours, 153 bytes
```

The checkpoint capture in `timed_xmacro.py` takes `head -n1`, so from block 8
onwards **every reference screenshot would be a 478x254 picture of a dead
dialog**. The same happens to the "N replacements" message box and to the Export
File dialog.

`drive-scenario.sh`'s `CP()` size assertion would catch it — but detecting it
every time is not a fix. The fix is the one `AGENTS.md` describes:

```text
--windowclass ''
--windowtitle '^(Untitled1|[*]?Parrot Field Report)$'
```

An **empty `windowclass` is meaningful**: `helpers.normalize_app_meta` preserves
it deliberately, and every consumer skips an empty value and falls through to the
title — the capture in `timed_xmacro.py`, `_find_window` in both `replay.py` and
`record-macro.py`, and `position-window.sh` (which uses `${VAR-default}`, so an
empty-but-set value stays empty). The title is passed as an environment variable
rather than through a shell, so the regex characters survive.

The regex is anchored for a reason. Unanchored, `Parrot Field Report` also
matches `Replace - *Parrot Field Report`. It has to cover three titles:

| when | title |
| --- | --- |
| block 1, before the document is opened | `Untitled1` |
| after opening, unmodified | `Parrot Field Report` |
| after any edit | `*Parrot Field Report` |

Note the window is titled from the document's `dc:title`, **not** its filename.

Verified by running the exact capture snippet with the dead Replace window
present: it selected the 1440x900 document.

### AbiWord's own menus sort ahead of the document too

Every menu and combo popup is an `[abiword]` window:

```text
View menu           X=80  Y=25  WIDTH=258 HEIGHT=303
View > Zoom submenu X=336 Y=303 WIDTH=154 HEIGHT=175
style combo popup   X=4   Y=0   WIDTH=178 HEIGHT=733
Insert menu         X=128 Y=25  WIDTH=245 HEIGHT=529
```

and they are listed *before* the document window. They are transient, so they
only matter if a checkpoint fires while one is open — but that is one more reason
the title match is the right one.

### Dialogs land top-left, and one is full screen

AbiWord's dialogs share the res_name, so the pin rule matches them: they are
moved to 0,0 and, if they carry no maximum size, resized.

```text
[Find] / [Replace]     0,0    478x254
[Insert Table]         0,0    365x259
[Zoom]                 1,45   178x259
[Font]                 0,0    1440x900   <-- resized by the pin rule
[Create and Modify Styles]  480,337  482x367   (centred - it is transient)
[Open File] / [Insert Picture] / [Export File]  173,84  1096x822
[Print]                420,237 601x516, and 635x516 once a printer is selected
[Select a filename]    191,107 1096x822
```

**The Font dialog is 1440x900**, exactly the size of the document window, so a
size assertion cannot tell the two apart. Another reason to match on title.

---

## Blocks

### 1. Load app

Nothing to dismiss. About 20 s to first paint.

### 2. Open document — Ctrl+O

```text
[Open File]  X=173 Y=84 WIDTH=1096 HEIGHT=822    (a GTK file chooser)
```

Typing a path beginning with `/` opens GTK's location entry, so
`/tmp/parrot-report.odt` then `Return` works with no clicking. About 45 s to
render page 1.

AbiWord **reuses** the empty `Untitled1` window rather than opening a second one.
During the open there is a transient moment when `Untitled1`, `Open File` and the
new document are all present; afterwards there is exactly one document window.

**AbiWord paginates the document to 97 pages where LibreOffice and OpenOffice
both give 98.** This is the whole reason `script.md` counts keystrokes instead of
naming page numbers.

### 3. Page through — Page Down x10

`Page: 5/97`, at the default Page Width zoom.

### 4. Jump to end — Ctrl+End

`Page: 97/97`, and **it needs up to 25 s to settle**. Measured twice: at 8 s and
again at 20 s the status bar still read `Page: 5/97`, which looks exactly like a
keystroke that did nothing. 30 s is used in the driver.

Unlike LibreOffice and OpenOffice, **one `Ctrl+End` is enough even from inside a
table** — see block 15.

### 5. Jump to start — Ctrl+Home

`Page: 1/97`, with the same generous settle.

### 6. Zoom

**Use View > Zoom, not the toolbar combo.**

```text
View menu        103,12
Zoom submenu     127,315   -> submenu at 336,303 154x175
  Zoom...        400,314   -> the [Zoom] dialog
  Page Width     400,343
  Whole Page     400,367
  Zoom to 200%   400,392
  Zoom to 100%   400,417
  Zoom to 75%    400,441
  Zoom to 50%    400,466
```

So 100 % is a single menu item, and 150 % goes through `Zoom...`:

```text
[Zoom]  X=1 Y=45 WIDTH=178 HEIGHT=259
  radios  200% 27,61   100% 27,88   75% 27,115
          Page width 27,142   Whole page 27,169   Percent 27,196
  percent field 58,229    Help 43,261   Close 130,261
```

There is **no OK button** — the zoom applies as soon as it is set, and `Close`
just dismisses the dialog. The percent field shows the current effective zoom
(169 % for Page Width at this window size), so it is a live control, not a blank.

Ends at `100 %` in the toolbar combo, read back to confirm.

#### The FIRST Zoom dialog of a session races, and block 6 warms it up

The geometry above is the one you get almost every time. Occasionally the first
Zoom dialog a session opens comes up **162x259 at 0,0** instead — undecorated,
its widgets 21 px lower relative to its own origin, sitting across the menu bar.

AbiWord maps it before setting `WM_TRANSIENT_FOR`, and fluxbox then applies the
`[app] (name=abiword)` rule from `pin-windows.sh` to a dialog it was never meant
to match: `[Deco]{NONE}` plus `[Position](TOPLEFT){0 0}`. This is the hazard that
script's own comment flags — "an app whose dialogs are NOT transient would need a
discriminator". AbiWord's dialogs *are* transient, just not always in time.

Nothing fails loudly. All four in-dialog clicks miss, `Close` at 130,261 lands
3 px below a dialog that now ends at y=258, and the dialog stays open over the
menu bar and eats the two `View` clicks of the second traversal. The zoom never
leaves Page Width, and check-006 fails against a page-width screen:

```text
measurement node   rmse 0.225042   dialog stacked UNDER the main window, invisible
locally            rmse 0.279954   dialog stacked OVER it, a black 162x259 corner
```

Both are within 0.023 of check-005 once that corner is masked — the screen is
block 5's, not block 6's.

Every open after the first has come up 178x259 at 1,45 — eight observations
across four sessions — so **block 6 opens a Zoom dialog and discards it with
Escape** before the sequence above, which moves the risky first creation to a
point where no coordinate depends on it. Escape rather than a click on `Close`:
the two forms' Close buttons overlap by about 4 px, so no single coordinate
closes both, and a key goes to whichever window has focus wherever it sits.

The warm-up makes AbiWord's Zoom block the longest in the group (66.7 s against
Collabora's 53.5 s), so `--normalize-time` re-pads block 6 in all six files.

**The warm-up moves the view by one pixel, so it ends on `Ctrl+Home`.** Opening
and dismissing the dialog is not free: without the re-anchor, checkpoints 6, 7
and 8 went to rmse 0.052 / 0.132 / 0.033 against references captured without it.
Every glyph differs and nothing else does — shifting the capture down one pixel
collapses the document-area rmse from 0.196 to 0.013. Block 5 ends on
`Ctrl+Home`, so repeating it after the warm-up restores 6 and 8 to their old
values exactly (0.0082 and 0.00527046).

Checkpoint 7 stays at **0.132166** — the same 1 px, stable across three runs.
Checkpoint 6 sits at scroll 0, where an offset cannot show; block 7 is the first
view scrolled away from the top, and block 8's `Ctrl+Home` clears it again. It
passes, but it spends two thirds of the 0.2 threshold, so reference 007 wants
re-capturing from a ground-truth-verified run.

#### The toolbar zoom combo cannot be driven by coordinates

It is a GTK combo popup and **it positions itself so that the currently selected
entry lands under the pointer**. With `Page Width` selected, `Other...` is at
562,105; once the selection has changed, the same click lands on a different
entry. Driving it that way set the zoom to 75 % when it was asked for 100 %, and
then to `Whole Page`, each time with no error.

### 7. Find word — Ctrl+F

```text
[Find]  X=0 Y=0 WIDTH=478 HEIGHT=254
  Find what field  204,30   (has focus when the dialog opens)
  Find button      413,30   (greyed until the field has text)
  Match case 26,82   Whole word 26,115   Reverse find 26,148
  Help 44,234   Close 432,234
```

Type `Cormorant`, then click `Find` three times. After the third:
**`Page: 3/97`**, with `Cormorant` selected in "The provisional conduit
downstream of Cormorant was cleaned and refitted." — the same sentence
LibreOffice and OpenOffice both land on from their page 3. That agreement across
three layout engines is the strongest evidence available that all three stepped
through the same three matches.

`Close` at 432,234 dismisses it. The window survives — see above.

### 8. Replace all — Ctrl+Home first, then Ctrl+H

Two separate traps in one block.

#### Ctrl+R is Align Right

Guessed as the replace shortcut, because `Ctrl+H` is not universal. It opens no
dialog; it **right-aligns the paragraph the cursor is in**, and the only visible
consequence is a `*` appearing in the title bar. `Ctrl+Z` undoes it. The Edit
menu is the authority:

```text
Edit menu 59,12
  Find...    Ctrl+F   291
  Replace... Ctrl+H   316
  Go To...   Ctrl+G   341
```

#### Replace All runs from the cursor, and does not wrap

This is the serious one. Block 7 leaves the cursor at the third `Cormorant` on
page 3. Opening Replace there and clicking `Replace All` gives:

```text
"AbiWord has finished its search of the document and has made 118 replacements."
```

118, not 120 — and the two before the cursor are still in the document, plainly
visible on screen. The wording ("finished its search of the document") reads like
a whole-document operation, the count is plausible, no error is raised, and
`check-result.sh` is the only thing that would ever have caught it.

Pressing **`Ctrl+Home` before opening the dialog** fixes it:

```text
"AbiWord has finished its search of the document and has made 120 replacements."
```

which is the number [`generate_document.py`](../generate_document.py) puts in.

```text
[Replace]  X=0 Y=0 WIDTH=478 HEIGHT=254
  Find what field     199,31   (has focus; EMPTY - it does not carry over from Find)
  Replace with field  199,76
  Find 398,30   Find and Replace 398,76   Replace All 398,122
  Help 44,234   Close 432,234
-> [] X=427 Y=446 WIDTH=587 HEIGHT=98   "...has made 120 replacements."   OK 719,504
```

### 9. Type paragraph

`Ctrl+End` — 30 s — then `Return` before typing, then the three lines. Ends on
`Page: 97/97`. Autocorrect is on and rewrites none of it.

### 10. Bold a line — Shift+Home, Ctrl+B

Confirmed in block 11's Font dialog, which opens with `Bold` selected in the
Style list.

### 11. Resize the text — Format > Font, NOT the size box

**The toolbar size combo is a silent no-op.** Triple-click it, type `18`, press
`Return`: the box shows `18`, keeps focus, and the text stays 12 pt. A second
`Return` does nothing, and `KP_Enter` does nothing. There is no error and the
box goes on displaying the value you asked for.

`Ctrl+D` opens the Font dialog instead:

```text
[Font]  X=0 Y=0 WIDTH=1440 HEIGHT=900   (resized by the pin rule)
  Font list    Liberation Serif selected
  Style list   Bold selected           <- confirms block 10
  Size list    10 (98)  11 (121)  12 (144)  14 (167)  16 (190)  18 (213)  20 (236)
  preview shows the selected line
  Help 49,875   Cancel 1299,875   OK 1389,875
```

Click `18` at 1290,213 and `OK` at 1389,875. The toolbar size box then reads 18
and the line is visibly larger.

The Font dialog does **not** linger after closing.

### 12. Apply heading — Format > Create and Modify Styles

The style combo cannot be used. A triple-click on it opens its popup:

```text
[abiword]  X=4 Y=0 WIDTH=178 HEIGHT=733
```

positioned so that the **currently selected** entry (`Text body`) sits under the
pointer, with `Heading 1` scrolled out of view above. This is the same combo
behaviour as the zoom box, and it is why this app gets driven through dialogs.

```text
Format menu 211,12
  Font... Ctrl+D 37 ... Create and Modify Styles... 466
-> [Create and Modify Styles]  X=480 Y=337 WIDTH=482 HEIGHT=367
   Available Styles list:  Caption 361  Figure 385  Heading 409
                           Heading 1 433  Heading 2 457  Standard 481
   New 704,520  Modify... 804,520  Delete 902,520
   Help 524,662   Close 827,662   Apply 916,662
```

Click `Heading 1` at 565,433, then **Apply** at 916,662, then `Close` at
827,662. The toolbar then reads Liberation Sans 22 — Heading 1's own font — and
the line renders as a heading.

The list is filtered to "In Use" styles, and `Heading 1` is in use because the
document ships twelve chapter headings, so its position is a property of the
document rather than of the run.

### 13. Insert image

`Ctrl+End`, `Return`, then:

```text
Insert menu   154,12
  Break...        37     Table...  113
  Picture...      490
-> [Insert Picture]  X=173 Y=84 WIDTH=1096 HEIGHT=822   (GTK file chooser)
```

Type `/tmp/parrot.png` and `Return`. Afterwards `Page: 98/98`.

Unlike OpenOffice, **AbiWord raises no context toolbar** when an image is
inserted, and the image is laid out inline, so nothing has to be dismissed and
nothing floats over the table that block 14 adds.

### 14. Insert table

```text
Ctrl+End, Return, Insert > Table...  (154,12 then 182,113)
-> [Insert Table]  X=0 Y=0 WIDTH=365 HEIGHT=259
   Number of columns  250,50   (defaults to 5)
   Number of rows     250,93   (defaults to 2)
   Automatic column size radio 41,157   Fixed 41,192
   Help 49,235   Cancel 226,235   Insert 317,235
```

Triple-click each spin field, type `3` and `4`, then `Insert`. Then `Alpha` Tab
`Beta` Tab `Gamma`. Ends on `Page: 98/98`, with the table drawn below the image.

### 15. Insert page break — Ctrl+End **once**, then Ctrl+Return

**AbiWord differs from LibreOffice and OpenOffice here.** In both of those the
first `Ctrl+End` only reaches the end of the table and the page break is a silent
no-op. In AbiWord one `Ctrl+End` leaves the table and reaches the end of the
document — verified by screenshot, with the cursor visible below the table's last
row and the style box reading `Text body` rather than a table style.

`Ctrl+Return` then takes: `Page: 98/98` → **`Page: 99/99`**.

A second `Ctrl+End` would be harmless, but it is left out because the measured
behaviour is what belongs in the driver.

### 16. Undo and redo — Ctrl+Z, Ctrl+Y

`99/99` → `98/98` → `99/99`.

**This block's screenshot carries no information in AbiWord.**
`abiword-check-016.png` is byte-identical to `015`, because undo followed by redo
is a round trip and AbiWord restores the scroll position exactly. LibreOffice and
OpenOffice both differ here only because their view ends up scrolled slightly
differently — the state is the same in all three.

Ground truth covers half of it: if `Ctrl+Z` ran and `Ctrl+Y` did not, the
document would be 98 pages and the PDF page count would fail. It does **not**
cover both keystrokes failing to arrive, which leaves exactly the state block 15
ended in.

Together with block 18 that is two identical consecutive pairs in this
recording — under the three-in-a-row threshold that means a run stopped doing
anything, and both are explained. `verify-app.sh` prints them; they are expected.

### 17. Save — Ctrl+S

No dialog: AbiWord writes ODT natively and does not ask about keeping the format.
The file goes from 9,167,202 to 10,150,039 bytes and the `*` leaves the title.

### 18. Export PDF — File > Print, print to file

There is **no "Export as PDF" in the File menu**:

```text
File menu 19,12
  New Ctrl+N 37   Open... Ctrl+O 87
  Save Ctrl+S 138   Save As... 163   Save Copy... 188
  Page Setup 239   Print Preview 264   Print... 289
```

`Save Copy...` looks like the route and is not. It opens `[Export File]` with
`Save file as type:` set to `AbiWord (.abw, .zabw, abw.gz)`, and typing a `.pdf`
name gets:

```text
"The given file extension does not match the chosen file type!
 Do you want to use this name anyway?"     No 575,505   Yes 868,505
```

Answering Yes would write an AbiWord document called `parrot-report.pdf` — a
file that exists, has the right name, and is not a PDF. The `Save file as type`
combo is the only way to change that, and **it does not open under synthetic
clicks at all**: neither a click on the box, nor on its arrow, nor two clicks,
nor `Down` on the focused widget changed it from `AbiWord`.

`script.md` allows print-to-file for exactly this kind of app, and that route is
clean:

```text
File > Print...  (19,12 then 52,289)
-> [Print]  X=420 Y=237 WIDTH=601 HEIGHT=516
   printer list: one row, "Print to File"  503,301
   click it -> the dialog grows to 635x516 and gains:
     File: button        523,512   (shows /output.pdf)
     Output format:  PDF 830,512  Postscript 895,512  SVG 1000,512
                     -- PDF is ALREADY selected
     Range: All Pages 456,581 -- ALREADY selected
     Preview 799,701   Cancel 897,701   Print 995,701
-> click the File button -> [Select a filename] X=191 Y=107 WIDTH=1096 HEIGHT=822
   Ctrl+A, type /tmp/parrot-report.pdf
   Cancel 1147,883   Select 1237,883
-> Print 995,701
```

Verified end to end: it writes a real `%PDF-` file. **The dialog must be measured
in its post-selection 635x516 state** — selecting the printer widens it by 34 px
and moves every button under it.

The Print dialog does not linger after it closes.

---

## Ground truth

The status bar gives `Page: N/M` and the font at the cursor, and the title bar
gives the modified flag. There is no word count and no table-cell reference, so
AbiWord offers less continuous confirmation than LibreOffice.

What it did catch: the page counts through blocks 3–5 and 13–16, and the `*`
appearing after `Ctrl+R` that revealed the align-right no-op.

What it could **not** catch, and what only
[`common/check-result.sh`](../common/check-result.sh) would have: the Replace All
that did 118 of 120.
