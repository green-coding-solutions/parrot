# SoftMaker FreeOffice PlanMaker — measured, then dropped from the group

**Status: SKIPPED. Not recorded, and it should not be recorded as the script
stands.**

PlanMaker **cannot write OpenDocument**. It reads `parrot-ledger.ods` perfectly
and drove sixteen of the eighteen blocks correctly, but block 17 — *"save the
workbook in place with Ctrl+S, keeping the ODS format if the app asks"* — is not
something the application can do, and everything the ground truth checks lives
in the file that save would produce.

Everything below was measured against a running container before that was
discovered, so the landmarks are real and the file is worth keeping: if the
group ever runs a second pass in XLSX, PlanMaker is ready and only block 17 and
the checker change.

SoftMaker FreeOffice 2024, package revision 3702, Ubuntu 24.04, 1440x900.

```bash
bash applications/spreadsheets/common/setup-container.sh freeoffice --measure
```

## The blocker, in full

`Ctrl+S` on the open `.ods` does not save in place. It opens **Save as**, with
`File name` pre-filled `parrot-ledger.pmdx` and `File type` set to *PlanMaker
document (\*.pmdx)*. The complete File type list is 22 entries:

```text
PlanMaker document (*.pmdx)            SYLK file (*.slk)
PlanMaker template (*.pmvx)            Rich Text Format (*.rtf)
Microsoft Excel (*.xlsx)               HTML 4.0 (*.htm)
Microsoft Excel with macros (*.xlsm)   dBASE (*.dbf)
Microsoft Excel 97-2003 (*.xls)        DIF file (*.dif)
Microsoft Excel 5.0/7.0 (*.xls)        CSV file (*.csv)
Microsoft Excel template (*.xltx)      CSV file with additional options (*.csv)
Microsoft Excel template with macros (*.xltm)   Text file (*.txt)
Microsoft Excel template (*.xlt)       Text file with additional options (*.txt)
TextMaker document (*.tmdx)
PlanMaker 2012 document (*.pmd)
PlanMaker 2012 template (*.pmv)
PlanMaker 2010 document (*.pmd)
```

**No OpenDocument entry.** The File ribbon tab confirms it from the other
direction — New, Open, Close, Save, Save as, **PDF export**, Page setup, Define
print range, Print preview, Print, Properties, Recalculate, Compress all
pictures, Options, Customize. There is no ODF export anywhere. Import is
one-way.

### Why that ends the run rather than costing a workaround

Accepting the Save as would write `/tmp/parrot-ledger.pmdx` and leave
`/tmp/parrot-ledger.ods` **exactly as shipped**. `check-result.sh` reads the
`.ods`, so it would report the sort never ran, no formulas in column I, no
`Shearwater`, no chart — a wall of failures describing work that had in fact all
been done, in a file it cannot read. Every one of the seventeen assertions is
about the saved workbook.

The alternatives, and why neither is mine to take:

* **Save XLSX instead.** This is the honest option, and it changes the
  benchmark: block 17 stops measuring the same serializer as the other five, and
  `check-result.sh` needs a second reader. It also reopens the ODS-vs-XLSX
  question the group settled deliberately (see the README).
* **Drop blocks 17 and 18 for this app.** Then the block table has a hole in it
  and `tools/check_blocks.py` stops reporting "all files define the same blocks",
  which is the check that makes the timing columns comparable at all.

So it is skipped, and the decision is left where it belongs.

## What was confirmed before the blocker

### The window, and the pin

```text
[Untitled 1 - PlanMaker]   WM_CLASS(STRING) = "pm", "pm"
```

`pin-windows.sh pm 1440 900` matches and pins to 0,0 — **confirmed, not
inferred.** The word processor group measured TextMaker's `res_name` as `tm`
against a binary called `textmaker24free`; `pm` was the obvious guess for
`planmaker24free` and obvious guesses are exactly what an unmatched fluxbox rule
swallows in silence. Read back:

```text
[Untitled 1 - PlanMaker] X=0 Y=0 WIDTH=1440 HEIGHT=900
```

**The seeded profile works.** `install.sh`'s `offo24config.ini` and
`pmfo24config.ini` suppress the *User interface* and *User info* modals, the
update check and the welcome document: PlanMaker comes up straight onto an
editable `Untitled 1` with no sidebar. The `[pm]` section name and the
`FirstLaunch` / `ShowWelcomeDocument` / `SidebarDocking` keys were guesses
carried over from TextMaker's `[tm]`, and they are correct.

### Fixed landmarks

| | |
| - | - |
| Ribbon tabs, y=15 | File 23, Home 76, Insert 136, Layout 198, Formula 269, Data 332, Review 391, View 450 |
| Name Box | `50,156` — a **single click selects**, like LibreOffice Calc and unlike Gnumeric and AOO |
| Sheet tabs, y=859 | Readings 132, Sites 186, Summary 240 |
| Grid | row 1 at y≈228 |
| Status bar | selection aggregate centred at x≈660, y=885 |

### The blocks that work

| # | Route | Notes |
| - | --- | --- |
| 1 | `planmaker24free` | ~35 s, nothing to dismiss |
| 2 | `Ctrl+O`, type the path, `Return` | SoftMaker's own dialog; File name empty and focused. ~60 s |
| 3 | `Ctrl+End` | H20001 |
| 4 | View `450,15` → Freeze cells ▾ `665,105` → **Freeze at current position** `767,164` | cursor at A2 first |
| 5 | `Page Down` ×10 | **A322** — 32 rows a press, the shortest in the group |
| 6 | tabs at y=859 | |
| 7 | Data `332,15` → Sort `29,60` | **see below** |
| 8 | Name Box → I2, `=ROUND(E2*F2,2)` | **the comma works**, as in LibreOffice and Gnumeric and unlike AOO |
| 9 | Home `76,15` → Fill ▾ `1085,70` → Down `1104,100` | **see below** |
| 10 | Name Box → K1, `=SUM(I2:I20001)` | **74641377.6** displayed |
| 11 | Formula `269,15` → Recalculate ▾ `1114,103` → **Recalculate workbook** `1177,160` | |
| 12 | Data → AutoFilter `210,60`, Category button `433,227` | Excel-style checkbox list with OK/Cancel: untick **(All)** `318,413`, tick **Turbine** `318,540`, **OK** `328,573`. Status bar then reads `3400 of 20000 records found` |
| 13 | Data → **Show all** `298,70` | filter buttons stay |
| 14 | Name Box → E2:E20001, `Ctrl+1`, category **Number** `430,332`, **OK** `879,697` | **see below** |
| 15 | Name Box → A1, `Ctrl+H` | **see below** |
| 16 | Summary tab, Name Box → A1:B7, Insert `136,15` → **Chart frame** `287,60`, **OK** `1096,752`, click outside | **see below** |

### 7. The worst sort default in the group

PlanMaker's Sort dialog (929x499 at 256,245) arrives with

* Column 1 = **`Column A`** — not `Date`, because
* **"First row contains headings" is UNTICKED.**

Pressing OK sorts the **heading row into the data**. Every other entrant at
least keeps the header where it is and merely sorts by the wrong column; this
one destroys the header. The row would end up somewhere in the middle of 20,000
data rows, and the first screen after the sort looks entirely normal.

So: tick *First row contains headings* at `661,592` **first** — the Column 1
dropdown then re-labels itself from `Column A` to `Date`, which is the
confirmation it took — then open it at `441,305` and click **Reading** at
`380,424`, then **OK** at `1112,279`. About 50 s.

Ranked, for the group table:

```text
LibreOffice Calc    one key, pre-set to the first column
Apache OpenOffice   one key, pre-set to `Date`
Gnumeric            all eight columns, in sheet order
PlanMaker           no header detection at all — sorts the heading row into the data
```

### 9. Ctrl+D opens the font list

Not fill-down, and not nothing either: **`Ctrl+D` drops open the font-name
combo** on the Home ribbon and leaves it open over the sheet. The selection is
untouched and only I2 holds a value.

That makes three different behaviours for one keystroke across four
applications:

```text
LibreOffice Calc    Fill Down
Gnumeric            Fill Down
Apache OpenOffice   nothing at all
PlanMaker           opens the font list
```

Fill Down is Home ▸ Fill ▾ ▸ Down. Two `Escape`s are needed to close the font
list before anything else will work.

### 14. The only app whose Number default is already right

Category **Number** arrives with **Decimal places = 2** and the preview reading
`10.00`, so OK is the whole interaction. LibreOffice, AOO and Gnumeric all
default to 0 and need the spinner clicked twice.

### 15. Replace all, and the scope box that is off by default

`Ctrl+H` works — where AOO leaves it unbound — and opens `Search and replace`
(677x507 at 382,409) on the **Replace** tab.

`Search in` is a group of its own, and **"Whole document" is unticked**, so the
replace is scoped to the current sheet. It happens not to matter here: all 500
`Cormorant` anchors are in `Readings!H` by construction, which is the sheet the
cursor is on. It would matter for any anchor placed elsewhere, and it is the
fourth application in this group to hide a scope default somewhere different.

`Search for` `623,487`, `Replace with` `623,552`, **Replace all** `951,541`.
Result dialog:

```text
500 occurrences have been replaced.
```

OK at `721,500`, then **Close** at `951,579`.

### 16. The chart wizard that is a single dialog

Insert ▸ **Chart frame** opens `Chart properties` (1163x633 at 139,178) with
**Columns / grouped already selected** and a live preview of the correct six
categories. OK inserts it immediately at a default size and leaves it selected
with a contextual **Chart** ribbon tab; a click at `1100,700` deselects.

No placement drag, unlike Gnumeric's guru and unlike Calligra Words' shape tool.

### 17. Where it stops

`Ctrl+S` on the **first** save also raises a **Compatibility assistant** (662x444
at 390,273) asking whether the default file format should be *Microsoft Office*
or *SoftMaker FreeOffice*. It offers no third option, and whichever is chosen the
Save as dialog follows — the assistant is a one-time preference, and cancelling
out of Save as and pressing `Ctrl+S` again brings Save as straight back. That
was checked specifically, to rule out the assistant being the cause.

## If this app is ever brought back

1. Seed the Compatibility assistant away (the key is in
   `/root/SoftMaker/Settings/offo24config.ini`; find it by diffing the file
   across the click, as the word processor group found the others).
2. Decide block 17 for the whole group, not for this app — XLSX for everyone, or
   ODS and PlanMaker stays out.
3. Everything else in this file is measured and ready.
