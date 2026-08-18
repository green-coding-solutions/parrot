# SoftMaker FreeOffice TextMaker — landmarks

**Status: complete. 18 PASS / 0 FAIL, worst RMSE 0.0059, ground truth PASS.**

Every landmark below was measured by hand against a running container and
checked against the status bar or the saved file, not against how the screen
looked. All eighteen blocks are measured, recorded (837 events), and replayed in
a fresh container.

```bash
bash applications/wordprocessors/common/setup-container.sh freeoffice --measure
```

Read [`../libreoffice/MEASUREMENTS.md`](../libreoffice/MEASUREMENTS.md) as well —
several of its findings are properties of the harness rather than of any one
application.

---

## Install

Pinned to **11.1 / package revision 3702**, fetched straight from SoftMaker's
own APT pool and verified against **the digest SoftMaker publish**:

```text
https://shop.softmaker.com/repo/apt/pool/non-free/p/proprietary/softmaker-freeoffice-2024_3702_amd64.deb
sha256 d518ce8058cfae4314f828b3885236aeb964551f3589f2b83d74ef02d80c1e23
```

from `dists/stable/non-free/binary-amd64/Packages`. That makes this the only app
in the group whose checksum is the vendor's rather than one observed from a
download.

The previous [`install.sh`](install.sh) piped SoftMaker's
`install-softmaker-freeoffice-2024.sh` instead. That script adds
`shop.softmaker.com` as an APT source and installs whatever is current from it,
so the benchmark would have measured a different application every few weeks and
no recording would have survived it — and the repository would have stayed wired
into the image for every later `apt-get`. The direct `.deb` avoids both.

`textmaker24free`, **not** `textmaker24`: both names exist and the unsuffixed one
belongs to the paid SoftMaker Office build.

## The window is called `tm`

```text
[Untitled 1 - TextMaker]   WM_CLASS "tm", "tm"
```

The binary, the package and the `.desktop` file are all `textmaker24free`. The
window is not. `pin-windows.sh textmaker24free 1440 900` matched nothing, and
what that looks like is **nothing at all**: no error, no warning, just a window
that comes back

```text
[Untitled 1 - TextMaker] X=180 Y=144 WIDTH=1080 HEIGHT=675
```

After `pin-windows.sh tm 1440 900`, read back off the running window:

```text
[Untitled 1 - TextMaker] X=0 Y=0 WIDTH=1440 HEIGHT=900
```

Always read the geometry back.

### Match on the title anyway

Every dialog also reports `WM_CLASS "tm", "tm"`. Unlike WPS's and AbiWord's they
are **not** resized to 1440x900 — they carry a maximum size, so fluxbox leaves
them at their natural size and merely centres them — and unlike AbiWord's they
are **destroyed** on close rather than left mapped at 0,0. So class matching
would probably survive here.

It is still matched on the title, because the checkpoint capture takes
`head -n1` and there is no reason to depend on "probably":

```bash
TITLE_RE='^.+ - TextMaker$'
```

That covers all three titles the document window carries — `Untitled 1 -
TextMaker` before the open, then with and without the modified `*` — and matches
no dialog, because TextMaker titles them `Open`, `New picture`, `New table`,
`Zoom`, `Search and replace`, `PDF export`, `Error` and `TextMaker`. Verified to
return exactly one window.

**One window per document.** TextMaker is single-instance and opens each
document in its own top-level window, so two open documents would both match the
title regex. Block 2 does not create one: an *unmodified, empty* `Untitled 1` is
reused, the way LibreOffice and AbiWord reuse theirs. Launching `textmaker24free`
a second time while one is running does add a second window (`Untitled 2`) — do
not do that during a run.

### The `*` appears during block 7, not block 9

The title picks up its modified marker at the **first Search**, before anything
has been edited. Nothing is actually changed — block 17 saves and
`check-result.sh` passes on the bytes — but a title regex anchored on the exact
string `parrot-report.odt - TextMaker` would stop matching from block 7 onward.

## First-run state, and how it is seeded away

Two modal dialogs stand in front of the application on a fresh profile, and a
third thing — the welcome document — stands in front of an editable page. All
three are settings, in **two** ini files under `/root/SoftMaker/Settings/`:

| what | where | key |
| --- | --- | --- |
| `[User interface]` 1028x648 — Ribbon or classic menus, before the app starts | `offo24config.ini` | `UIThemeNewPro=0` |
| `[User info]` 891x553 — name, company, address | `offo24config.ini` | `[UserData]` section must exist |
| opens `Welcome to TextMaker.tmdx` instead of a blank document | `tmfo24config.ini` | `ShowWelcomeDocument=0` |
| the tips sidebar, ~300 px down the right | `tmfo24config.ini` | `SidebarDocking=0` |
| startup update check against softmaker.com | `offo24config.ini` | `UpdateCheckEnabled=0` |

Each key was found by **diffing the file across the click that sets it**. Nothing
was captured: TextMaker's own first run also writes

```text
guid=350D6914-5335-0FA4-7A44-8A54CF3D2761      a per-install identifier
FirstDayTime=1786117369                        the trial clock
FirstDayHash=264145875320941045124803135683767019828
AdsLastDate=7.8.2026   SidebarAdDate=07.08.2026
```

and `AGENTS.md` is explicit that such values must not go into a committed
profile — they are valid but wrong, silently. Verified from a clean container:
with only the five keys above, `FirstDayTime` and `FirstDayHash` are regenerated
fresh and **no `guid` is written at all**, because turning the update check off
also stops the identifier being minted.

### The sidebar is turned off because it carries a dated advertisement

`SidebarDocking=0` looks like a cosmetic choice and is not. The sidebar's own
settings are

```text
AdsLastDate=7.8.2026     SidebarAdPic=1     SidebarAdDate=07.08.2026
```

against 136 banner images that the `.deb` unpacks into the profile from
`/usr/share/freeoffice2024/inst/banners.zip`. A reference screenshot with a
date-keyed advertisement in 300 px of it fails on replay the moment the date
moves. Turning the sidebar off is one click in View > Sidebars, removes the whole
class of failure, and gives the document the full window width every other app in
the group gets.

(The banners ship *inside the deb*, so they are pinned by its SHA-256 and no
network fetch happens at run time. The `Discover SoftMaker Office` shopping-cart
button in the File tab and the small cart icon in the ribbon are static and stay.)

---

## The blocks

Coordinates are 1440x900 absolute, with the window pinned at 0,0. The status bar
is the ground truth throughout: it carries `L n Col n`, `Page n of m`, the word
count, and — when there is a selection — the **selected** word count instead.

### 1. Load app

Launch `textmaker24free`. With the profile seeded there is nothing to dismiss.

```text
end state   blank Untitled 1, Ribbon UI, no sidebar
            Section 1 | Chapter 1 | Page 1 of 1 | English (United States) | 0 words | Ins | 100%
```

### 2. Open document

`Ctrl+O` opens a classic tree+list `[Open]` dialog, 993x487 at 224,251.

```text
  File name field   553,617
  OK                811,617
```

The File name field **does** take an absolute path, and `Return` **does**
activate it — neither is true of every app in this group, and both were checked
rather than assumed. The default File type is `All documents (*.tmdx;*.tmvx;…)`
and it already includes ODT, so the type combo is never touched.

```text
end state   Page 1 of 97, 54607 words, style Title, Liberation Sans 28
```

TextMaker paginates the document to **97** pages, as AbiWord does; LibreOffice
and OpenOffice both make it 98. This is why `script.md` counts keystrokes and
never names a page.

### 3. Page through

Ten `Next`, about 0.8 s apart.

```text
end state   L 33 Col 7 | Page 5 of 97 | Liberation Serif 12 | Text body
```

### 4. Jump to end

`Ctrl+End`, settles in about 25 s. `L 37 Col 52 | Page 97 of 97`.

### 5. Jump to start

`Ctrl+Home`. `L 1 Col 1 | Page 1 of 97`.

### 6. Zoom

**Double-click the zoom percentage in the status bar** at `1385,885`. That opens
a `[Zoom]` dialog, 473x318 at 484,336:

```text
  Full page / Two full pages / Three full pages / Fit margins / Fit text /
  Previous zoom level  then  50%  75%  100%  150%  200%
  100%   560,541
  150%   560,579
  OK     884,366
```

**The list does not reposition.** Reopened with 150 % selected, the dialog came
back at exactly the same place with 150 % highlighted in its own row and 100 %
still at y=541. That is worth stating because it is the opposite of AbiWord's
zoom and style boxes, which put the *selected* entry under the pointer.

Do **not** drive the zoom from the ribbon: View > Set zoom would leave the ribbon
on the View tab, and blocks 10–12 need Home.

### 7. Find word

`Ctrl+F` opens `[Search and replace]` on its **Search** tab, 619x382 at 411,534.

```text
  Search for field   615,605
  Search             908,590      (the label becomes "Search again" after the first)
  Close              908,628
```

Three clicks on the same button. `end state  L 24 Col 24 | Page 3 of 97 | 1 word`
— the same page 3 LibreOffice, OpenOffice and AbiWord all land on.

### 8. Replace all

`Ctrl+H` opens the same window on its **Replace** tab — and at a **different
size and position**, 619x458 at 411,458, because the dialog is centred and the
Replace tab is taller. Every coordinate in this block differs from block 7's:

```text
  Search for field    615,529
  Replace with field  615,629
  Replace all         908,590
  Close               908,628
  OK on the count box 721,500     (the box is [TextMaker] 349x128 at 546,431)
```

`Ctrl+Home` **first**, and wait for it. TextMaker's Replace All runs from the
cursor and the dialog's "Search from top" box is unticked by default, so from
block 7's match on page 3 it would replace a subset and report that number as
though it were the answer — which is exactly what AbiWord did (118 of 120). From
the top:

```text
120 occurrences have been replaced.
```

which is what the document contains. `end state  L 1 Col 1 | Page 1 of 97 | 54607 words`.

### 9. Type paragraph

`Ctrl+End`, `Return`, then the three sentences one keystroke at a time.

```text
end state   L 40 Col 54 | Page 97 of 97 | 54633 words     (54607 + 26)
```

### 10. Bold a line

`Shift+Home`, `Ctrl+B`. `L 40 Col 1 | 9 words` — the status bar switches to the
selected word count, which is the cheapest confirmation the selection is live.

### 11. Resize the text

The ribbon's font-size box at `462,52`. **Click once, then `Ctrl+A`** — a
triple-click does *not* select the box's contents. The first attempt at this
triple-clicked, typed `18`, and produced

```text
Error: The font size must be between 1 pt and 999 pt.
```

with the box reading `1218`: the 18 had been appended to the 12. The error box is
415x128 at 513,431 with OK at `721,500`; dismissing it reverts the box to 12 and
leaves the selection intact, so the mistake is recoverable but silent up to the
point where it is not.

With `Ctrl+A` the box takes `18`, `Return` applies it, and the selection stays
live (`9 words`).

### 12. Apply heading

The style gallery's dropdown arrow at `976,67`, then `Heading 1` at `873,256`.

The popup is **anchored under the box and shows every style without scrolling**,
with the current one merely highlighted — so, like the Zoom list and unlike
AbiWord's style box, its coordinates do not move with the selection. It is also
an override-redirect popup that `xdotool search --onlyvisible` cannot see, so it
raises no window-matching problem either.

```text
Caption Figure Heading Heading-1 Heading-2 Heading-3 Normal Standard
Subtitle Table-Contents Table-Heading Text-body Title    Paragraph style...
```

`end state  style box reads Heading 1, Liberation Sans 22` — Heading 1's own
size replaces the 18 from block 11, which is what the other apps do too.

### 13. Insert image

`Ctrl+End`, `Return`, then the **Insert** ribbon tab at `136,15` and `Picture` at
`161,60`. That opens `[New picture]`, 993x487 at 224,251 — the same shape as the
Open dialog:

```text
  File name   553,584
  OK          811,584
```

`Save within document` is ticked by default, so the image is embedded and lands
in the ODT's `Pictures/` (verified: `pictures x13`).

Two things happen that have to be undone:

* the ribbon switches to a contextual **Picture** tab and the image is selected
  with handles;
* **`Escape` does not deselect it.** Measured — the handles and the Picture tab
  survive it.

A click in the body text at `700,800` deselects, returns the ribbon to Home and
puts the cursor at `L 19 Col 46`. `700,800` is below the image (whose bottom edge
is at y≈723 at this zoom), so it lands in text rather than re-selecting.

TextMaker inserts the picture as a **floating** object 19 x 12.19 cm, so it is
drawn over the text around its anchor rather than pushing it down — the same trap
OpenOffice has, where the inserted table renders underneath the image and the
screen shows nothing wrong.

`end state  L 19 Col 46 | Page 97 of 98`.

### 14. Insert table

`Ctrl+End`, `Return`, **Insert** tab at `136,15`, `Table` at `93,60`. `[New table]`
is 549x195 at 446,397 and defaults to **3 rows x 3 columns**, so the row count has
to be changed:

```text
  Rows      590,407     click, Ctrl+A, type 4
  Columns   770,407     click, Ctrl+A, type 3
  OK        918,410
```

Same `Ctrl+A` rule as the font-size box.

Then `Alpha` Tab `Beta` Tab `Gamma`.

```text
end state   L 1 Col 6 | Page 98 of 98 | 54636 words | cell indicator C1
            contextual Table ribbon tab active
```

### 15. Insert page break

`Ctrl+End` then `Ctrl+Return`.

One `Ctrl+End` is enough: unlike LibreOffice and OpenOffice, where the first one
only reaches the end of the table and `Ctrl+Return` there is a silent no-op, in
TextMaker it leaves the table and reaches the end of the document — confirmed by
the contextual Table tab disappearing and the cursor reading `L 23 Col 1`.

```text
Page 98 of 98  ->  Page 99 of 99
```

### 16. Undo and redo

`Ctrl+Z` then `Ctrl+Y`. `99/99 -> 98/98 (L 23 Col 1) -> 99/99 (L 1 Col 1)`.

### 17. Save

`Ctrl+S`. **No dialog**: TextMaker writes ODT natively and does not ask about
keeping the format. The `*` leaves the title, which is the confirmation.

### 18. Export PDF

The **File** ribbon tab at `23,15` — it is a tab, not a menu popup — then
`PDF export` at `489,60`.

```text
  [PDF export] options   785x581 at 328,204
    Export range = All is already selected, Pages reads 1-99
    OK      907,727
  [PDF export] file      993x487 at 224,251
    File name   720,617    click, Ctrl+A, type /tmp/parrot-report.pdf
    OK         1148,617
```

The file dialog already defaults to `/tmp` with `parrot-report.pdf`, because the
document lives there; the path is typed anyway so the block does not depend on
that.

```text
ok   pdf 99 pages, 9854 KiB (want 99)
```

99 = TextMaker's 97 plus the image page plus the page break, so
[`expected-pdf-pages`](expected-pdf-pages) carries **99**.

---

## Ground truth

Driven by hand through all eighteen blocks, then
`check-result.sh window-container 99`:

```text
  ok   Shearwater x120 (want 120)
  ok   Cormorant x0 (want 0)
  ok   typed: The kestrel circled above the reservoir befo...
  ok   typed: Three technicians logged the reading and fil...
  ok   typed: Nothing in the record explained the drop in ...
  ok   typed block carries a style (P11)
  ok   pictures x13 (want 13)
  ok   tables x4 (want 4)
  ok   table cell Alpha / Beta / Gamma
  ok   paragraphs starting a new page x13 (12 chapters + 1 inserted), from 2 break style(s)
  ok   pdf 99 pages, 9854 KiB (want 99)
RESULT PASS
```

`P11` is an automatic style; checked separately that it is the real thing rather
than the check being generous:

```xml
<style:style style:name="P11" style:family="paragraph" style:parent-style-name="Heading_20_1">
<text:h text:outline-level="1" text:style-name="P11">Nothing in the record ...
```

## Replay

`verify-app.sh freeoffice`, against a container rebuilt from
`usage_scenario.yml`:

```text
  PASS 18   FAIL 0
  worst RMSE:  0.00589256   0.00589256   0.00336435
  RESULT PASS
```

### Three checkpoints cannot tell "it worked" from "it did nothing"

`verify-app.sh` reports them, and they are worth stating rather than explaining
away:

```text
  freeoffice-check-006.png identical to the one before it
  freeoffice-check-016.png identical to the one before it
  freeoffice-check-017.png identical to the one before it
```

All three are blocks whose **end state is their start state**, so a perfect
replay and a completely dead one produce the same image. This is not new — every
app in the group has some — but FreeOffice has one more than the others:

| block | why identical | what covers it instead |
| --- | --- | --- |
| 6 Zoom | TextMaker already opens at 100 %, so 100 % -> 150 % -> 100 % ends where it began. LibreOffice and AbiWord open at Page Width, so their block 6 changes the screen. | **Nothing automated.** Verified by hand during the measuring pass; the 150 % state was captured and read. |
| 16 Undo and redo | `Ctrl+Z` then `Ctrl+Y` returns to block 15's state by definition. | `check-result.sh` counts 13 break-referencing paragraphs, which proves the **redo**. Nothing can prove the undo after the redo has run — true of every app here. |
| 17 Save | the pin rule strips window decorations, so the title bar is not in the capture and the `*` disappearing is invisible. | `check-result.sh` entirely: the saved ODT on disk is the proof. |

For comparison: LibreOffice has one such pair (18), AbiWord two (16 and 18),
OpenOffice none.
