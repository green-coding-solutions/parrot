# Gnumeric — measured landmarks

All eighteen blocks were driven by hand through a clean container and
`common/check-result.sh` reported **PASS** on what they left behind, before a
line of `drive-scenario.sh` was written.

Gnumeric 1.12.56-2build5, Ubuntu 24.04, 1440x900.

**Gnumeric is the reason this group is worth running as a group.** It is the only
entrant that is not descended from StarOffice, and in the first hour it found a
defect in the shipped workbook that LibreOffice had accepted through an entire
measuring pass, a recording and a replay verification. See *The workbook was
wrong and only this application said so*.

## The window

```text
WM_CLASS(STRING) = "gnumeric", "Gnumeric"
WM_WINDOW_ROLE:  not found
```

`pin-windows.sh gnumeric 1440 900` matches and pins to 0,0 — read back, not
assumed. `xdotool search --onlyvisible --class gnumeric` returns the window, so
one string serves both the pin rule and the capture.

## Fixed landmarks

| | |
| - | - |
| Name Box | `75,151` — **needs a TRIPLE-click**, see below |
| Menu bar, y=12 | File 19, Edit 59, View 103, Insert 154, Format 212, Tools 267, Statistics 330, Data 391, Help 438 |
| Sheet tabs, y=874 | Readings 55, Sites 143, Summary 232 |
| Grid | row 1 at y≈201 — about 65 px lower than Calc's, because Gnumeric stacks three toolbars |
| Status bar | selection aggregate at x≈1140–1360, y≈880 |
| Park position | `1100,700` |

### The Name Box APPENDS

The single most important difference from LibreOffice Calc. A single click into
Calc's Name Box selects its whole contents, so typing replaces the address.
Gnumeric's does not:

```text
click once, type A1:H20001   ->  name box reads  A352A1:H20001
                                 selection unchanged, Return does nothing
triple-click, type A1:H20001 ->  name box reads  A1:H20001
                                 status bar: Sum = 998310608.35
```

Nothing reports an error either way. This is the same shape as the word
processor group's FreeOffice spin box, where a triple-click did *not* select and
typed digits were appended, turning 12 and 18 into 1218 — the two applications
fail in opposite directions, and the wrong choice is silent in both.

`NAME()` in `drive-scenario.sh` therefore triple-clicks, and Calc's single-clicks.

## The blocks

### 1. Load app

`gnumeric` through the recorder's startcommand, about 30 s to an empty
`Book1.gnumeric`.

### 2. Open workbook

`Ctrl+O` opens `Open Spreadsheet File` (1096x822). Typing a path beginning with
`/` makes the GTK file chooser open its location entry automatically, so the
path can be typed straight in with no click and no `Ctrl+L`. `Return` opens it,
about 45 s. `Book1.gnumeric` is replaced, so there is still exactly one window.

### 3. Jump to end

`Ctrl+End` → **H20001**, read off the Name Box.

### 4. Freeze the header

`Ctrl+Home`, `Down` to A2, then View at `103,12` → **Freeze Panes** at `148,62`.
Relative to the cursor, as everywhere else in this group.

### 5. Page through

`Page Down` ×10 → **A352**, against Calc's A412: 35 rows per press rather than
41, because the extra toolbars leave a shorter grid. The script counts
keystrokes and never names a destination precisely so that this does not matter.

### 6. Switch sheets

`143,874` (Sites), `232,874` (Summary), `55,874` (Readings).

### 7. Sort

Name Box → `A1:H20001`, Data at `391,12` → **Sort...** at `415,37`.

The dialog (513,243 415x503) is not Calc's, and accepting it would sort the
wrong way:

* Range is `Readings!A1:H20001` — picked up from the selection, in Gnumeric's own
  `!` syntax.
* "Sort range has a header" is **already ticked**.
* **The Sort Specification is pre-populated with ALL EIGHT COLUMNS**, in sheet
  order. Pressing OK would sort by Date, then Site, then Sensor… — not by
  Reading. Calc pre-populates one key and Gnumeric pre-populates eight; neither
  says so.

So: **Clear** at `882,533` empties the specification, the reference field at
`658,658` takes `E1:E20001`, **Add** at `882,658` puts Reading in as the only
key, and **OK** at `878,699` runs it. About 20 s.

### 8. Enter formula

Name Box → `I2`, type `=ROUND(E2*F2,2)`, `Return`.

**The comma works here too.** Gnumeric stores it lower-cased —
`=round(E2*F2,2)` — which is cosmetic but does appear in the reference
screenshot, so do not read a difference from Calc's rendering as a defect.

### 9. Fill down

Name Box → `I2:I20001`, `Ctrl+D`. About 25 s.

**Do not trust the status-bar sum immediately after this.** It read
`Sum = 74641367.1` where `SUM(I2:I20001)` in a cell gives `74641377.6` — short by
exactly **10.5**, which is the value of I2, the fill's source cell. The
authoritative number is block 10's; the status bar is a useful signal everywhere
else in this group and specifically not here.

### 10. Total

Name Box → `K1`, type `=SUM(I2:I20001)`, `Return` → **74641377.6**.

Calc gives 74641377.67 for the same column. Both are right — see the half-cent
note below.

### 11. Recalculate

`F9`. About 15 s. Gnumeric has no separate "hard" recalculation.

### 12. Filter

Name Box → `A1:H20001`, Data at `391,12` → Filter at `415,112` → **Add Auto
Filter** at `653,111`. There is no keyboard shortcut.

The Category dropdown is at `442,202`. Its popup is a **plain single-select
list** — `(All)`, `(Top 10...)`, `(Custom...)` then the six categories — not
Calc's checkbox tree, so **Turbine** at `374,398` is one click and there is no
search box and no "untick All" step.

The popup is its own X window (`Gnumeric Spreadsheet`, 82x209 at 349,209) and it
carries the application's `WM_CLASS`, sorting **ahead** of the main window in
`xdotool search`. A checkpoint taken with it open would be an 82x209 photograph
of a dropdown. `CP()`'s size assertion covers it.

### 13. Clear filter

The same dropdown at `442,202`, then **(All)** at `370,223`. This restores every
row but **leaves the filter buttons in place**, where Calc's `Ctrl+Shift+L`
removes them. Both satisfy the script; the screenshots differ and should.

### 14. Format numbers

Name Box → `E2:E20001`, `Ctrl+1` → Format Cells (397,243 648x503), **Number** at
`454,342`.

**Gnumeric's Number category defaults to 0 decimal places, not 2.** The spinner's
`+` at `727,330` is clicked **twice**, and the field is read back as `2` before
OK at `993,699`. The `+` is used rather than typing into the field on purpose:
typing into a spin box is what silently produced `1218` in the word processor
group.

### 15. Replace all

Name Box → `A1`, `Ctrl+H` → `Search & Replace` (428,293 585x404).

**No scope trap here.** Gnumeric puts scope in an explicit group and defaults to
**Entire workbook**, where Calc silently scopes to the selection. The `A1`
selection is kept anyway so the two drivers stay the same shape.

`Search for` has focus: type `Cormorant`, click `Replace by` at `785,413`, type
`Shearwater`, **OK** at `961,649`. About 18 s, and **no results dialog** — where
Calc opens one reporting "500 results found" that has to be closed.

### 16. Insert chart

Summary tab `232,874`, Name Box → `A1:B7`, Insert at `154,12` → **Chart...** at
`181,137`.

Two things differ from Calc, and both would produce a plausible wrong result:

1. **The Graph Guru defaults to XY (scatter)**, not a bar chart. "Accepting the
   app's defaults" cannot produce what the script asks for, so **Column** at
   `504,301` is selected explicitly. It serialises as
   `chart:class="chart:bar"`, the same as Calc's default, which is what the
   ground truth reads.
2. **Insert does not insert.** `950,759` closes the guru and arms a placement
   tool; the chart appears only when the sheet is dragged. `300,230` →
   `820,520`. This is the same shape as Calligra Words' image shape tool in the
   word processor group — a wizard that finishes without producing anything.

Then a click at `1100,700` deselects it.

### 17. Save

`Ctrl+S`. **No format prompt** — Gnumeric writes the ODS back in place without
asking, despite `.gnumeric` being its native format. Confirmed rather than
assumed; the title's `*` clears.

### 18. Export PDF

Gnumeric has **no "Export as PDF"**. `Ctrl+P` opens the GTK print dialog
(420,237 601x516), which is the print-to-file route `script.md` allows for
exactly this case.

* **Print to File** at `503,301` has to be selected — it is the only printer and
  it is *not* selected on open, so the Print button starts insensitive.
* The **Gnumeric Print Range** tab at `697,232` defaults to **"Active workbook
  sheet"**. Left alone it exports the Summary sheet alone. **All workbook
  sheets** at `438,268`.
* **Print** at `996,701`.

There is **no file dialog**: Gnumeric derives the output name from the document
and writes `/tmp/parrot-ledger.pdf`, which is exactly where the ground truth
looks.

**11 pages**, against Calc's 9, from the same print ranges — carried in
`expected-pdf-pages`.

## Verification

`common/verify-app.sh gnumeric` — replayed into a container rebuilt from
`usage_scenario.yml`:

```text
PASS 18   FAIL 0
worst RMSE:  0.180904   0.0954784   0.0116242
RESULT PASS   (all 17 ground-truth assertions)
```

Two things in that summary are worth knowing before anyone re-runs it.

### Block 12's margin is the tightest in the group

`0.180904` against a `0.2` threshold. Every other checkpoint in this group sits
below `0.1` and most are at `0`, so this one is the only one that could plausibly
tip over on a different machine. It is the autofilter block: the residue is the
filter buttons' arrows and the row-header column, which Gnumeric repaints at
slightly different subpixel offsets depending on how far the scroll settled. If
it fails on another host, look at the diff before widening anything — a genuine
failure here looks completely different (a wrong category, or the dropdown
photographed instead of the sheet).

### Blocks 16, 17 and 18 are byte-identical to each other

```text
gnumeric-check-006.png identical to the one before it
gnumeric-check-011.png identical to the one before it
gnumeric-check-017.png identical to the one before it
gnumeric-check-018.png identical to the one before it
```

`verify-app.sh` flags runs of identical checkpoints because *a recording that
stopped doing anything replays perfectly*. Here all four pairs are genuine, and
the three-in-a-row at the end is the case the warning exists for — so it is worth
saying exactly why each one is real:

* **006 = 005.** Switch sheets ends back on Readings, and Gnumeric restores each
  sheet's scroll position, so the view returns to precisely where Page Down left
  it. The two intermediate sheets are never captured.
* **011 = 010.** A recalculation of already-correct values produces the identical
  screen. LibreOffice Calc has the same pair in the same place, for the same
  reason.
* **017 = 016.** `Ctrl+S` changes only the title bar's `*`, and the capture is of
  the client area.
* **018 = 017.** The print dialog opens and closes over an unchanged sheet.

**Only the ground truth separates 16 from 18**, and it does: the chart is in
`content.xml` and `/tmp/parrot-ledger.pdf` is 11 pages and 56 KiB. This is the
clearest demonstration in the group of why `check-result.sh` exists — three
consecutive screenshot checks pass here while telling you nothing at all.

## The workbook was wrong and only this application said so

The first shipped `parrot-ledger.ods` wrote the Summary sheet's cross-sheet
ranges as `[Readings.$D$2:$D$20001]`. OpenFormula requires a dot on **both**
endpoints — `[Readings.$D$2:.$D$20001]` — which is what LibreOffice itself
writes when it saves.

Gnumeric refused to open it:

```text
Summary!B7
Unable to parse 'SUMIF([Readings.$D$2:$D$20001];[.A7];[Readings.$E$2:$E$20001])'
  ('Invalid expression')
```

one modal per formula, before the window appeared. LibreOffice had accepted the
same file silently and computed every total correctly.

`generate_workbook.py --check` now asserts the syntax, and the group README
carries the general lesson: when four of six entrants share a lineage, their
agreement is not evidence.

## Two applications, two number systems, one ground truth

Neither of these is a defect and both would fail a naive checker:

**Serialisation.** Gnumeric writes `office:value="8.5899999999999999"` where
LibreOffice writes `8.59`. Comparing exact decimals fails on essentially every
cell of a correct sheet — including the shipped Reading and Factor columns the
run never touched. `check-result.sh` snaps every stored value to two decimals
before comparing anything.

**Half-cent ties.** `13.70 * 0.85` is `11.6450` exactly and
`11.644999999999999` in IEEE 754. Neither application is rounding a decimal;
both are rounding a double, and they disagree on about 700 of the 20,000 rows.
1,437 rows land on such a tie. `check-result.sh` accepts `ROUND_HALF_UP` or
`ROUND_HALF_DOWN` of the exact product and **nothing else**, so for the other
18,500-odd rows it remains a strict equality — which is what still catches a
fill-down that stopped early or drifted off its row.

The visible consequence is that the two applications' totals differ in the last
two digits: `74641377.67` in Calc, `74641377.60` here. K1 is checked against the
sum of the column actually present in the file, so both pass.

### The normalized variant

```text
usage_scenario_normalized.yml  PASS 18   FAIL 0   worst RMSE 0.180904   RESULT PASS
```

Identical RMSE to the unpadded run, including block 12's tight 0.18. Padding
inserts idle *before* each checkpoint, so it must not change what is on screen
when one fires — and here it does not.

## Through the Green Metrics Tool

```text
usage_scenario.yml             18 PASS / 0 FAIL   Run Benchmark phase 663.4 s
usage_scenario_normalized.yml  18 PASS / 0 FAIL   Run Benchmark phase 825.6 s
```

Gnumeric is the fastest of the three on its own pace and the busiest per unit
time — 16 against LibreOffice's 7 on container CPU utilization, and 82 MB of
disk reads against LibreOffice's 27 MB. That is the shape you would expect from
the one entrant that is a spreadsheet rather than a suite.

No energy figure: this machine's GMT config enables no CPU energy provider. See
the group README's *Through the Green Metrics Tool*.
