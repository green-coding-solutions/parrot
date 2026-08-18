# Collabora Office — landmarks

**Status: complete. 18 PASS / 0 FAIL, worst RMSE 0.0524, ground truth PASS.**

All eighteen blocks were driven through a clean container first, every end state
re-read, then recorded and replayed in a fresh container. The end states below
are from that measuring pass and the recording reproduced every one of them.

The single most important thing below: **drive this application from the
keyboard wherever there is a choice.** Its ribbon is a web view, and a click on
a control that has not finished painting falls through to the document — where
the next thing typed replaces the selection. That happened twice while this was
being worked out, and both times the screen looked entirely plausible
afterwards.

```bash
bash applications/wordprocessors/common/setup-container.sh collabora --measure
```

Read [`../calligra/MEASUREMENTS.md`](../calligra/MEASUREMENTS.md) first — it
carries everything about getting a Flatpak to run in this harness at all (the
two `--security-opt` relaxations, why running the application as **uid 1001** is
what removes `SYS_ADMIN` and `NET_ADMIN` entirely, and the missing D-Bus), and
all of it applies here unchanged.

---

## Install

Pinned to an OSTree commit and read back after installing:

```text
com.collaboraoffice.Office   54dc072b35c27bc822d711d00b62d3da8cdd564dd4ebefb6db27c0b81d19c177
org.kde.Platform//6.10       d0d8f7888350e93c0e6d009d79c5b143f6f6dde09de28ff93a7dc8a14a848c16
```

`flatpak info` in the container reports the version as **26.04.2.4-2**. The
host's Fedora-filtered flathub mirror reports 26.04.1.4-1 for the same commit
because its appstream data is stale — the commit is the authority, not either
version string.

This is the largest install in the group by a distance: about 450 MB of
application on a 387 MB runtime, 1.2 GB and 1 GB respectively once unpacked.

### Chromium will not start as root

Collabora's desktop suite is Collabora Online's UI running offline, built on
**QtWebEngine** — its Flatpak declares `base=app/io.qt.qtwebengine.BaseApp` and
`command=coda-qt`. Chromium refuses to run as root:

```text
ERROR:zygote_host_impl_linux.cc(115)] Running as root without --no-sandbox is
not supported. See https://crbug.com/638180.
```

and no window ever appears. Everything in this container runs as root, so
[`install.sh`](install.sh) sets

```bash
flatpak override --env=QTWEBENGINE_CHROMIUM_FLAGS=--no-sandbox com.collaboraoffice.Office
```

as a permanent override rather than passing it on the command line, so the
`startcommand` — and `replay.py`'s relaunch of it — stay a plain `flatpak run`.

Worth being clear about what that gives up: Chromium's own sandbox, **inside** a
Flatpak sandbox, in a throwaway container that already needs `SYS_ADMIN` and
`NET_ADMIN` to run a Flatpak at all. It is a real reduction and the group should
know it is there.

### The launch line

```bash
flatpak-session flatpak run com.collaboraoffice.Office
```

`flatpak-session` is the wrapper [`../common/install-flatpak.sh`](../common/install-flatpak.sh)
writes; without it `flatpak run` dies on the missing D-Bus with a message that
reads like a missing file.

## Window pinning — confirmed

```text
[Collabora Office - Start]  X=0 Y=0 WIDTH=1440 HEIGHT=900
WM_CLASS  "coda-qt", "Collabora Office"
```

`coda-qt`, **not** `soffice`. The scenario's first guess was `soffice` on the
assumption that this is still LibreOffice underneath; it is not, and the window
came back 1200x675 at 120,144 with no complaint from anywhere. Read back after
the fix.

---

## What is established about the application

### It is the most faithful of the newcomers

```text
Page 1 of 98  |  54,607 words, 361,913 characters  |  English (UK)  |  170%
```

**98 pages**, which is exactly what LibreOffice and OpenOffice give, and the
fonts are right — the title renders in Liberation Sans and the body in
Liberation Serif. Compare AbiWord and TextMaker at 97, and Calligra at 120 with
the wrong fonts entirely.

### It autosaves

The ODT on disk already had a fresh mtime and a changed size **before** block 17
pressed Ctrl+S. That is the web-application architecture showing through, and it
means the saved document is not on its own evidence that block 17 ran. It does
not weaken `check-result.sh`, which asks whether the work was done rather than
which keystroke did it.

---

## Block 1 — Load app, and why it ends on the start screen

Collabora opens a **start screen**, not a document: a purple header, a left rail
of `Home` / `New` / `Open`, a template gallery (Blank Document, CV, Default
Style, Modern Business L…, Modern Style, Resume, Simple Style) and an empty
`Recent` section.

```text
  Home    79,110      Blank Document tile   269,262
  New     79,207
  Open    79,300
```

`script.md` asks for "an editable page on screen", and this is not one. Clicking
`Blank Document` does produce one — **and it is still the wrong thing to do**:

```text
after clicking Blank Document:
  [Collabora Office - Start]           X=0 Y=0 WIDTH=1440 HEIGHT=900
  [Untitled.odt - Collabora Office]    X=0 Y=0 WIDTH=1440 HEIGHT=900
  [welcome-slideshow.odp - Collabora Office]  800x450
```

Collabora opens **one window per document** and does not reuse an empty one, so
opening the report in block 2 then gives *two* 1440x900 windows with the same
class — measured, not assumed. `record-macro.py` captures `head -n1` of the
class search and `replay.py` takes the largest; with two identical windows
neither can tell them apart, and both **raise** the window they pick before
capturing, so the wrong choice also puts the start screen on top of the
document and swallows the next block's clicks.

So block 1 ends on the start screen. It is a deviation from `script.md` and it
should be read as one, but it is the honest one: the start screen *is* this
application's launch state, and block 1 measures a launch. Nothing else in the
run is affected, because the start screen closes itself the moment the document
window appears.

### The `Blank Document` tile fails silently, and `--writer` with it

Worth recording even though the route was abandoned, because the failure is
invisible on screen — the tile just does nothing:

```text
ERR  Failed to copy template from /app/share/coolwsd/browser/dist/templates/TextDocument.odt
     to /root/Documents/Untitled.odt|WebView.cpp:879
ERR  Failed to create new document of type: writer|Bridge.cpp:1017
```

`flatpak run com.collaboraoffice.Office --writer` is accepted as an argument and
dies the same way, taking the whole process with it — no window ever appears.

The cause is not the missing directory, which was the obvious guess and was
wrong. The app already declares the permission it needs:

```text
$ flatpak info --show-permissions com.collaboraoffice.Office
filesystems=xdg-documents;xdg-run/gvfsd;xdg-config/kdeglobals:ro;/tmp;
```

but flatpak resolves `xdg-documents` through `~/.config/user-dirs.dirs`, and
this image has no `xdg-user-dirs`. With no way to resolve the location, flatpak
**skips the binding without a word**, and `$HOME/Documents` simply is not there
inside the sandbox. Creating `/root/Documents` in the container changes nothing
on its own; creating it *and* writing

```ini
XDG_DOCUMENTS_DIR="$HOME/Documents"
```

to `/root/.config/user-dirs.dirs` makes `Documents` appear inside the sandbox
and the tile work. Neither is in `install.sh`, because block 1 no longer needs
it — but anyone who tries to make Collabora create a document will need both.

### The welcome slideshow is tied to creating a document

An 800x450 `welcome-slideshow.odp` window appears over a **newly created**
document on first run, with a close button at 779,20. It does **not** appear
when a document is opened, so the route this scenario takes never sees it —
confirmed in a fresh container. If a future route does create a document,
note that the click that closes the slideshow also lands on whatever is beneath
it: at 779,20 that is the `Help` tab of the ribbon.

## Block 2 — Open document, and the mode switch

`Open` in the left rail raises an `[Open File]` dialog, 632x412 at 394,226 —
the Qt fallback, because the portal is absent here as it is for Calligra:

```text
  File name field   708,562
  Open              975,562
  Files of type     already "All Files (*)"
```

Click the field, `Ctrl+A`, type the absolute path, `Return`. About 70 s. The
start screen closes itself, leaving exactly one window.

### …but it opens in Viewing mode

The mode selector at the top right reads **`Viewing`**, and the ribbon is absent
— only `File / Edit / View / Help`. Nothing in blocks 3–18 can be driven from
there.

```text
  mode selector arrow   1421,17
  "Viewing Mode"        1383,43
  "Editing Mode"        1381,73
```

This is per document and it is not configurable from anywhere reachable: there
is no `registrymodifications.xcu` in the app's data at all — its state lives in a
QtWebEngine persistent profile. A newly created blank document *does* arrive in
Editing mode, so it is specifically opening an existing file that lands in
Viewing.

**The switch is part of block 2.** Block 2's job is to leave the document open
and usable, and a read-only view is not that; putting it at the top of block 3
would make Collabora's "press Page Down ten times" carry a cost no other
application's does.

```text
end state   Page 1 of 98 | 54,607 words, 361,913 characters | English (UK)
            | Edit mode | 170%,  ribbon on Home
```

Note the language flips from English (USA) to English (UK) with the mode. That is
cosmetic and it is in the reference screenshot, so it only has to be consistent.

---

## Blocks 3-18 — the measured pass

Ground truth throughout is the status bar: `Page n of 98`, the word and character
count, and — with a selection — `Selected: n words, n characters`.

```text
 3  Page through   ten Next                    -> Page 4 of 98   (at the 170% it opens with)
 4  Jump to end    Ctrl+End (~35 s)            -> Page 98 of 98
 5  Jump to start  Ctrl+Home                   -> Page 1 of 98
 6  Zoom           170 -> 150 -> 100           -> Page 1 of 98, canvas redrawn both ways
 7  Find word      Ctrl+F, 3x next             -> Result 3 of 120, Page 3 of 98,
                                                  Selected: 120 words, 1,080 characters
 8  Replace all    Ctrl+Home, ribbon Replace   -> "replaced 120 times", 362,033 characters
 9  Type paragraph Ctrl+End, Return, 3 lines   -> Page 98 of 98, 54,633 words, 362,195 chars
10  Bold a line    Shift+Home, Ctrl+B          -> Selected: 9 words, 53 characters, B lit
11  Resize         Font panel size box, 18     -> visibly larger, selection still live
12  Apply heading  Ctrl+1                      -> Heading 1, gallery highlights it
13  Insert image   Insert > Image, Escape      -> Page 99 of 99, Picture tab gone again
14  Insert table   Insert > Table, 3 x 4       -> Page 99 of 99, 54,636 words, 362,209 chars
15  Page break     Ctrl+End, Ctrl+End, Ctrl+Return -> Page 100 of 100
16  Undo and redo  Ctrl+Z, Ctrl+Y              -> 99 of 99, then 100 of 100
17  Save           Ctrl+S, no dialog           -> Save greys out in the File backstage
18  Export PDF     File > Export > PDF         -> 100 pages, 1.8 MB
```

### Block 6 — zoom, and it works properly

The zoom control is at the bottom right: `−  100% ▾  +`.

```text
  the percentage (opens the list)  1334,884
  100   1327,770        120   1327,800
  150   1327,830        170   1327,860
```

The list is `20 25 30 35 40 50 60 70 85 100 120 150 170 200 …`, so **150 and 100
are both there** — one of only three applications in the group that can do block
6 exactly. And **it does not reposition**: reopened at 150 %, the list came back
pixel-identical with 100 still at y=770. Checked twice, in two sessions, by
re-reading the list rather than by assuming — and by watching the canvas redraw,
not the label change.

(Compare Calligra, whose equivalent widget is completely inert.)

### Block 7 — Find is a Navigation sidebar

`Ctrl+F` opens a **Navigation** panel on the left, not a find bar.

```text
  search box   109,201
  Results tab  103,243
  next result  233,276        previous  202,276
  close panel  220,148
```

Type `Cormorant`, `Return` — it reports **`120 results`**, which is exactly what
the document contains and is free ground truth. `Return` alone does not set the
result index; three clicks on the ▼ button reach `Result 3 of 120`. Collabora
highlights every match at once, so the status bar reads `Selected: 120 words,
1,080 characters` for the whole block.

**Close it with its own X, never with Escape** — see the traps below.

### Block 8 — Replace all

Ribbon `Search` (1083,70) opens a two-item menu; `Replace` (1123,172) raises a
**Find and Replace** dialog drawn *inside* the web view, so it is not a separate
X window and nothing in `WINS` or `CP()` ever sees it.

```text
  Find field     763,400
  Replace field  777,489
  Replace All    874,541
  close (X)      917,313
```

```text
Search key replaced 120 times.
```

54,607 words unchanged, 361,913 -> 362,033 characters (+120, one per
`Cormorant`->`Shearwater`). **The message pushes the lower half of the dialog
down by 32 px** — the Replace field moves to y=521 and the buttons to y=573 — so
anything clicked after it needs the post-message coordinates. The close X is
above the message and does not move.

Two more things this block needs:

* `Ctrl+Home` first, as everywhere else in this group — Replace All runs from
  the cursor and block 7 left it on page 3.
* the ribbon's **Search menu stays open behind the dialog**. Click `Search`
  again afterwards to toggle it shut, or the checkpoint photographs a menu.

### Block 11 — the Font group has to be expanded first

At 1440x900 the ribbon is in its compact form and the Font group is a single
button. Its dropdown arrow at `263,70` expands a panel:

```text
  font family  300,139     size box  510,139     B  228,173
  collapse again: the Font group button, 237,70
```

Click the size box, `Ctrl+A`, type `18`, `Return` — the same rule TextMaker
needs. Collapsing the panel afterwards is safe: verified by reading the rendered
line, the bold and the 18 pt both survive it.

### Block 14 — the grid picker labels itself

`Insert > Table` (250,60) opens a **10x10 grid picker**, not a dialog. Hovering
a cell shows a tooltip with the dimensions, so the coordinate can be confirmed
in text instead of counted off a screenshot:

```text
  hover 289,182  ->  tooltip "3 x 4", 3 columns and 4 rows highlighted
```

There is a dropdown arrow beside `Table` at 286,71 that was not explored.

### Block 15 — TWO Ctrl+End presses

This is the LibreOffice and OpenOffice trap, present here for the same reason
(same core), and it is silent:

```text
Ctrl+End          -> cursor lands in the LAST CELL of the table. The only sign
                     is the contextual Table ribbon tab staying active.
Ctrl+Return       -> nothing. Page 99 of 99 before, Page 99 of 99 after.
Ctrl+End again    -> leaves the table; the tab strip returns to Home
Ctrl+Return       -> Page 100 of 100
```

`Insert > Page Break` at 59,63 is an alternative that does not depend on getting
out of the table first, and was not tried.

### Block 18 — Export PDF

`File` (98,17) opens a full-screen backstage — `Home / New / Open / Info / Save /
Save As / Print / Export / Sign`, with `Save` greyed out once the document is
saved. Then:

```text
  Export        75,371
  PDF tile     1321,207     ("PDF Document (.pdf)", the plain one)
                             a second "PDF ... (.pdf) with options" sits at 279,315
  [Export As] dialog, 632x412 at 394,226, same shape as block 2
  File name    708,562      Ctrl+A, type /tmp/parrot-report.pdf, Return
```

**100 pages**, which is 98 + the image page + the page break — the same as
LibreOffice and OpenOffice, and the group default, so Collabora needs **no**
`expected-pdf-pages` file.

At 1.8 MB the PDF is a fifth of the size the others produce (9.5-9.9 MB), which
is worth a glance at some point but is not a correctness problem: the page count
is right and the checks pass.

---

## The two traps that cost the most time

Both are the same underlying fault — **the Styles gallery had not painted** — and
both produced a perfectly plausible screen.

### 1. Clicking the blank Styles box silently clears direct formatting

The wide white area labelled `Styles` at the top of the Home ribbon is a gallery
of style previews. When it has not finished painting it is an empty box. After
applying bold and 18 pt in blocks 10 and 11, a single click on it put the line
back to regular 12 pt. The selection stayed live and nothing else changed, so the
only evidence was the rendered text.

Isolated by re-applying both and then collapsing the Font panel *without*
touching the Styles box: the formatting survived. It is the Styles box.

### 2. Typing into that box types into the DOCUMENT

Clicking it does not focus it. With the line still selected, clicking it and
typing `Heading 1` **replaced the selected sentence with the literal text
"Heading 1"** — 54,633 words down to 54,626.

The same thing happened earlier in block 7: `Escape` closed the Navigation
panel, and the `Cormorant` that was meant for its search box was inserted into
the title page instead. 54,607 -> 54,608 words, and a title page that still
looked like a title page.

### What that means for the driver

**No Styles box, and no `Escape` to close panels — use the panel's own close
button.** Block 12 uses `Ctrl+1`, which applies Heading 1 directly, is
keyboard-only, and depends on nothing painting.

The clean pass makes this worse, not better: **the gallery does paint** — it
came up fully drawn, showing `Default Paragraph / Body Text / Heading 1-4 /
Title / Subtitle`, and it highlights the current style correctly. So this is a
*rendering race*, not a permanent defect, and a race is the more dangerous of
the two: a control that is reliably absent gets noticed, a control that is
usually there does not. Nothing in the driver should depend on it.

`Escape` on a **selected picture** is fine and is what block 13 uses — that one
was measured, and the contextual Picture tab disappearing confirms it.

Collabora's undo is also per-character for typed text, so recovering from either
mistake takes many `Ctrl+Z` presses, not two.

---

## Replay, and what the RMSE is made of

```text
PASS 18   FAIL 0
worst   0.0524191    best   0 (block 1) and 1.24202e-05 (block 14)
no identical consecutive checkpoints
ground truth RESULT PASS
```

0.052 is six to nine times the other applications in this group (LibreOffice
0.0082, OpenOffice 0.0081, AbiWord 0.0081, TextMaker 0.0059), and **all of it is
the Styles gallery**. The evidence is block 14, which replays at 1.2e-05:
that is the only checkpoint whose ribbon is on the contextual **Table** tab, so
the gallery is not on screen at all. Every checkpoint that shows the Home ribbon
sits at 0.050-0.052; block 1, which is the start screen and has no ribbon,
replays at exactly 0.

So the race described below is visible in the numbers, not just in the
narrative: the gallery paints on some runs and not others, and 0.052 is what a
520x70 region of style previews costs against a 1440x900 frame. It is a quarter
of the 0.2 threshold, so the recording is sound — but it is the one number in
this group that would move if the machine were faster or slower, and it should
be watched rather than assumed stable.

### A reporting bug found on the way

`verify-app.sh` first reported the worst RMSE as **1.24202**, which would have
been a failure six times over. It was not: the value was `1.24202e-05`, and the
script's `rmse=[0-9.]+` pattern truncated the exponent, after which `sort -g`
ranked the best result in the run as the worst. Fixed in
[`../common/verify-app.sh`](../common/verify-app.sh) — the exponent is now part
of the pattern, and the scan is anchored to the `[check-image]` lines so the
script cannot re-read its own summary. That line is the one the loop says to
read *instead of* the pass count, so it has to be right.

## Ground truth from the clean pass

```text
  ok   Shearwater x120 (want 120)          ok   Cormorant x0 (want 0)
  ok   typed: The kestrel circled above the reservoir befo...
  ok   typed: Three technicians logged the reading and fil...
  ok   typed: Nothing in the record explained the drop in ...
  ok   typed block carries a style (Heading_20_1)
  ok   pictures x13 (want 13)              ok   tables x4 (want 4)
  ok   table cell Alpha / Beta / Gamma
  ok   paragraphs starting a new page x13 (12 chapters + 1 inserted), from 2 break style(s)
  ok   pdf 100 pages, 1831 KiB (want 100)
RESULT PASS
```
