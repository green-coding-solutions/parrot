# Benchmarking spreadsheets

Spreadsheet applications driven through the same eighteen-step working session
against the same generated 20,000-row workbook. Nothing is downloaded at
measurement time and the workbook is byte-identical on every machine, so a
recording made today replays identically next year and on another machine.

The corpus and the ground truth are built and verified: `generate_workbook.py`,
`parrot-ledger.ods` and `common/check-result.sh` are done and tested end to end
against a workbook LibreOffice really wrote (see *What was tested*).

**Six were planned; three are recorded and three are out.** None was dropped for
being awkward to drive. Each was dropped because the application cannot do
something the script asks for, and in each case the gap also breaks the ground
truth:

| Out | Why | Blocks lost |
| --- | --- | --- |
| **FreeOffice PlanMaker** | reads ODS and **cannot write it** — no OpenDocument entry anywhere in its Save-as file types | 17, and with it every assertion |
| **Calligra Sheets** | **no freeze panes** — no such action exists in the application at all | 4 |
| **Collabora Office** | **no modal dialog opens** in this container — not Sort, not Format Cells | 7, 14, 18 |

Each is written up below and in its own `MEASUREMENTS.md`, because each is a
decision about what the *group* measures rather than a per-app workaround, and
each is cheap to reverse if that decision changes. Their landmarks are measured
and kept.

**The three that remain — LibreOffice Calc, Apache OpenOffice Calc and Gnumeric
— are complete**: all eighteen blocks measured by hand, recorded, replayed in a
fresh container at 18 PASS / 0 FAIL, and passing all seventeen ground-truth
assertions. They are also a real comparison rather than a consolation one: two
forks of the same 2010 codebase, which disagree with each other more than either
expected, and one application sharing no code with either.

## Progress

| App | Install | Landmarks | Recorded | Replay-verified | Normalized | GMT |
| --- | --- | --- | --- | --- | --- | --- |
| LibreOffice Calc | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.000703, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| Apache OpenOffice Calc | ✅ 4.1.16-3 | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| Gnumeric | ✅ 1.12.56-2build5 | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.180904, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| SoftMaker FreeOffice PlanMaker | ✅ rev 3702 | ✅ 16/18 | ⛔ **skipped** | ⛔ cannot write ODS — [why](freeoffice/MEASUREMENTS.md) | — | — |
| Calligra Sheets (Flatpak) | ✅ 26.04.3 | ⚠ partial | ⛔ **skipped** | ⛔ no freeze panes — [why](calligra/MEASUREMENTS.md) | — | — |
| Collabora Office (Flatpak) | ✅ 26.04.2.4-2 | ⚠ blocks 1–6 | ⛔ **skipped** | ⛔ no dialog opens — [why](collabora/MEASUREMENTS.md) | — | — |

## Spreadsheets under test

| Spreadsheet | Licence | Version | Install source |
| ----------- | ------- | ------- | -------------- |
| [LibreOffice Calc](https://www.libreoffice.org/) | open (MPL 2.0) | pin to the 24.04 package, expected `4:24.2.7-0ubuntu0.24.04.6` | Ubuntu 24.04 `libreoffice-calc` |
| [Gnumeric](http://www.gnumeric.org/) | open (GPL 2.0) | 1.12.56-2build5 | Ubuntu 24.04 `gnumeric` |
| [Apache OpenOffice Calc](https://www.openoffice.org/) | open (Apache 2.0) | 4.1.16-3 | `archive.apache.org` deb tarball, pinned by SHA-256 |
| ~~[Calligra Sheets](https://apps.kde.org/calligrasheets/)~~ | open (GPL 2.0) | 26.04.3 | Flathub `org.kde.calligra`, pinned by OSTree commit — **dropped, see below** |
| ~~[Collabora Office](https://www.collaboraoffice.com/)~~ | open (MPL 2.0) | 26.04.2.4-2 | Flathub `com.collaboraoffice.Office`, pinned by OSTree commit — **dropped, see below** |
| ~~[SoftMaker FreeOffice PlanMaker](https://www.freeoffice.com/en/download/linux)~~ | **closed** | FreeOffice 2024, package rev 3702 | ~~upstream deb, pinned by SHA-256~~ — **dropped, see below** |

Five of the six were the same *packages* the word processor group already
installs and pins — `install.sh` changes only which component it launches and
which file it stages. Gnumeric is the one genuinely new install, and it replaces
AbiWord as the group's lightweight GTK entrant.

The spread was the point: two LibreOffice-lineage suites, one Qt suite, one
closed-source suite, one web-technology UI running offline, and one small native
GTK application that is not a suite at all.

What survived is narrower but not narrow: **two forks of one 2010 codebase and
one application that shares no code with either**. That turned out to be the
more interesting comparison, because the two forks disagree with each other on
four separate landmarks — see the Apache OpenOffice note below — while Gnumeric,
which shares nothing, agrees with OpenOffice against LibreOffice on the single
most dangerous one.

### FreeOffice PlanMaker is out, and the reason is worth reading

**PlanMaker cannot write OpenDocument.** It opens `parrot-ledger.ods` perfectly
and drove sixteen of the eighteen blocks correctly, but its Save-as file-type
list has 22 entries — `pmdx`, six Excel variants, `tmdx`, three legacy PlanMaker
formats, SYLK, RTF, HTML, dBASE, DIF, CSV and text — **and no ODF at all**. The
File tab offers PDF export and nothing else. Import is one-way.

So block 17 cannot happen, and every one of `check-result.sh`'s seventeen
assertions is about the file block 17 would write. Accepting its Save-as would
put the work in `/tmp/parrot-ledger.pmdx` and leave the shipped `.ods` untouched.

The two ways to keep it — save XLSX for this app only, or drop blocks 17 and 18
for this app — both change what the group measures, so neither was taken
unilaterally. Its landmarks are measured and recorded in
[freeoffice/MEASUREMENTS.md](freeoffice/MEASUREMENTS.md) against the day this
group runs a second pass in XLSX, where PlanMaker would be ready and only the
checker changes.

It is also the entrant that found the group's worst sort default: PlanMaker's
Sort dialog leaves *First row contains headings* **unticked**, so accepting it
sorts the heading row into the 20,000 data rows.

### Notes on the awkward ones

**Gnumeric** is the entrant most likely to change the script. It is the only one
here that is a spreadsheet rather than a suite, and it is fast — which is exactly
why it is worth measuring — but it has **no pivot tables**, its ODF export is a
non-default save format, and its formula UI uses Excel-style `Sheet!A1` cross-sheet
references where the ODF suites use `Sheet.A1`. See *Why the script looks the way
it does* for what each of those cost the script.

**Calligra Sheets** is out too, and for one missing feature: **it has no freeze
panes**. Not hidden somewhere unusual — *absent*. Its complete action list, read
out of Settings ▸ Configure Keyboard Shortcuts, has zero matches for `freeze`
and zero for `pane`; `split` returns only `Split Cells`, the merge-cells
inverse. So block 4 cannot happen and `check-result.sh`'s frozen-split assertion
cannot pass.

Everything else it was checked for is there — `Auto-Filter`, `Export as PDF`,
`Recalculate Document` on `F9` — and the README's prediction that charts would
go through the shape tool rather than a wizard is confirmed by the action list
(`Chart editing`, no wizard). Its landmarks are in
[calligra/MEASUREMENTS.md](calligra/MEASUREMENTS.md), including the two-window
trap: three X windows exist, two of them are called `Calligra Sheets`, and only
one is 1440x900.

It also holds the group's only cursor difference: `Ctrl+End` lands on **I20002**,
one row and one column *past* the last used cell, where every other entrant
lands on H20001.

**Collabora Office** is out, and it is the only one of the three whose blocker
might be environmental rather than a property of the application. **No modal
dialog opens.** Sort waited 65 s and never appeared; Format Cells never
appeared; the same is true on a three-cell selection, which rules out the
20,000 rows being the cause. Meanwhile the application stays fully responsive
throughout — the ribbon switches tabs, the grid scrolls, `Ctrl+End` works, and
the *Qt* file dialog (a real window, not a JSDialog) opens fine. Blocks 7, 14
and 18 all need a dialog.

Its dialogs are JSDialogs — LibreOffice dialogs serialised to JSON and re-drawn
by the web UI — and the log carries `WebGL2 blocklisted`, which is the first
thing to look at if anyone picks this up. Notably the word processor group drove
Collabora through all eighteen of its blocks in this same image, so the fault is
narrower than "Collabora in a container".

What *was* confirmed: the Viewing-to-Editing mode switch belongs to block 2, its
Name Box **appends** like Gnumeric's and AOO's, `Ctrl+End` gives H20001, the
freeze works (though its popup does not close itself and swallows keystrokes
until `Escape`), and `xdotool` needs `--class collabora` where fluxbox needs
`coda-qt`. See [collabora/MEASUREMENTS.md](collabora/MEASUREMENTS.md).

**Apache OpenOffice** is the reason the workbook is ODF **1.2** rather than 1.3.
It implements 1.2 and throws a modal "ODF Version Conflict" at anything newer,
which cost the word processor group a pass. The generator writes 1.2 and every
other app reads it without complaint.

It is also the entrant that looks safest to copy from LibreOffice Calc and is
not. Measured, in a codebase forked from Calc's in 2010: its Name Box
**appends** where Calc's selects, `=ROUND(E2*F2,2)` gives **Err:508** because
the argument separator is `;` and 4.1 has no option to change it, **`Ctrl+D` is
unbound** so Fill Down is a menu walk, and **`Ctrl+H` is unbound** so Find and
Replace is `Ctrl+F`. Every one of those leaves the LibreOffice driver running
to completion against a wrong file. See
[openoffice/MEASUREMENTS.md](openoffice/MEASUREMENTS.md).

### Considered and not included

| | Why not |
| - | ------- |
| ONLYOFFICE Spreadsheet | Installs and then aborts before Qt starts. Ruled out in the word processor group; nothing about the spreadsheet component changes that. |
| WPS Office Spreadsheets | Dropped from the word processor group for having no OpenDocument importer. If this group ever runs a second pass in XLSX, WPS is the first application to add back. |
| Microsoft Excel | No native Linux build. Wine or the browser measures something else. |
| Google Sheets, Excel for the web | Browser plus network. Non-reproducible, and it would be measuring the browser. |
| Pyspread, sc-im, GNU Oleo, Teapot | No overlap with the script — no charts, no autofilter, and in two cases no GUI at all. |
| SIAG Office | Not packaged for Ubuntu 24.04. |

Popcon figures go here once pulled from <https://popcon.debian.org>, the way the
other groups carry them. Expect the same lopsidedness: `libreoffice-calc` against
`gnumeric` is the only comparison with real numbers on both sides.

## The workbook

`parrot-ledger.ods` is committed, the way the word processor group commits
`parrot-report.odt` and the PDF group commits `20yearsofKDE.pdf`.
`generate_workbook.py` is what produces it, so it can be changed and rebuilt
rather than hand-edited — deterministic from a fixed seed, with frozen zip
timestamps and nothing read from the clock or the network.

Three sheets:

| Sheet | Contents |
| ----- | -------- |
| `Readings` | 20,000 data rows plus a heading row. A `Date`, B `Site`, C `Sensor`, D `Category`, E `Reading`, F `Factor`, G `Status`, H `Note` |
| `Sites` | 40 rows mapping site code to name and region — the lookup table, and the reason `Readings` carries no region column |
| `Summary` | A1:B7, a heading row and six `SUMIF` formulas over the 20,000 rows of `Readings`, one per category, with a grand total in B9 |

The properties the script depends on, all asserted by `generate_workbook.py --check`:

| | |
| - | - |
| Column E (`Reading`) | **every value unique**, so the sort in block 7 has one correct answer and produces the same screen in every app |
| Column D (`Category`) | six values; `Turbine` appears an exact, known number of times, which is what block 12 filters to |
| Column H (`Note`) | `Cormorant` exactly 500 times and `Shearwater` zero times — the replace-all anchor, in a column nothing else keys on |
| Cross-sheet formulas | only in `Summary`, written by the generator in ODF form. Nothing the script *types* crosses a sheet |
| Print ranges | set in the file, so the PDF export is bounded and the same shape everywhere |
| Page setup | landscape, pinned in the file rather than inherited from the app |
| ODF version | 1.2, for Apache OpenOffice |
| Size / sha256 | 632 KiB, `4150ced6b60b65d48760eaaaa91f0efd1df3beee10a27e756fa1babb08b5c94e` |

Ties in the sort key and cross-sheet references in typed formulas are the two
things that would quietly make this group incomparable, and both are designed out
rather than worked around. Neither is recoverable from looking at the workbook.

**20,000 rows was the one number that had to be settled before the first
recording, and it is settled.** It is chosen so that sort, fill-down and
recalculation cost real measurable work rather than rounding error. Three
applications have now run the whole script against it — LibreOffice Calc,
Gnumeric and Apache OpenOffice Calc — and in all three the fill-down and the
recalculation are among the most expensive blocks, which is exactly what the
number is for. Calligra Sheets was the entrant most likely to find it too large;
if it does, that is a finding about Calligra, not a reason to change the corpus.
Changing it now would invalidate every recording, every reference screenshot and
the whole ground truth, because the script names ranges by address.

### What check-result.sh asserts

The ground truth is the saved `.ods` and the exported PDF, not the screenshots.
Seventeen assertions, all of them things the screenshots cannot see:

* column E non-decreasing **and** exactly the set of values the workbook
  shipped — in order says the sort ran, the set says nothing was lost getting
  there, and a sort of column E alone would pass both;
* I2:I20001 all hold formulas, and each value equals `ROUND(E*F,2)` of the same
  saved row — which is what catches the columns coming apart, and is why the
  check needs neither the seed nor the sort order;
* K1 equals that sum, within a tolerance: the apps sum 20,000 doubles in
  whatever order they please;
* `Shearwater` × 500, `Cormorant` × 0;
* E2:E20001 resolve to a data style with two decimal places, **through the
  column's default cell style as well as the cell's own**, in `styles.xml` as
  well as `content.xml`;
* no row carries `table:visibility="collapse"` — the filter really was cleared;
* `settings.xml` records `VerticalSplitMode=2` on `Readings`;
* an embedded object exists whose content parses to a `chart:chart` — parsed,
  not substring-matched;
* the PDF exists and has the expected page count for that app.

Two structural things it has to do that the word processor group's did not, and
that are silent when wrong: expand `table:number-columns-repeated` and
`table:number-rows-repeated` before reading anything (every app compresses them
differently, so column E is at a different index in each file), and cap the row
expansion, because a trailing row can claim to repeat to the end of the sheet —
a million rows in most of these apps and sixteen million in Gnumeric.

## What was tested

### The workbook opens, paginates and computes

Converted with LibreOffice 25.8.7.3 to confirm the hand-written ODF is valid:
**9 pages, 455 KiB**, all eight columns on one page width, dates rendering as
dates. That 9 is the starting value for `expected-pdf-pages`; it has to be
re-measured per app.

The `SUMIF` formulas were checked by **zeroing every cached value, forcing
recalculation on load, and reading the sheet back**. All six category totals and
the grand total came back identical to the generator's own figures — so the ODF
formula syntax is right, and not merely displaying a cached number that happens
to be correct.

### The ground truth was tested against a real save, not a hand-built file

`check-result.sh` was written against what the ODF *should* look like and then
run against a workbook produced by driving LibreOffice through the scenario's
mutations over UNO — sort, formula, fill-down, total, recalculate, filter,
clear, format, replace, chart, freeze, save, export. It reported **five failures
on its first run, four of which were the checker being wrong**, which is the
whole reason for doing this before recording rather than after:

| Reported | Actually |
| --- | --- |
| two-decimal format on 0 of 20,000 cells | LibreOffice applied it as the **column's** default cell style, with the number style in **styles.xml**. The cells carry no style attribute at all. A per-cell check of `content.xml` sees nothing on a correctly formatted sheet |
| no frozen split | An artefact of loading the document `Hidden=True`, which writes a `settings.xml` with no `Views` block. Loaded normally it is there |
| PDF 4 pages, not 9 | Correct, and a consequence of the next row |
| `Shearwater` × 88, not 500 | **Correct, and the most useful result of the exercise.** Clearing the filter fields through the API does not unhide the rows, and **replace-all then silently skipped every hidden row** — 88 of 500, spread evenly across all five note variants so nothing about the result looked partial |

The last one is the shape of defect this project keeps producing: a plausible
screen, a confirmation dialog reporting a number, and the wrong work done. It is
also why block 13 exists as a block of its own and why `hidden rows == 0` is
asserted rather than assumed.

Everything passes now, seventeen for seventeen.

### Gnumeric found a bug in the workbook that five applications would not have

The first shipped workbook wrote the Summary sheet's cross-sheet ranges as
`[Readings.$D$2:$D$20001]`. The correct OpenFormula — and what LibreOffice
itself writes when it saves — puts a dot on **both** endpoints:
`[Readings.$D$2:.$D$20001]`.

| | |
| --- | --- |
| LibreOffice | accepted it silently and computed every total correctly, through an entire measuring pass, a recording and a replay verification |
| Gnumeric | refused it outright — `Unable to parse 'SUMIF([Readings.$D$2:$D$20001];[.A7];[Readings.$E$2:$E$20001])' ('Invalid expression')` — one modal per formula, before the window even appeared |

The lenient majority is the danger, not the strict minority. Four of the six
entrants are StarOffice-descended and would all have accepted it; had the group
been picked any less diversely, a malformed corpus would have shipped and the
only symptom would have been that nobody else could open it.

`generate_workbook.py --check` now asserts that every range in every formula is
dotted at both ends, so it cannot regress.

This is also the clearest argument for the group's composition: **Gnumeric earns
its place by not being a LibreOffice.**

### The print range attribute is not the formula syntax

The first generated workbook exported a **718-page, 44 MiB** PDF. The print
ranges were written as `[Readings.$A$1:$H$201]`, the bracketed form that
*formulas* use; `table:print-ranges` takes a plain cell-range-address-list,
`Readings.A1:Readings.H201`. LibreOffice does not complain, does not warn, and
prints the whole used range. The only symptom is the page count.

The page setup is pinned in the file for the same class of reason: left to
LibreOffice's default portrait A4, eight columns at 20.8 cm against 17 cm of
printable width put G and H onto pages of their own, and *where* an application
breaks a column is a per-app decision that would move the page count for reasons
having nothing to do with the application's work.

## The harness

`common/` is the word processor group's harness with the paths changed:

```text
common/
├── setup-container.sh   rebuild window-container from an app's usage_scenario.yml
├── pin-windows.sh       deterministic window geometry, and no window-manager key grabs
├── install-flatpak.sh   pinned Flatpak install, running the app as uid 1001
├── measure.sh           helpers for measuring landmarks by hand
├── check-result.sh      ground truth: what the run left on disk
└── verify-app.sh        replay in a fresh container, report RMSE and ground truth
```

```bash
# rebuild the workbook (only if you change it - it is committed)
./applications/spreadsheets/generate_workbook.py
./applications/spreadsheets/generate_workbook.py --check
./applications/spreadsheets/generate_workbook.py --expected   # what a run must leave
```

Everything in [`../wordprocessors/HANDOFF.md`](../wordprocessors/HANDOFF.md)
applies here unchanged and should be read before the first measuring pass. The
parts that will bite this group in particular:

* fluxbox grabs `Control+F1..F12` unless `pin-windows.sh` writes a keys file with
  no keyboard bindings — and `Ctrl+F9`/`Shift+F9` are recalculation shortcuts;
* fluxbox matches `res_name` at **map** time and xdotool matches `res_class`, and
  they are not always the same string. Read the geometry back;
* dropdowns, tooltips and dead dialogs carry the application's own `WM_CLASS` and
  sort *ahead* of the main window, so a checkpoint can photograph one. `CP()`
  asserts 1440x900 before every checkpoint;
* toolbar combo boxes are a trap in three of these apps and the equivalent dialog
  is fine;
* the shortcut you are sure of is the one that costs a pass. Read the
  accelerators off the app's own menus before writing any into a driver.

Two scenarios per app, as in the other groups: `usage_scenario.yml` replays
`<app>.parrot` and answers "what does this app cost at its own pace";
`usage_scenario_normalized.yml` replays `<app>-normalized.parrot`, padded by
`tools/check_blocks.py --normalize-time` so every block occupies identical
wall-clock in every app, and is **the only one of the two that compares apps**.

## Why the script looks the way it does

The rule is the intersection, not the union: **every step must be something all
six can do.**

* **The grid is portable and the layout is not.** Unlike a paginated document,
  a spreadsheet has an absolute address space that is identical in all six apps —
  `I2:20001` means the same cells everywhere. So the script names cells, and
  every selection goes through the **name box** rather than through a drag or a
  `Ctrl+Shift+Down`. Dragging depends on rendered row heights; `Ctrl+Shift+Down`
  from a cell with nothing under it runs to the sheet's last row, and the six
  apps do not agree on how many rows a sheet has.
* **Typed formulas never cross a sheet.** `=ROUND(E2*F2,2)` and
  `=SUM(I2:I20001)` are byte-identical in all six. A `VLOOKUP` into `Sites`
  would not be: the ODF suites write `Sites.A2` and Gnumeric writes `Sites!A2`,
  so "the same" typed text is a different formula in different apps — the same
  problem the code editors had with auto-close, solved the same way, by not
  typing anything the apps disagree about. The cross-sheet work stays in
  `Summary`, where the generator writes it once in ODF form.
* **Autocomplete is off in the profile wherever a profile can carry it.** Cell
  autoinput completes a typed entry from other cells in the column and function
  autocomplete completes a typed function name, and in both cases the `Enter`
  that ends the entry commits the *suggestion*. This is the code editors'
  autocomplete problem again.
* **Recalculation on load is off, and recalculation gets its own block.** Left
  on, an unknown amount of the workbook's formula graph is evaluated inside
  block 2 in some apps and not others, and "open a file" stops meaning the same
  thing. Off, block 2 measures a load and block 11 measures a recalculation.
* **The container locale is fixed.** `ROUND(E2*F2,2)` parses as one argument in
  a locale where the comma is the decimal separator. Nothing about the workbook
  or the script is safe under a locale change.
* **The argument separator is the application's, not the script's.** Block 8
  names the formula `=ROUND(E2*F2,2)` and LibreOffice Calc and Gnumeric both
  take it. **Apache OpenOffice Calc does not** — it answers `Err:508`, and 4.1
  has no formula-separator option to change that, so its driver types
  `=ROUND(E2*F2;2)`. Same formula, same result in the file, same thing a user
  would do; the block is "type the formula", the way block 18 is "by whichever
  route the app offers". Each driver's separator is recorded in its
  `MEASUREMENTS.md`.
* **The sort key is unique.** With ties, a stable and an unstable sort produce
  different rows in the same place, the reference screenshots stop being
  comparable across apps, and the ground truth can only assert monotonicity.
* **The sort happens before any formula is entered.** Sorting A1:H20001 while
  column I holds formulas that reference column E of the same row is a real
  spreadsheet bug, it is silent, and it would land differently in each app
  depending on whether the app widens the sort range for you.
* **The chart is drawn from six summary rows, not from 20,000.** Charting the
  full data range is not what anybody does and would be pathological in at least
  two of these apps. Six rows still exercises the chart engine and stays
  bounded.
* **The PDF comes out by whichever route the app offers**, and the workbook
  carries print ranges so the export is bounded. Per-app page counts go in
  `<app>/expected-pdf-pages`, as in the word processor group.
* **Every step is one line, however long.** `record-macro.py` skips blank and
  `#` lines and nothing else, so a step continued on a second line becomes its
  own checkpoint and every label after it attaches to the wrong block.
* **There is no "close the app" step.** A checkpoint is a screenshot of the
  application window, so a block whose action destroys that window has nothing
  to photograph. The script ends at Export PDF.

### Considered and left out of the script

| | Why |
| - | --- |
| Pivot table | The most characteristic spreadsheet operation there is, and **Gnumeric has none**. Keeping it means dropping Gnumeric; the intersection rule says drop the step. |
| Conditional formatting over 20,000 cells | Real, heavy, and a completely different dialog in all six. Block 14 already measures what mass reformatting costs. |
| A separate data-entry block | Typing is already covered by blocks 8 and 10, and free text typed into a column is exactly what triggers cell autoinput. |
| Goal Seek, Solver, statistical tools | Not present, or not comparable, across all six. |
| Macros | Different language in every app. |
| A second XLSX pass | The same open question the word processor group left on DOCX: Apache OpenOffice cannot write it. It would add WPS back and drop OpenOffice, so it is a different comparison rather than a re-run of this one. |

## What the recordings cost, block by block

`python3 tools/check_blocks.py applications/spreadsheets`, over the recorded
apps. **All eighteen blocks are defined in the same order in every file** — that
check is the point of the table, and it is what makes the columns comparable at
all.

| Block | Gnumeric | LibreOffice | OpenOffice |
| --- | --: | --: | --: |
| Load app | 51.4 | 66.5 | 51.5 |
| Open workbook | 62.9 | 55.9 | 67.9 |
| Jump to end | 13.3 | 13.3 | 13.3 |
| Freeze the header | 16.6 | 16.6 | 16.6 |
| Page through | 14.9 | 14.9 | 14.9 |
| Switch sheets | 21.0 | 21.0 | 21.0 |
| Sort | 59.3 | 45.5 | 65.2 |
| Enter formula | 15.6 | 15.4 | 15.6 |
| Fill down | 46.4 | 41.3 | 80.8 |
| Total | 20.7 | 18.4 | 22.7 |
| Recalculate | 23.3 | 28.3 | 48.3 |
| Filter | 49.8 | 44.7 | 61.0 |
| Clear filter | 26.4 | 18.3 | 33.4 |
| Format numbers | 42.9 | 23.8 | 48.7 |
| Replace all | 48.0 | 46.1 | 63.6 |
| Insert chart | 55.6 | 48.1 | 60.3 |
| Save | 23.2 | 23.3 | 33.3 |
| Export PDF | 60.7 | 62.1 | 81.6 |
| **Total** | **652.0** | **603.4** | **799.6** |

**These are recording durations, not application timings.** Each block's wall
clock is the app's work *plus* the driver's fixed waits, and the waits are sized
per app to whatever that app needed while being measured — so a block where all
three agree to a tenth of a second (Jump to end, Page through, Switch sheets) is
one where the driver's sleeps dominate and nothing is being measured but the
sleep. Blocks where the numbers separate — Fill down at 41/46/81, Recalculate at
23/28/48 — are separating because the applications really did differ.

The like-for-like comparison is the **normalized** variant, where every block is
padded to the longest across the group so each app is given identical wall clock
per block and the energy figure is what differs.

```bash
python3 tools/check_blocks.py applications/spreadsheets --normalize-time
bash applications/spreadsheets/common/verify-app.sh <app> --normalized
```

It is generated once every app is recorded, not before — **adding or
re-recording one app changes the padding in all of them**. Each app then carries
a second scenario, `usage_scenario_normalized.yml`, identical to its ordinary
one except for which `.parrot` it replays: same container, same setup-commands,
same reference screenshots, same ground truth.

All three are verified in that form as well:

| App | Normalized replay |
| --- | --- |
| LibreOffice Calc | 18 PASS / 0 FAIL, worst RMSE 0.000703, ground truth PASS |
| Apache OpenOffice Calc | 18 PASS / 0 FAIL, worst RMSE 0, ground truth PASS |
| Gnumeric | 18 PASS / 0 FAIL, worst RMSE 0.180904, ground truth PASS |

The RMSE figures are identical to the unpadded runs, which is the result to
want: padding inserts idle before each checkpoint and must not change what is on
screen when it fires.

## Through the Green Metrics Tool

All six scenarios — three ordinary, three normalized — have been run end to end
on the local GMT, and all six report `>>>> MEASUREMENT SUCCESSFULLY COMPLETED
<<<<` with **18 `PASS ref=` and 0 `FAIL ref=`**. GMT exits 0 even when a flow
fails, so those three counts are what a run is judged by, not the exit code.

```bash
docker rm -f window-container          # GMT refuses to start if one is up
cd /home/didi/code/green-metrics-tool && venv/bin/python runner.py \
  --uri /home/didi/code/parrot \
  --filename applications/spreadsheets/<app>/usage_scenario.yml \
  --dev-no-sleeps --dev-no-system-checks=check_ssh_session
```

`--dev-no-system-checks=check_ssh_session` is required on this machine, or
`runner.py` aborts on `/etc/ssh/sshd_config` before the scenario starts. None of
these three scenarios carries `docker-run-args`, so `--allow-unsafe` is not
needed — it would be for the two Flatpak entrants, which is one more reason
their absence simplifies the group.

Run IDs from the pass recorded here, at
`http://metrics.green-coding.internal:9142/stats.html?id=<id>`:

| | ordinary | normalized |
| --- | --- | --- |
| LibreOffice Calc | `62cfe6e5-39eb-4e01-967c-a18da450e92e` | `520b501b-7d24-4536-a10d-b3a984bc6b81` |
| Apache OpenOffice Calc | `51877fab-58b4-41a4-88a4-4351438d9f30` | `19eda2e0-0add-4b05-9a02-028ffb106bf5` |
| Gnumeric | `0f052b74-680b-4301-ada9-03e8f0f24256` | `65dd2c90-bee2-4f3f-a45b-b9f2d3872df3` |

### Run Benchmark phase, ordinary against normalized

| | LibreOffice | OpenOffice | Gnumeric | spread |
| --- | --: | --: | --: | --: |
| **ordinary** | 615.2 s | 813.2 s | 663.4 s | **198.0 s** |
| **normalized** | 826.6 s | 827.8 s | 825.6 s | **2.2 s** |

That is the normalization working, measured rather than assumed: three
applications given the same wall clock to within 2.2 seconds over a
fourteen-minute run, where their own pace differs by more than three minutes.
Everything left in the comparison is what the application did with that time.

### What the ordinary runs say about the applications

| | LibreOffice | OpenOffice | Gnumeric |
| --- | --: | --: | --: |
| CPU utilization (container) | 7 | 11 | 16 |
| Memory used | 479 MB | 431 MB | 539 MB |
| Disk read | 27.4 MB | 15.1 MB | 82.3 MB |
| Disk write | 11.7 MB | 24.2 MB | 5.2 MB |

Gnumeric is the interesting column: it is the *fastest* of the three on its own
pace and the *busiest* per unit time, which is what you would expect from the
one application here that is a spreadsheet rather than a suite. Its 82 MB of
reads against LibreOffice's 27 MB is worth a look before anyone quotes it.

### There is no energy figure yet, and that is a config gap

**This machine's GMT enables no CPU energy provider.** `config.yml` lists only
`cpu_utilization_procfs_system`, `cpu_utilization_cgroup_container`,
`memory_used_cgroup_container`, `network_io_cgroup_container` and
`disk_io_cgroup_container` under `metric_providers.linux`. The only metric with
`energy` in its name is `network_energy_formula_global`, which is a **formula**
over bytes transferred rather than a measurement, and it reads 1.6–1.8 mJ across
all three — noise from the same container pulls.

So these runs prove the scenarios measure cleanly and give a real resource
comparison, and they cannot answer the question the group exists for. Joules
need `cpu_energy_rapl_msr_component` or a PSU provider enabled, and a quiet
machine: GMT warned `You have other containers running on the system` on every
one of these six runs.

## Still open

Three of the questions this group opened with are now settled, and the three
that remain are all the same question in different clothes: **how much may the
script bend for one application before the group stops being a comparison?**

### Settled

1. **20,000 rows.** The one number that had to be fixed before the first
   recording. Three applications have run the full script against it; sort,
   fill-down and recalculation are among the most expensive blocks in all three
   and none of them struggled. It stays.
2. **The argument separator, and it is not uniform.** LibreOffice Calc and
   Gnumeric take `=ROUND(E2*F2,2)`; **Apache OpenOffice answers `Err:508`** and
   needs `;`, with no option in 4.1 to change it. FreeOffice PlanMaker takes the
   comma. Rather than degrade block 8 to a single-argument formula for everyone,
   each driver types its own application's separator and records which — the
   same treatment block 18 already gives the PDF route.
3. **Gnumeric's ODF export is faithful enough.** It writes the ODS back in place
   with no format prompt, and what it writes passes all seventeen assertions,
   including the frozen split and the embedded chart.

### Open, and each one is a decision about the group

1. **Block 17 in ODS, or a second pass in XLSX.** ODS is the only format the
   surviving three both read and write, and it flatters the LibreOffice family
   exactly as ODT did. An XLSX pass would bring **FreeOffice PlanMaker** back and
   needs a second reader in `check-result.sh`.
2. **Whether block 4 (freeze) is required.** Making it optional brings
   **Calligra Sheets** back, at the cost of the frozen-split assertion and of a
   hole in the block table that `tools/check_blocks.py` currently uses to prove
   the timing columns are comparable.
3. **Whether Collabora's dialogs can be made to work here.** That one is a
   debugging question rather than a benchmark-design question, and the word
   processor group's Collabora working in the same image is the place to start.

None of the three was taken unilaterally, and none of them is expensive to
revisit — every dropped app is installed, pinned, and measured as far as its
blocker.
