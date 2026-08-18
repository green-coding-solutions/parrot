# Handoff — spreadsheet group

Everything an incoming session needs to carry this group forward. Read this,
then [`README.md`](README.md), then the `MEASUREMENTS.md` of whichever app you
are working on. **Read [`libreoffice/MEASUREMENTS.md`](libreoffice/MEASUREMENTS.md)
whichever app you are on** — several of its findings are properties of the
harness and of spreadsheets in general, not of LibreOffice.

The repository's [`AGENTS.md`](../../AGENTS.md) is the authority on how to make a
recording that is worth having, and
[`../wordprocessors/HANDOFF.md`](../wordprocessors/HANDOFF.md) applies here
unchanged. Nothing below replaces either.

---

## Where things stand

| App | Install | Landmarks | Recorded | Replay-verified | Normalized | GMT |
| --- | --- | --- | --- | --- | --- | --- |
| LibreOffice Calc | ✅ | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.000703, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| Gnumeric | ✅ 1.12.56-2build5 | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0.180904, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| Apache OpenOffice Calc | ✅ 4.1.16-3 | ✅ 18/18 | ✅ | ✅ 18 PASS, worst RMSE 0, ground truth PASS | ✅ 18 PASS | ✅ 18 PASS ×2 |
| SoftMaker FreeOffice PlanMaker | ✅ rev 3702 | ✅ 16/18 | ⛔ **skipped** | ⛔ cannot write ODS — [why](freeoffice/MEASUREMENTS.md) | — | — |
| Calligra Sheets (Flatpak) | ✅ 26.04.3 | ⚠ partial | ⛔ **skipped** | ⛔ no freeze panes — [why](calligra/MEASUREMENTS.md) | — | — |
| Collabora Office (Flatpak) | ✅ 26.04.2.4-2 | ⚠ blocks 1–6 | ⛔ **skipped** | ⛔ no dialog opens — [why](collabora/MEASUREMENTS.md) | — | — |

The corpus and the ground truth are finished and tested — see the README's
*What was tested*.

**Three apps are complete and three are out.** The three that are out were each
stopped by something the application cannot do, not by a driver problem, and
each of the three would need a decision about what the *group* measures before
it could come back:

| Out | Would need |
| --- | --- |
| FreeOffice PlanMaker | block 17 in XLSX for everyone, or it stays out |
| Calligra Sheets | block 4 made optional, and the frozen-split assertion with it |
| Collabora Office | its JSDialogs to work in this container — start at `WebGL2 blocklisted` |

Those are the three open questions, and they are the reason each app's
`MEASUREMENTS.md` was written up in full rather than deleted: everything
measured is still there.

The time-normalized variants are generated, replay-verified and GMT-verified for
the three that are in. **Re-run `tools/check_blocks.py applications/spreadsheets
--normalize-time` if any app is ever re-recorded or added** — every block is
padded to the longest across the group, so one new recording changes the padding
in all of them, and the normalized scenarios then have to be re-run too.

**All six scenarios have been through GMT** (three ordinary, three normalized),
all six reporting `MEASUREMENT SUCCESSFULLY COMPLETED` with 18 `PASS ref=` and 0
`FAIL ref=`. Judge a GMT run by those three counts — its exit code is 0 even
when the flow failed. The normalized runs land within **2.2 s** of each other
over fourteen minutes, against a 198 s spread unpadded.

**No energy numbers yet.** This machine's GMT config has no CPU energy provider
— only cpu/memory/disk/network utilisation. `network_energy_formula_global` is a
formula over bytes, not a measurement. Publishable Joules need
`cpu_energy_rapl_msr_component` (or a PSU provider) and a quiet machine; GMT
warned about other running containers on every run.

## The loop, per app

1. Write `install.sh` (pin the version) and `usage_scenario.yml`.
2. `bash common/setup-container.sh <app> --measure`
3. Launch the app, read `WM_CLASS` and `WM_WINDOW_ROLE`, fix the `pin-windows.sh`
   arguments, rebuild, and **confirm the geometry came back as 1440x900 at 0,0**.
   An unmatched fluxbox rule is completely silent. Then **run
   `xdotool search --onlyvisible --class <what you plan to pass as
   --windowclass>` and confirm it returns the window** — fluxbox matches
   `res_name` and xdotool matches `res_class`, and they are not always the same
   string.
4. Measure one block at a time, screenshotting after each, writing
   `MEASUREMENTS.md` as you go rather than at the end. **Drive all eighteen
   blocks by hand and run `common/check-result.sh` before writing a line of
   `drive-scenario.sh`.** That is what turns the driver into a transcription of a
   session known to do the work.
5. Write `drive-scenario.sh` and `record-session.sh`.
6. Record. Check: 18 checkpoints, 18 PNGs, all 1440x900, no `WARNING` lines,
   ground truth PASS.
7. `bash common/verify-app.sh <app>` in a fresh container. Read the **worst
   RMSE**, not the pass count.
8. Open the reference screenshots and compare them against LibreOffice's for the
   same block. This is the only thing that catches a block that acted on the
   wrong object.

## Commands

```bash
bash applications/spreadsheets/common/setup-container.sh libreoffice --measure
source applications/spreadsheets/common/measure.sh    # X, K, T, WINS, SHOT, STATUS, start_app

./applications/spreadsheets/<app>/record-session.sh
bash applications/spreadsheets/common/verify-app.sh <app>
bash applications/spreadsheets/common/verify-app.sh <app> --normalized

./tools/check_blocks.py applications/spreadsheets
./tools/check_blocks.py applications/spreadsheets --normalize-time

./applications/spreadsheets/generate_workbook.py --check
./applications/spreadsheets/generate_workbook.py --expected
```

---

## Traps that are specific to spreadsheets

These are the ones the word processor group could not have taught, and both of
the first two were found in LibreOffice within an hour of each other.

### A dialog's default SCOPE is the first thing to check

**Confirmed in two unrelated codebases**, which makes it a rule rather than a
quirk. Not one of these was a wrong coordinate; every one is a dialog quietly
scoped to less than the whole workbook, and every one produces a plausible file
and no error:

| App | Dialog | Default | What it would have done |
| --- | --- | --- | --- |
| LibreOffice Calc | Find and Replace | "Current selection only" **ticked** whenever a multi-cell range is selected | Block 14 leaves E2:E20001 selected — a column with no text in it — so Replace All searches that, changes nothing, and reports it |
| LibreOffice Calc | PDF export | Range = "Selection/Selected sheet(s)" | Block 16 leaves the cursor on Summary: a 1-page PDF where the ground truth wants 9 |
| Gnumeric | Print (print-to-file) | "Active workbook sheet" | The same — Summary alone |

Gnumeric's Search & Replace is the counter-example that proves it is worth
checking rather than assuming: it puts scope in an explicit group and defaults
to **Entire workbook**. Apache OpenOffice is a second counter-example, and a
sharper one: its Find & Replace hides "Current selection only" behind a
collapsed *More Options* and leaves it unticked, and its PDF export defaults
Range to **All** — so on the two dialogs where LibreOffice Calc traps you, the
fork of LibreOffice Calc does not.

### A pre-filled field that is not selected is the same bug in a different dress

The scope traps are about what a dialog will *act on*. This one is about what it
will *keep*, and it has now appeared three times in two applications:

| App | Field | Typing into it gives |
| --- | --- | --- |
| Gnumeric | Name Box | `A352A1:H20001` — not a reference, so Return does nothing |
| Apache OpenOffice Calc | Name Box | `A422A1:H20001` — the same |
| Collabora Office | Name Box | `A381A1:H20001` — the same |
| Apache OpenOffice Calc | PDF export → File name | `/tmp/parrot-ledger.pdfparrot-ledger.pdf` — a valid PDF nothing will look for |

**Four of the five applications that got this far append.** LibreOffice Calc and
FreeOffice PlanMaker are the only two whose Name Box selects on a single click —
so the majority behaviour is the opposite of the one the group's first driver
was written against, and a driver copied from LibreOffice's silently selects
nothing. Triple-click anything pre-filled, and read the field back before
committing to it.

Check the scope of every dialog that has one, in the state the driver actually
reaches it in.

### The default SELECTION in a dialog is worth the same suspicion

Same class, different field. Both sort dialogs arrive pre-populated and neither
says what with:

| App | Sort dialog arrives with | Pressing OK would |
| --- | --- | --- |
| LibreOffice Calc | Sort Key 1 = the first column | sort by Date |
| Apache OpenOffice Calc | Sort by = `Date`, already chosen | sort by Date |
| Gnumeric | **all eight columns**, in sheet order | sort by Date, then Site, then Sensor, … |
| FreeOffice PlanMaker | `Column A`, and **"First row contains headings" unticked** | sort by date **and sort the heading row into the data** |

All four produce a perfectly ordered sheet that is ordered by the wrong thing,
and the last one destroys the header while doing it. Four out of four: assume
the sort dialog is wrong until you have read every field in it.

### Check the ACTION LIST, not the menus, before assuming a feature exists

Calligra Sheets has no freeze panes. Four menu walks did not prove that; the
**shortcut editor** did. Settings ▸ Configure Keyboard Shortcuts lists every
action the application has, bound or not, in a menu or not, and it answers in
seconds:

```text
freeze  -> nothing        filter -> Auto-Filter          ✅
pane    -> nothing        pdf    -> Export as PDF...     ✅
split   -> Split Cells    chart  -> Chart editing  (shape tool, no wizard)
fix     -> Permute fixation (F4)
```

Do this on the first day for every new entrant, for every block the script
needs. A menu walk tells you where you have looked; the action list tells you
what is there. Calligra is dropped; see
[calligra/MEASUREMENTS.md](calligra/MEASUREMENTS.md).

### An application can read a format it cannot write

FreeOffice PlanMaker opens `parrot-ledger.ods` and drives sixteen blocks
correctly, and then has **no ODF entry in its Save-as file-type list at all**.
Nothing before block 17 hints at it. If the group is ever extended, check the
*save* side of the format on the first day, not the *open* side — a file that
opens is not a file that round-trips. It is dropped; see
[freeoffice/MEASUREMENTS.md](freeoffice/MEASUREMENTS.md).

### The lenient reader is the dangerous one

The shipped workbook's cross-sheet ranges were malformed OpenFormula
(`[Readings.$D$2:$D$20001]` where the end reference needs its own dot,
`[Readings.$D$2:.$D$20001]`). LibreOffice accepted it through a full measuring
pass, a recording and a replay verification without a murmur; Gnumeric threw one
modal per formula before its window appeared.

Generalise it: when four of six entrants share a lineage, agreement between them
is not evidence. Take the odd one out seriously the first time it complains.

### A wrong fill-down is invisible on screen

You cannot see row 1000 from the top of the sheet, and no checkpoint looks at
row 20001. A fill-down that stopped early, a sort that moved one column and not
its neighbours, a filter that was never cleared — none of these show up in a
screenshot. `check-result.sh` is not optional here in a way it nearly was for a
document.

### Clearing a filter may not unhide

Verified in LibreOffice's GUI (`Ctrl+Shift+L` does unhide) and verified NOT to
in the UNO API, where clearing the filter fields and refreshing leaves all
16,600 rows hidden. A replace-all afterwards then silently skips every hidden
row — 88 of 500 anchors, spread evenly across all five note variants so nothing
about the result looks partial. Check the row numbers are consecutive and black,
not just that the grid looks full.

### Cell autoinput is the code editors' autocomplete problem again

Typing into a cell completes the entry from other cells in the same column, and
the `Enter` that ends the entry commits the **suggestion**. Turn it off in the
profile wherever the app lets a profile carry it (`Input/AutoInput` for the
LibreOffice family), and check what the cell actually contains afterwards rather
than what was typed.

### The argument separator is a per-application question

`=ROUND(E2*F2,2)` with a comma is confirmed to work in **LibreOffice Calc** in an
English (USA) locale container. It has to be confirmed the same way in every
other app: if one insists on `;`, the typed text is no longer identical across
the group and block 8 needs a single-argument formula instead. Note that this
cannot be answered through UNO — `setFormula` uses the API grammar and takes a
semicolon regardless of what the interface accepts.

### Prefer a focused control and a keystroke to any popup

Two places where this removed a coordinate-sensitive click on a list that could
reposition itself under the pointer:

* the **Sort** dialog opens with Sort Key 1 focused, so `r` selects `Reading`
  without opening the popup at all (`s` would be ambiguous between Site, Sensor
  and Status — check the initial letters are unique before relying on this);
* the **filter** popup opens with its search box focused, so typing `Turbine`
  narrows the list to one entry and ticks it.

### Inserting a chart changes the whole application

LibreOffice's chart wizard leaves the application in chart-edit mode with a
different menu bar and different toolbars. A click outside the chart is required
before the checkpoint, or it photographs a different application than every
other block did.

### Calligra redefines shortcuts, silently, and Words proved it four times

Carried over from the word processor group and worth pressing one at a time in
Sheets before writing any of them into a driver. In Calligra **Words**:

| pressed | what actually happened |
| --- | --- |
| `Ctrl+R` | **Align Right**, not Replace — it reformatted the paragraph the cursor was in |
| `Ctrl+Y` | **nothing at all**; redo is `Ctrl+Shift+Z` |
| `Tab` in a table | inserted a **tab character** instead of moving a cell |
| `Escape` after inserting a picture | did not leave the shape tool |

None of them reported an error. `Tab` is the one to watch hardest here: this
group has no table block, but `Tab` inside a **grid** is how a spreadsheet moves
between cells, and if Sheets does what Words did the driver would type into one
cell instead of three.

### The status bar is free ground truth, per block

Use it while measuring. In Calc the selection Sum caught three things that would
otherwise only have surfaced at the end: that the sort had not lost a row
(`998310608.349896` before and after), that the fill-down produced exactly the
expected total (`74641377.6700004`), and that the filter selected exactly 3,401
rows.

---

## Settled, do not relitigate

* ODS for both opening and saving — the only format all six read and write.
* Ranges are named by address through the Name Box, never dragged and never
  reached with `Ctrl+Shift+Down`; the applications do not agree on how many rows
  a sheet has.
* Typed formulas never cross a sheet: the ODF suites write `Sites.A2` and
  Gnumeric writes `Sites!A2`.
* Recalculation on load is OFF, so block 2 measures a load and block 11 measures
  a recalculation. The workbook ships cached values for this reason.
* 20,000 rows, and the workbook is committed. Changing either invalidates every
  recording, because the script names ranges by address.
* No pivot table — Gnumeric has none, and the script is the intersection.
* There is no "close the app" block.
