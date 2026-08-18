# Apache OpenOffice Calc — measured landmarks

All eighteen blocks were driven by hand through a clean container and
`common/check-result.sh` reported **PASS** on all seventeen assertions before a
line of `drive-scenario.sh` was written.

Apache OpenOffice 4.1.16-3, Ubuntu 24.04, 1440x900.

```bash
bash applications/spreadsheets/common/setup-container.sh openoffice --measure
```

Read [`../libreoffice/MEASUREMENTS.md`](../libreoffice/MEASUREMENTS.md) too —
several of its findings are properties of the harness rather than of any one
application. Read [`../gnumeric/MEASUREMENTS.md`](../gnumeric/MEASUREMENTS.md)
as well, because **AOO agrees with Gnumeric against LibreOffice** on the single
most dangerous landmark in this group.

## Three differences from LibreOffice Calc, all silent

AOO and LibreOffice are the same codebase forked in 2010. That makes the places
they have drifted apart much more dangerous than the places Gnumeric differs,
because a driver written for one *looks* like it should work on the other.

| | LibreOffice Calc | Apache OpenOffice Calc |
| - | - | - |
| Name Box on a single click | selects its contents | **appends to them** |
| `=ROUND(E2*F2,2)` | accepted | **Err:508** |
| `Ctrl+D` | Fill Down | **unbound — does nothing** |
| `Ctrl+H` | Find & Replace | **unbound — Ctrl+F does both** |

Not one of the four reports anything. Two of them leave a screen that looks
exactly like success.

## The window

```text
WM_CLASS(STRING) = "VCLSalFrame.DocumentWindow", "OpenOffice 4.1.16"
```

`pin-windows.sh VCLSalFrame.DocumentWindow 1440 900` matches and pins to 0,0 —
read back off the running window, not assumed:

```text
[Untitled 1 - OpenOffice Calc] X=0 Y=0 WIDTH=1440 HEIGHT=900
```

The word processor group measured AOO Writer's settled window as reporting plain
`VCLSalFrame`, with `VCLSalFrame.DocumentWindow` true only at map time. **Calc's
settled window reports the full string**, so here the property you can read off
a running application happens to be the one that works. Do not generalise from
that: the pin rule is evaluated at map time either way, and the value that
matters is the one the window carries *then*.

`xdotool search --onlyvisible --class openoffice` matches the res_class
`OpenOffice 4.1.16` and returns exactly the document window, which is what
`record-session.sh` passes as `--windowclass`. **Two different strings for one
window**, and neither works in the other's place.

## Fixed landmarks

| | |
| - | - |
| Name Box | `65,88` — **needs a TRIPLE-click**, see below |
| Menu bar, y=9 | File 15, Edit 45, View 78, Insert 116, Format 160, Tools 203, Data 240, Window 284, Help 327 |
| Sheet tabs, y=868 | Readings 101, Sites 150, Summary 200 |
| Grid | row 1 at y≈128 |
| Status bar | selection aggregate at x≈1000–1100, y=890 |
| Park position | `1100,700` |

The Properties **sidebar is open by default** down the right-hand side
(x≈1180–1400 plus a tab strip to 1435). That is what a user gets, so it is left
alone — it costs the grid about 260 px of width, which is why AOO shows columns
A–J where Gnumeric shows more.

### The Name Box APPENDS

```text
click once, type A1:H20001   ->  name box reads  A422A1:H20001
                                 selection unchanged, Return does nothing
triple-click, type A1:H20001 ->  name box reads  A1:H20001
                                 status bar: Sum=998310608.349896
```

Gnumeric's Name Box behaves identically and LibreOffice Calc's does not. So the
two applications that share a codebase disagree, and the two that share nothing
agree — which is the whole argument for measuring each entrant rather than
inheriting from the nearest relative.

`998310608.35` is the same figure Gnumeric reports for the same selection.

## The blocks

### 1. Load app

`soffice -calc`, about 35 s to an empty `Untitled 1`. Nothing to dismiss:
[`install.sh`](install.sh)'s profile has accepted the licence, completed the
first-start wizard and turned the update check off.

### 2. Open workbook

`Ctrl+O` opens **AOO's own** Open dialog (546x308 at 447,330), not GTK's. The
`File name` field is **empty and focused**, so the path is typed straight in —
no `Ctrl+L`, no click. `Return` opens it, about 50 s. `Untitled 1` is replaced,
so there is still exactly one window.

**No recalculation prompt and no ODF version modal.** The workbook is written as
ODF **1.2** precisely because AOO 4.1 implements 1.2 and puts an "ODF Version
Conflict" dialog in front of anything newer — whose default button runs an
online update check.

`Calc/Formula/Load ODFRecalcMode` is seeded in the profile as well. That key is
a LibreOffice 4.x addition and AOO 4.1 predates it, so it is very likely being
ignored; the observed behaviour — no prompt, Summary values present and correct
on open — is the same either way, and is what the recording depends on.

### 3. Jump to end

`Ctrl+End` → **H20001**, read off the Name Box.

### 4. Freeze the header

**Window > Freeze**, not View: Window at `284,9` → Freeze at `314,101`. Relative
to the cursor, so `Ctrl+Home` then `Down` to A2 first.

### 5. Page through

`Page Down` ×10 → **A422**: 42 rows a press, against Calc's 41 and Gnumeric's 35.
The script counts keystrokes and never names a destination, so this does not
matter — which is why it is written that way.

### 6. Switch sheets

`150,868` (Sites), `200,868` (Summary), `101,868` (Readings).

### 7. Sort

Name Box → `A1:H20001`, Data at `240,9` → **Sort...** at `261,77`.

The dialog (523x365 at 505,330) pre-populates **one** key — like Calc's, unlike
Gnumeric's eight — but it pre-selects **`Date`**, so pressing OK sorts the sheet
by date. Perfectly, and by the wrong column, and nothing says so.

`Reading` is the only column beginning with R, so **`r`** on the focused list box
selects it. That is one keystroke instead of a click on a dropdown that can
reposition itself under the pointer. **OK** at `762,655`, about 35 s.

**No "does the range have headings?" prompt.** AOO reads the header row from the
selection and offers the column *names* in the dropdown, which is itself the
confirmation that it did.

### 8. Enter formula

Name Box → `I2`, type **`=ROUND(E2*F2;2)`**, `Return`.

**The comma does not work.** `=ROUND(E2*F2,2)` produces

```text
Err:508      (error in bracketing / missing pair)
```

AOO 4.1 has no formula-separator option at all — the `Tools > Options > Calc >
Formula` panel that carries one in LibreOffice does not exist here. So the
semicolon is not a preference, it is the only thing that works.

This is the one place the driver types something different from what
[`../script.md`](../script.md) spells out. The script names the formula
`ROUND(E2*F2,2)`; the block is *"type the formula and press Enter"*, and the
argument separator is the application's, the same way block 18 is *"by whichever
route the app offers"*. Left as a comma, I2 shows `Err:508`, the fill-down
propagates it 20,000 times, K1 sums to an error, and the run still produces
eighteen plausible screenshots — the ground truth is the only thing that catches
it.

### 9. Fill down

Name Box → `I2:I20001`, then **Edit > Fill > Down**.

**`Ctrl+D` is unbound.** Not slow, not conditional — it does nothing at all. No
beep, no status message; the selection stays exactly as it was and only I2 holds
a value:

```text
selection I2:I20001, Ctrl+D, 30 s   ->  status bar: Sum=10.5      (= I2 alone)
selection I2:I20001, Edit>Fill>Down ->  K1 = 74641377.67
```

The Edit menu confirms it: `Fill ▸` carries no accelerator where `Find &
Replace` shows `Ctrl+F` two lines above it.

**Fill needs a click, not a hover.** A single `mousemove` onto it neither
highlights it nor opens its submenu; the pointer has to arrive in two steps and
then be clicked. That is what `MCLICK()` in the driver does, and Data > Filter
needs it too. About 50 s.

### 10. Total

Name Box → `K1`, type `=SUM(I2:I20001)`, `Return` → **74641377.67**.

To the cent the same as LibreOffice Calc. Gnumeric gives `74641377.60` from the
same column, and both are right — see the half-cent note in Gnumeric's file.

### 11. Recalculate

`Ctrl+Shift+F9`, the hard recalculation.

fluxbox's **default** keys file grabs `Control+F1..F12` for workspace switching
and would eat this without a word; `pin-windows.sh` writes a keys file with no
keyboard bindings at all, which is why it does not. Had it been eaten, the
display would have jumped to an empty workspace and *every* later checkpoint
would have failed loudly — which is the only reason this block is verifiable at
all, since a recalculation of correct values leaves the identical screen and the
identical file.

### 12. Filter

Name Box → `A1:H20001`, Data at `240,9` → Filter at `260,97` → **AutoFilter** at
`430,97`. No keyboard shortcut. Filter needs `MCLICK` for the same reason Fill
does.

The Category button is at `436,127`. Its popup is a **plain single-select list**
— `All`, `Top 10`, `Standard Filter...`, then the six categories — so **Turbine**
at `380,256` is one click: no checkbox tree, no search box, no "untick All" step.

The popup is an **override-redirect child of the document window**, not a
top-level. `xdotool search` never returns it, so unlike Gnumeric's 82x209 filter
dropdown it cannot be photographed instead of the sheet. `CP()`'s size assertion
still runs — AOO's *dialogs* share the document's res_class and could be.

### 13. Clear filter

The same button at `436,127`, then **All** at `360,144`. Every row comes back and
the filter buttons **stay**, as Gnumeric's do and unlike Calc's `Ctrl+Shift+L`,
which removes them. All three satisfy the script and the three screenshots
differ, correctly.

### 14. Format numbers

Name Box → `E2:E20001`, `Ctrl+1` → Format Cells (523x365 at 447,338).

**Number is already the selected category and Decimal places is 0.** The
spinner's `+` at `656,515` is clicked **twice** and the `Format code` field is
read back as `0.00` before **OK** at `704,663`. The `+` rather than typing into
the field on purpose: a typed value in a spin box is what silently produced
`1218` from 12 and 18 in the word processor group.

AOO writes this the same way LibreOffice does — as the **column's**
`default-cell-style-name` (`ce3`) with the number style in `styles.xml`, not as a
per-cell attribute. A checker that looks only at `content.xml` cell styles
reports 0 of 20,000 on a correctly formatted sheet; `check-result.sh` resolves
the whole chain.

### 15. Replace all

Name Box → `A1`, **`Ctrl+F`** → `Find & Replace` (390x252 at 525,346).

**`Ctrl+H` does nothing.** AOO reaches Find *and* Replace through `Ctrl+F`; the
word processor group measured the same in Writer, so it is suite-wide rather
than a Calc quirk.

`Search for` has focus: type `Cormorant`, click `Replace with` at `664,440`, type
`Shearwater`, **Replace All** at `853,453`. About 25 s.

**No scope trap.** "Current selection only" lives behind the collapsed **More
Options** and is not ticked, where Calc auto-ticks it the moment a multi-cell
range is selected. The single-cell `A1` selection is kept anyway so all three
drivers have the same shape.

**No results dialog** — Calc opens a "500 results found" box that has to be
closed. The Find & Replace window itself does stay up and is closed at
`853,553`, or the checkpoint photographs it.

### 16. Insert chart

Summary tab `200,868`, Name Box → `A1:B7`, Insert at `116,9` → **Chart...** at
`150,419`.

**The Chart Wizard opens on Column already selected**, so accepting the defaults
does produce what the script asks for — `chart:class="chart:bar"`, which is what
the ground truth reads. Gnumeric's guru opens on XY scatter and needs Column
chosen explicitly; this one does not.

**Finish** at `726,724` inserts it immediately — no placement tool to drag, which
Gnumeric does need. The chart is left in edit mode (the whole toolbar set
changes); the click at `1100,700` is what leaves it.

The Summary sheet is worth reading while it is on screen, because it is the only
place the shipped cross-sheet `SUMIF`s are visible:

```text
Intake 11285284.93   Conduit 11631881.84   Turbine    12639690.21
Spillway 13297596.61 Telemetry 14174120.47 Switchgear 11167725.94
All sites 74196300
```

### 17. Save

`Ctrl+S`. **No format prompt** — ODS is the native format. Confirmed by
`File > Save` going grey afterwards, not by how the screen looked.

### 18. Export PDF

**File > Export as PDF...** at `100,315`. Two dialogs, and the second one has the
trap.

**PDF Options** (702x373 at 369,285): Range is **All** by default. Calc's
equivalent defaults to "Selection/Selected sheet(s)" and quietly exports one
sheet. The one place the two forks could have shared a trap is a place they
differ. **Export** at `880,618`.

**Export** file dialog (546x308 at 447,330): directory already `/tmp`, `File
name` already `parrot-ledger`, format already PDF — and **the pre-filled name is
not selected**. Typing the path appended to it:

```text
first attempt  ->  /tmp/parrot-ledger.pdfparrot-ledger.pdf   (42194 bytes, no error)
```

A perfectly valid 9-page PDF, at a filename nothing would ever look for, and the
application reported success. Same shape as the Name Box, in a different dialog,
found the same way — by checking the filesystem rather than the screen. The
field is triple-clicked at `715,511` first.

**9 pages, 41 KiB** — identical to LibreOffice Calc, from the same print ranges.
Gnumeric gives 11.

## Ground truth after the hand-driven pass

```text
ok   sheets ['Readings', 'Sites', 'Summary']
ok   Readings rows 20001
ok   Reading non-decreasing over rows 2..20001 - the sort ran
ok   Reading is exactly the shipped set (0 differ)
ok   every Factor is one of the shipped factors
ok   column I holds x20000 formulas
ok   column I == ROUND(E*F,2) on every row (1437 half-cent ties allowed either way)
ok   K1 = 74641377.6700004 (want 74641377.67)
ok   Shearwater x500 / Cormorant x0
ok   Turbine rows x3400 - what block 12 filtered to
ok   hidden rows x0 - the filter was cleared
ok   E2:E20001 carry a two-decimal format x20000 [column style ce3]
ok   Readings carries a frozen split
ok   embedded chart x1 ['chart:bar']
ok   pdf 9 pages, 41 KiB
RESULT PASS
```

## Verification

```text
usage_scenario.yml             PASS 18   FAIL 0   worst RMSE 0        RESULT PASS
usage_scenario_normalized.yml  PASS 18   FAIL 0   worst RMSE 0        RESULT PASS
```

**Every checkpoint replays pixel-identical.** That is the best result in the
group — LibreOffice's worst is 0.0007 and Gnumeric's is 0.18 — and it is a
property of AOO's rendering rather than of the driver: nothing in its interface
carries an animation, a caret blink or a subpixel-positioned scroll residue at
the moment a checkpoint fires.

One identical pair, `006` = `005`: Switch sheets ends back on Readings and AOO
restores the sheet's scroll position, so the view returns to where Page Down
left it. Gnumeric does the same thing in the same block.

### The splash window loses a race, and it does not matter

The normalized run logged this before its first checkpoint, four times:

```text
X protocol error: BadWindow  resource_id = 0x0060000b   (X_ConfigureWindow)
[position-window] attempt 4: window is unknown, wanted 1440x900 — retrying
[position-window] WARNING: could not size window 6291467 to 1440x900
[position-window] WARNING: check-image will fail on a size mismatch …
```

`position-window` latched onto **AOO's splash screen**, which then unmapped
underneath it, and never got hold of the document window. Its warning says
check-image will now fail on a size mismatch.

**All eighteen checks then passed at RMSE 0.** The warning is correct about what
`position-window` failed to do and wrong about the consequence, because the
document window was already the right size: fluxbox's `[app]` rule pins it at
**map time**, before `position-window` runs at all, and `position-window` is the
belt to that pin's braces rather than the mechanism. The plain run did not hit
the race; the normalized one did, purely on timing.

Worth knowing in both directions — do not chase this warning on AOO if the
checks pass, and do not treat `position-window` succeeding as evidence the pin
rule is right, because here it is the pin that did the work.

**It is reproducible, not a fluke.** Four occurrences so far: the normalized
replay, and then the GMT runs of both the ordinary and the normalized scenario
(12 `BadWindow` lines in the last one). Every one of them still finished 18 PASS
/ 0 FAIL. AOO is the only entrant that shows a splash screen, which is why it is
the only one that races.

## Through the Green Metrics Tool

```text
usage_scenario.yml             18 PASS / 0 FAIL   Run Benchmark phase 813.2 s
usage_scenario_normalized.yml  18 PASS / 0 FAIL   Run Benchmark phase 827.8 s
```

Note the **total** run for the ordinary scenario is 1394.8 s against an 813 s
phase. The extra ten minutes is `install.sh` fetching the 180 MB Apache tarball
inside the run window — LibreOffice's and Gnumeric's apt installs are cached and
theirs is not. It is setup, not the benchmark, and it is one more reason to read
the *phase* time rather than the run time.

## What this application contributes to the group

The other five entrants are each obviously different from LibreOffice Calc, so
nobody would write their drivers by analogy. **AOO is the one that looks safe to
copy and is not.** Every one of its four traps — appending Name Box, semicolon
separator, dead `Ctrl+D`, dead `Ctrl+H` — is a place where the LibreOffice
driver runs to completion and produces a wrong file with a plausible screenshot.

Three of the four were found by reading the file or the status bar rather than
the screen. The fourth, `Err:508`, was visible — and only because the cell was
still on screen when the checkpoint was taken.
