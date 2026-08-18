# LibreOffice Calc — measured landmarks

**Complete. 18 PASS / 0 FAIL, worst RMSE 0.000703, ground truth PASS**, replayed
in a fresh container. Replay time 603.4 s across 1,224 waits.

One pair of identical consecutive checkpoints, and it is inherent rather than a
defect — see *Block 11 cannot be told apart by its screenshot* below.

Every coordinate `drive-scenario.sh` uses, measured against a container built by
`common/setup-container.sh libreoffice --measure` and verified one block at a
time. The whole eighteen-block sequence was driven by hand before anything was
recorded, and `common/check-result.sh` reported **17/17 PASS** on what it left
behind — so the driver below is a transcription of a session that is known to do
the work, not a guess at one.

LibreOffice Calc 4:24.2.7-0ubuntu0.24.04.6, Ubuntu 24.04, 1440x900.

## The window

```text
WM_CLASS(STRING) = "libreoffice", "libreoffice-calc"
WM_WINDOW_ROLE:  not found
```

`pin-windows.sh libreoffice 1440 900` matches on the res_name and pins the
document window to 0,0 1440x900 with no decorations — confirmed by reading the
geometry back, not assumed. `xdotool search --onlyvisible --class libreoffice`
returns the window, so the same string works for the pin rule and for the
capture. (It does not for every app in this group; see the group HANDOFF.)

Dialogs share the res_name and are all transient, so fluxbox centres them on the
screen and clamps them to their own maximum size. Measured positions below are
absolute screen coordinates read off a root capture.

## Fixed landmarks

| | |
| - | - |
| Name Box | `72,89` — **a single click selects its whole contents**, so typing replaces the address with no triple-click and no `Ctrl+A` |
| Menu bar, y=9 | File 15, Edit 47, View 82, Insert 123, Format 171, Styles 219, Sheet 264, Data 305, Tools 344, Window 392, Help 438 |
| Sheet tabs, y=864 | Readings 162, Sites 228, Summary 293 |
| Status bar | y=889. Selection summary at x≈900–1250 |
| Format as Number | toolbar `756,60` |
| Park position | `1200,700` — empty grid, far from every toolbar and dropdown |

**The status bar is the cheapest ground truth in the application** and was used
to verify almost every block as it was measured:

| After | Status bar reads | Meaning |
| --- | --- | --- |
| selecting A1:H20001 | `Sum: 998310608.349896` | the whole range, before the sort |
| the sort | `Sum: 998310608.349896` | unchanged — nothing was lost |
| the fill-down | `Sum: 74641377.6700004` | matches `generate_workbook.py --expected` exactly |
| the filter | `Selected: 3,401 rows` | 3,400 Turbine rows + the header |
| clearing it | `Selected: 20,001 rows` | every row back |

## The blocks

### 1. Load app

`soffice --calc` through the recorder's startcommand. About 45 s to a painted
grid in this container. Nothing to dismiss: the seeded profile turns off the
first-run wizard, Tip of the Day, the version infobar and document recovery.

### 2. Open workbook

`Ctrl+O`, type `/tmp/parrot-ledger.ods`, `Return`. The filename field has focus
when the dialog appears, so nothing is clicked. The empty `Untitled 1` window is
**replaced** rather than added to, so there is still exactly one window. About
40 s to a drawn grid.

No recalculation prompt: `ODFRecalcMode=1` in the profile. That is deliberate —
see `install.sh`.

### 3. Jump to end

`Ctrl+End` → **H20001**, confirmed in the Name Box. One press is enough; the
sheet has no table for the cursor to stop at.

### 4. Freeze the header

`Ctrl+Home`, then `Down` to put the cursor in A2, then View → **Freeze Rows and
Columns** at `171,323`. Freezing is relative to the cursor, so A2 freezes row 1
and nothing else. There is no keyboard shortcut for it in 24.2.

### 5. Page through

`Page Down` ×10 → **A412**. 41 rows per press, with row 1 frozen above.

### 6. Switch sheets

Click `228,864` (Sites), `293,864` (Summary), `162,864` (Readings). Each sheet
keeps its own scroll position, so Readings comes back at row 412.

### 7. Sort

Name Box → `A1:H20001`, then Data at `305,9` → **Sort...** at `337,30`.

The dialog opens at 516,290 (408x364) with:

* **"Range contains column labels" already ticked** — Calc detects the header
  row. Screenshotted rather than assumed, per AGENTS.md.
* Sort Key 1 = `Date`, **with focus**.
* Ascending already selected.

So the whole dialog is driven with **two keystrokes**: `r` selects `Reading`
(the only column beginning with R — `S` would be ambiguous between Site, Sensor
and Status), and `Return` presses OK.

That matters. The alternative is clicking the combo, which opens a popup that
positions the *selected* entry under the pointer — the failure that cost the
word processor group a pass on three separate applications. Typing the initial
letter into a focused listbox never opens the popup at all.

About 15 s for 20,000 rows. The view returns to the top.

### 8. Enter formula

Name Box → `I2`, type `=ROUND(E2*F2,2)`, `Return`. I2 shows **10.5**.

**The comma works.** This was the group's open question: an English (USA) locale
container takes `,` as the argument separator in the UI, so the typed string can
stay as `script.md` writes it. Confirmed in the formula bar, not inferred.

### 9. Fill down

Name Box → `I2:I20001`, then `Ctrl+D`. About 20 s. Status bar afterwards reads
`Sum: 74641377.6700004`.

### 10. Total

Name Box → `K1`, type `=SUM(I2:I20001)`, `Return`. Reselecting K1 shows
`74641377.67`.

### 11. Recalculate

`Ctrl+Shift+F9` (hard recalculation). About 10 s.

This is the keystroke that would be eaten by fluxbox's default keys file, which
grabs `Control+F1..F12` at the X server for workspace switching. `pin-windows.sh`
writes a keys file with no keyboard bindings at all, so it reaches the
application — verified by checking the window and K1 were still there afterwards
rather than on an empty workspace.

### 12. Filter

Name Box → `A1:H20001`, then `Ctrl+Shift+L` (Data → AutoFilter). Dropdown
buttons appear on every heading cell; the Category one is at `443,132`.

The popup opens with **the "Search items" box focused**, so typing `Turbine`
narrows the list to that one entry and ticks it — no checkbox coordinates, no
"untick All then tick one". OK at `485,513`. About 10 s.

### 13. Clear filter

`Ctrl+Shift+L` again. This removes the autofilter **and unhides every row** —
verified: consecutive black row numbers, buttons gone, `Selected: 20,001 rows`.

Worth stating explicitly because the equivalent through the UNO API does *not*
unhide, and the next block's replace-all then silently skips every hidden row.
See the group README.

### 14. Format numbers

Name Box → `E2:E20001`, then the **Format as Number** toolbar button at
`756,60`. One click; E2 goes from `10` to `10.00`.

Calc writes this as the **column's** default cell style rather than 20,000
per-cell styles, with the number style in `styles.xml` — which is why
`check-result.sh` resolves the whole chain instead of reading cell attributes.

### 15. Replace all

**Name Box → `A1` first.** This is not decoration:

> `Ctrl+H` opened with E2:E20001 still selected has **"Current selection only"
> TICKED**, because Calc ticks it whenever a multi-cell range is selected. The
> replace would then have searched column E, which contains no text at all,
> replaced nothing, and said so in a small dialog. Every screenshot would have
> looked correct.

With a single cell selected the box is unticked. Verified both ways.

Then: `Ctrl+H` (Find field has focus), type `Cormorant`, click the Replace field
at `733,365`, type `Shearwater`, click **Replace All** at `939,411`.

A **Search Results** window opens at 537,295 reporting **"500 results found"** —
exactly `ANCHOR_COUNT`, every hit in `Readings` column H. It has to be closed at
`837,597`, then Find and Replace at `950,627`. Two windows, both of which would
otherwise be in the next checkpoint.

### 16. Insert chart

Summary tab `293,864`, Name Box → `A1:B7`, Insert at `123,9` → **Chart...** at
`155,49`.

The Chart Wizard opens at 328,318 (783x307) with a live preview of all six
categories, `Column` selected and shape `Bar`. **Finish** at `948,584`.

`Column` is the default and ODF stores it as `chart:class="chart:bar"`, which is
what the ground truth looks for — so "a bar chart accepting the app's defaults"
needs no clicking in the type list.

Inserting a chart puts the **whole application into chart-edit mode**: the menu
bar loses Sheet, Data and Styles and the toolbars change. A click outside the
chart at `1200,700` leaves it. Without that the next checkpoint photographs a
different application.

### 17. Save

`Ctrl+S`. No format dialog — the workbook was opened as ODS and is saved as ODS.
643 KiB → 1.1 MiB. About 10 s.

### 18. Export PDF

File at `15,9` → **Export as PDF...** at `77,324`.

**PDF Options opens with Range = "Selection/Selected sheet(s)".** Left alone,
that exports the Summary sheet alone — a one-page PDF where the ground truth
expects nine. `All` at `412,313` first. This is the second silent default in the
script, and like the first it produces a plausible file rather than an error.

Then **Export** at `1004,619`, triple-click the file name field at `696,543`,
type `/tmp/parrot-ledger.pdf`, `Return`. The dialog already points at /tmp with
the right name and filter; the path is typed anyway so the driver does not
depend on it.

Result: **9 pages, 41 KiB**, matching the print ranges the workbook carries.

## Ground truth after the hand-driven pass

```text
ok  Reading non-decreasing over rows 2..20001 - the sort ran
ok  Reading is exactly the shipped set (0 differ)
ok  column I holds x20000 formulas
ok  column I == ROUND(E*F,2) on every row
ok  K1 = 74641377.67
ok  Shearwater x500 / Cormorant x0
ok  hidden rows x0 - the filter was cleared
ok  E2:E20001 carry a two-decimal format x20000 [column style ce3]
ok  Readings carries a frozen split
ok  embedded chart x1 ['chart:bar']
ok  pdf 9 pages
RESULT PASS
```

## Block 11 cannot be told apart by its screenshot

`libreoffice-check-011.png` is byte-identical to `010`, and no amount of care
would change that: a **hard recalculation of a workbook whose values are already
correct produces exactly the same screen, by definition**. Block 10 ends with K1
selected showing `74641377.67` and block 11 ends the same way.

The ground truth cannot separate them either, for the same reason — a
recalculation that never ran leaves the identical file. So block 11 is the one
block in this script that is verified only by the fact that the keystroke
reached the application, which was checked while measuring: fluxbox's default
keys file grabs `Control+F1..F12`, and had it eaten `Ctrl+Shift+F9` the display
would have jumped to an empty workspace and *every* subsequent checkpoint would
have failed, loudly.

This is the same shape as the word processor group's `check-018` being identical
to `017` for its PDF export. Expect one such pair per group and know which it is.

## The driver must press Pause

`drive-scenario.sh` ends with `K Pause`. Without it `record-macro.py` keeps
recording after the last block and `record-session.sh`'s `wait` never returns:
the log stops at "driver finished", every checkpoint has already fired, and
nothing anywhere says the recorder is still armed. It looks like a completed run
that has hung on the ground-truth check.

The keystroke does not land in the macro. `record-macro.py` stops on it and does
not emit the idle that preceded it, so the file ends exactly at the last `check`
with **0.0 s trailing** — measured on this recording, which sat idle for several
minutes between the last checkpoint and the Pause.

## Two things to carry to every other application in the group

1. **A dialog's default scope is the thing to check first.** Both silent
   failures found here were a default scope, not a wrong coordinate: Find and
   Replace scoped to the selection, and PDF export scoped to the current sheet.
   Neither reports an error and both leave a plausible screen.
2. **Prefer a focused control and a keystroke to any popup.** The Sort dialog's
   `r`, and the filter popup's search box, both remove a click on a list that
   could reposition itself under the pointer.

## Verification

```text
usage_scenario.yml             PASS 18   FAIL 0   worst RMSE 0.000703   RESULT PASS
usage_scenario_normalized.yml  PASS 18   FAIL 0   worst RMSE 0.000703   RESULT PASS
```

Re-verified against the **corrected** `parrot-ledger.ods` after Gnumeric found
the malformed OpenFormula ranges in the first one (new sha256 `4150ced6…`). The
recording was made against the pre-fix corpus and did not need re-recording: the
fix is in the Summary sheet's stored formulas, which none of the eighteen blocks
displays, so every reference screenshot is still exact. Confirmed rather than
assumed — worst RMSE is unchanged to six decimal places.

## Through the Green Metrics Tool

```text
usage_scenario.yml             18 PASS / 0 FAIL   Run Benchmark phase 615.2 s
usage_scenario_normalized.yml  18 PASS / 0 FAIL   Run Benchmark phase 826.6 s
```

No energy figure: this machine's GMT config enables no CPU energy provider. See
the group README's *Through the Green Metrics Tool*.
